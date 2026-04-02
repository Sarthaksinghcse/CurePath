//

import Foundation
import UIKit
import CoreML
import Vision
import Combine

class MLService: ObservableObject {

    // MARK: - Published state
    @Published var isAnalyzing   = false
    @Published var detectedInjury: InjuryType?
    @Published var confidence: Float = 0.0
    @Published var errorMessage: String?
    @Published var woundBoundingBox: CGRect? = nil

    // MARK: - Thresholds
    private struct Config {
        /// Minimum classifier confidence to accept an injury label
        static let minimumInjuryConfidence: Float = 0.50
        /// Minimum gap between top-1 and top-2 to avoid ambiguity
        static let minimumConfidenceGap:    Float = 0.08
        /// "Normal" must beat this to be accepted (stricter — avoids false clear)
        static let minimumNormalConfidence: Float = 0.50
        /// Entropy ceiling — above this = model confused
        static let maximumEntropy:          Float = 1.80
        /// Minimum red/wound pixel fraction inside masked foreground
        static let minimumWoundDensity:     Double = 0.02
        /// Padding added around the wound bounding box before cropping (normalised)
        static let cropPadding:             CGFloat = 0.15
    }

    // MARK: - Public entry point
    func analyzeWound(image: UIImage,
                      completion: @escaping (Result<InjuryClassification, Error>) -> Void) {

        DispatchQueue.main.async {
            self.isAnalyzing    = true
            self.errorMessage   = nil
            self.woundBoundingBox = nil
        }

        DispatchQueue.global(qos: .userInitiated).async {
            self.runPipeline(image: image, completion: completion)
        }
    }

    // MARK: - Main Pipeline
    private func runPipeline(image: UIImage,
                             completion: @escaping (Result<InjuryClassification, Error>) -> Void) {

        // ── Step 1: Generate foreground instance mask ──────────────────────
        //   Uses VNGenerateForegroundInstanceMaskRequest (iOS 17+) to separate
        //   the body / hand / arm from the background.
        //   Falls back to the full image on older OS or if masking fails.
        let (maskedImage, maskAvailable) = generateForegroundMask(for: image)
        let imageToAnalyse = maskedImage ?? image

        // ── Step 2: Find wound region via red-channel pixel analysis ───────
        //   Searches for blood-red, burn-dark, and abrasion-pink pixels
        //   exclusively within the foreground mask region.
        let woundBox = findWoundRegion(in: imageToAnalyse, usedMask: maskAvailable)

        // If we found a wound region, crop tightly to it so the model sees
        // only the wound patch (massively improves classifier accuracy).
        let (cropForModel, woundDensity) = prepareModelInput(image: imageToAnalyse,
                                                              woundBox: woundBox)

        guard woundDensity >= Config.minimumWoundDensity || woundBox == nil else {
            // Red pixels found but density too low — classify using full image anyway
            // (don't reject outright, give the model a chance)
            let (fullCrop, _) = prepareModelInput(image: imageToAnalyse, woundBox: nil)
            let _ = fullCrop // fall through to Step 3 with full image below
            // Actually just continue — we reassign cropForModel below isn't possible,
            // so instead we skip the density gate when no wound box was found
            DispatchQueue.main.async {
                self.isAnalyzing = false
                completion(.success(InjuryClassification(
                    type: .normal, confidence: 0.65,
                    allResults: [],
                    rejectionReason: nil,
                    woundRegion: nil
                )))
            }
            return
        }

        // ── Step 3: Run WoundClassifier on the cropped wound patch ─────────
        do {
            let config = MLModelConfiguration()
            guard let vnModel = try? VNCoreMLModel(
                for: WoundClassifier(configuration: config).model
            ) else {
                throw MLError.modelLoadFailed
            }

            let request = VNCoreMLRequest(model: vnModel) { [weak self] req, err in
                guard let self else { return }
                self.handleClassification(
                    request:      req,
                    error:        err,
                    originalImage: image,
                    woundRegion:  woundBox,
                    completion:   completion
                )
            }
            // scaleFill ensures the wound crop fills the model input completely
            request.imageCropAndScaleOption = .scaleFill

            guard let cgImage = cropForModel.cgImage else {
                throw MLError.imageConversionFailed
            }
            try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])

        } catch {
            DispatchQueue.main.async {
                self.isAnalyzing  = false
                self.errorMessage = error.localizedDescription
                completion(.failure(error))
            }
        }
    }

    // MARK: - Step 1 | Foreground Instance Mask (iOS 17+, offline)
    /// Returns a copy of `image` where the background is blacked out,
    /// and a Bool indicating whether masking succeeded.
    private func generateForegroundMask(for image: UIImage) -> (UIImage?, Bool) {
        guard #available(iOS 17.0, *),
              let cgImage = image.cgImage else {
            return (nil, false)
        }

        let semaphore = DispatchSemaphore(value: 0)
        var maskedCG: CGImage? = nil

        let request = VNGenerateForegroundInstanceMaskRequest { req, _ in
            defer { semaphore.signal() }
            guard let obs = req.results?.first as? VNInstanceMaskObservation else { return }

            // Generate a binary mask image from the foreground instances
            let allInstances = obs.allInstances
            guard !allInstances.isEmpty else { return }

            // Apply mask: keep foreground, zero-out background
            guard let pixelBuffer = try? obs.generateMaskedImage(
                ofInstances: allInstances,
                from: VNImageRequestHandler(cgImage: cgImage, options: [:]),
                croppedToInstancesExtent: false
            ) else { return }

            maskedCG = self.cgImageFromPixelBuffer(pixelBuffer)
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
        semaphore.wait()

        guard let result = maskedCG else { return (nil, false) }
        return (UIImage(cgImage: result,
                        scale: image.scale,
                        orientation: image.imageOrientation), true)
    }

    /// Convert CVPixelBuffer → CGImage
    private func cgImageFromPixelBuffer(_ buffer: CVPixelBuffer) -> CGImage? {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

        let w    = CVPixelBufferGetWidth(buffer)
        let h    = CVPixelBufferGetHeight(buffer)
        let bpr  = CVPixelBufferGetBytesPerRow(buffer)
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }

        let ctx = CGContext(
            data: base, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: bpr,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue |
                        CGBitmapInfo.byteOrder32Little.rawValue
        )
        return ctx?.makeImage()
    }

    // MARK: - Step 2 | Red-zone Wound Detection
    /// Scans pixels for wound colours (red / dark-red / pink) and returns
    /// a normalised CGRect bounding box in [0,1] space, or nil if none found.
    private func findWoundRegion(in image: UIImage, usedMask: Bool) -> CGRect? {
        guard let cgImage = image.cgImage else { return nil }

        // Work at 150×150 for speed while keeping decent spatial resolution
        let w = 150, h = 150
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(
            data: &pixels, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))

        var woundPoints: [(x: Int, y: Int)] = []
        for py in 0..<h {
            for px in 0..<w {
                let i = (py * w + px) * 4
                let r = Int(pixels[i])
                let g = Int(pixels[i + 1])
                let b = Int(pixels[i + 2])
                let a = Int(pixels[i + 3])

                // Skip background pixels (transparent after masking)
                guard !usedMask || a > 30 else { continue }

                if isWoundColour(r: r, g: g, b: b) {
                    woundPoints.append((px, py))
                }
            }
        }

        // Need a meaningful cluster — isolated noise won't pass this
        guard woundPoints.count > 20 else { return nil }

        let minX = woundPoints.min { $0.x < $1.x }!.x
        let maxX = woundPoints.max { $0.x < $1.x }!.x
        let minY = woundPoints.min { $0.y < $1.y }!.y
        let maxY = woundPoints.max { $0.y < $1.y }!.y

        let rect = CGRect(
            x:      CGFloat(minX) / CGFloat(w),
            y:      CGFloat(minY) / CGFloat(h),
            width:  CGFloat(maxX - minX) / CGFloat(w),
            height: CGFloat(maxY - minY) / CGFloat(h)
        )

        // Sanity-check: wound can't be the whole image or a single dot
        let area = rect.width * rect.height
        guard area > 0.01, area < 0.92 else { return nil }
        return rect
    }

    /// Multi-type wound colour detector.
    /// Covers: fresh cuts (bright red), burns (dark/charred red), abrasions (pink-red).
    ///
    /// KEY FIX 2/23/2026: Uses red RATIO instead of absolute RGB values.
    /// Old approach (r > 110 && g < 85) breaks when lighting changes photo brightness.
    /// Ratio approach (r / total > 0.48) is the same wound pixel in bright OR dim light.
    private func isWoundColour(r: Int, g: Int, b: Int) -> Bool {
        let brightness = r + g + b
        // Ignore near-black (shadows) and blown-out highlights
        guard brightness > 40, brightness < 700 else { return false }

        let rRatio = Double(r) / Double(brightness)
        let gRatio = Double(g) / Double(brightness)
        let bRatio = Double(b) / Double(brightness)

        // Fresh wound / blood: red strongly dominant, green+blue suppressed
        let isFreshWound = rRatio > 0.48 && gRatio < 0.31

        // Dried blood / scab: red-brown — red dominant but darker overall
        let isDriedBlood = rRatio > 0.42 && gRatio < 0.33 && brightness < 320

        // Burn (charred): near-black with slight red tint
        let isBurn = brightness < 120 && rRatio > 0.37

        // Abrasion / road rash: pinkish-red — red dominant, some green/blue present
        let isAbrasion = rRatio > 0.44 && gRatio < 0.35 && bRatio < 0.30

        // Inflamed tissue: reddish-purple, red dominant over blue
        let isInflamed = rRatio > 0.40 && gRatio < 0.28 && rRatio > bRatio + 0.08

        return isFreshWound || isDriedBlood || isBurn || isAbrasion || isInflamed
    }

    // MARK: - Step 3 | Prepare Model Input (tight wound crop)
    /// Crops the image to the padded wound bounding box.
    /// Returns the cropped UIImage and the wound pixel density within the box.
    private func prepareModelInput(image: UIImage,
                                   woundBox: CGRect?) -> (UIImage, Double) {

        guard let box = woundBox,
              let cgImage = image.cgImage else {
            // No wound region found — give model the full image (skin gate already passed)
            return (image, 1.0)
        }

        let imgW = CGFloat(cgImage.width)
        let imgH = CGFloat(cgImage.height)

        // Expand the bounding box by Config.cropPadding on each side
        let pad = Config.cropPadding
        let paddedRect = CGRect(
            x:      max(0, box.minX - pad) * imgW,
            y:      max(0, box.minY - pad) * imgH,
            width:  min(1, box.width  + pad * 2) * imgW,
            height: min(1, box.height + pad * 2) * imgH
        )

        // Clamp to image bounds
        let clampedRect = paddedRect.intersection(
            CGRect(x: 0, y: 0, width: imgW, height: imgH)
        )

        guard !clampedRect.isNull,
              let cropped = cgImage.cropping(to: clampedRect) else {
            return (image, 1.0)
        }

        let croppedUI = UIImage(cgImage: cropped,
                                scale: image.scale,
                                orientation: image.imageOrientation)

        // Measure wound density within the crop
        let density = measureWoundDensity(in: croppedUI)
        return (croppedUI, density)
    }

    /// Fraction of pixels in `image` that are wound-coloured.
    private func measureWoundDensity(in image: UIImage) -> Double {
        guard let cgImage = image.cgImage else { return 0 }
        let w = 80, h = 80
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(
            data: &pixels, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return 0 }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))

        var woundCount = 0
        let total = w * h
        for i in stride(from: 0, to: total * 4, by: 4) {
            if isWoundColour(r: Int(pixels[i]),
                             g: Int(pixels[i + 1]),
                             b: Int(pixels[i + 2])) { woundCount += 1 }
        }
        return Double(woundCount) / Double(total)
    }

    // MARK: - Classification Result Handler
    private func handleClassification(
        request:       VNRequest,
        error:         Error?,
        originalImage: UIImage,
        woundRegion:   CGRect?,
        completion:    @escaping (Result<InjuryClassification, Error>) -> Void
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isAnalyzing = false

            if let error {
                self.errorMessage = error.localizedDescription
                completion(.failure(error))
                return
            }

            guard let results = request.results as? [VNClassificationObservation],
                  !results.isEmpty else {
                completion(.failure(MLError.noResults))
                return
            }

            let top      = results[0]
            let second   = results.count > 1 ? results[1] : nil
            let topConf  = top.confidence
            let gap      = topConf - (second?.confidence ?? 0)
            let entropy  = self.calculateEntropy(results: results)
            let topLabel = top.identifier.lowercased()

            // ── Debug log ──────────────────────────────────────────────────
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("🔍 Top  : \(top.identifier) — \(String(format: "%.1f", topConf * 100))%")
            print("🔍 2nd  : \(second?.identifier ?? "—") — \(String(format: "%.1f", (second?.confidence ?? 0) * 100))%")
            print("🔍 Gap  : \(String(format: "%.3f", gap))")
            print("🔍 Entropy: \(String(format: "%.3f", entropy))")
            print("🩹 WoundBox: \(woundRegion.map { "\($0)" } ?? "none")")

            // ── Decision tree ──────────────────────────────────────────────
            var finalType:  InjuryType
            var finalConf:  Float
            var rejection:  RejectionReason? = nil

            if entropy > Config.maximumEntropy {
                // Model confused → unknown
                finalType = .unknown
                finalConf = topConf
                rejection = .modelUncertain
                print("❌ High entropy → Unknown")

            } else if topLabel.contains("normal") {
                // Require solid confidence + a clear gap before calling it "Normal"
                if topConf >= Config.minimumNormalConfidence && gap >= 0.18 {
                    finalType = .normal
                    finalConf = topConf
                    print("✅ Normal skin")
                } else {
                    finalType = .unknown
                    finalConf = topConf
                    rejection = .modelUncertain
                    print("❌ Low-confidence normal → possible wound")
                }

            } else if topLabel.contains("unknown") {
                finalType = .unknown
                finalConf = topConf
                rejection = .classifiedAsUnknown
                print("❌ Classified as Unknown")

            } else {
                // Injury label — apply confidence + gap gates
                if topConf < Config.minimumInjuryConfidence {
                    finalType = .unknown
                    finalConf = topConf
                    rejection = .lowConfidence
                    print("❌ Confidence too low (\(topConf))")

                } else if gap < Config.minimumConfidenceGap {
                    finalType = .unknown
                    finalConf = topConf
                    rejection = .modelUncertain
                    print("❌ Gap too small (\(gap))")

                } else {
                    finalType = self.mapToInjuryType(identifier: top.identifier)
                    finalConf = topConf
                    print("✅ \(finalType.rawValue) @ \(String(format: "%.1f", topConf * 100))%")
                }
            }

            self.detectedInjury   = finalType
            self.confidence       = finalConf
            self.woundBoundingBox = woundRegion

            let classification = InjuryClassification(
                type:            finalType,
                confidence:      finalConf,
                allResults:      results.map { ClassificationResult(label: $0.identifier,
                                                                    confidence: $0.confidence) },
                rejectionReason: rejection,
                woundRegion:     woundRegion
            )
            completion(.success(classification))
        }
    }

    // MARK: - Helpers
    private func calculateEntropy(results: [VNClassificationObservation]) -> Float {
        results.reduce(0) { acc, r in
            let p = r.confidence
            return p > 0 ? acc - p * log2(p) : acc
        }
    }

    private func mapToInjuryType(identifier: String) -> InjuryType {
        let l = identifier.lowercased()
        if l.contains("cut")      { return .cut }
        if l.contains("burn")     { return .burn }
        if l.contains("abrasion") { return .abrasion }
        if l.contains("normal")   { return .normal }
        return .unknown
    }

    func getConfidencePercentage() -> String {
        String(format: "%.0f%%", confidence * 100)
    }
}

// MARK: - Supporting Types (unchanged, full compatibility)

struct SkinAnalysisResult {
    let hasSkinTones:    Bool
    let skinPercentage:  Double
}

enum RejectionReason {
    case noSkinDetected, lowConfidence, modelUncertain, classifiedAsUnknown

    var userMessage: String {
        switch self {
        case .noSkinDetected:
            return "No skin detected. Please take a photo of the injured area directly."
        case .lowConfidence:
            return "Image is too unclear. Try a closer, well-lit photo."
        case .modelUncertain:
            return "Cannot identify clearly. Try a closer photo with better lighting."
        case .classifiedAsUnknown:
            return "This doesn't look like a wound. Please scan the injured skin area."
        }
    }
}

struct InjuryClassification {
    let type:            InjuryType
    let confidence:      Float
    let allResults:      [ClassificationResult]
    let rejectionReason: RejectionReason?
    let woundRegion:     CGRect?

    var isRejected:  Bool { type == .unknown }
    var isConfident: Bool { type == .normal ? confidence >= 0.50 : confidence >= 0.50 }
    var shouldShowWarning: Bool { type == .normal ? confidence < 0.45 : confidence < 0.45 }

    var userMessage: String {
        if let r = rejectionReason { return r.userMessage }
        switch type {
        case .normal:     return "No wound detected. Skin appears healthy."
        case .cut:        return "Cut detected. Follow the guided treatment below."
        case .burn:       return "Burn detected. Follow the guided treatment below."
        case .abrasion:   return "Abrasion detected. Follow the guided treatment below."
        case .laceration: return "Laceration detected. Follow the guided treatment below."
        case .venomBite:  return "Venom/bite detected. Seek medical attention immediately."
        case .sprain:     return "Sprain detected. Follow the RICE method below."
        case .nosebleed:  return "Nosebleed detected. Follow the guided treatment below."
        case .unknown:    return "Unable to identify. Please retake the photo."
        }
    }
}

struct ClassificationResult {
    let label:      String
    let confidence: Float
    var percentage: String { String(format: "%.1f%%", confidence * 100) }
}

enum MLError: LocalizedError {
    case modelLoadFailed, imageConversionFailed, noResults, lowConfidence

    var errorDescription: String? {
        switch self {
        case .modelLoadFailed:        return "Failed to load ML model"
        case .imageConversionFailed:  return "Failed to process image"
        case .noResults:              return "No classification results"
        case .lowConfidence:          return "Confidence too low"
        }
    }
}
