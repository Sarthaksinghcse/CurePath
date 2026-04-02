import UIKit
import Vision

struct WoundComparisonResult {
    var isSameArea:          Bool        = true
    var sameAreaConfidence:  Float       = 1.0
    var woundDetected:       Bool        = true
    var woundPresenceNote:   String      = ""
    var sizeDeltaPct:        Double      = 0      // +ve = wound smaller (healing)
    var sizeChange:          SizeChange  = .unchanged
    var colourDeltaRedness:  Double      = 0      // +ve = redder (inflammation risk)
    var colourDeltaDarkness: Double      = 0      // +ve = darker (scab = healing)
    var colourNote:          String      = ""
    var overallTrend:        WoundTrend  = .stable
    var summary:             String      = ""
    var isInfectionRisk:     Bool        = false
    var shouldSeeDoctor:     Bool        = false
    var doctorReason:        String      = ""
    var consecutiveDaysNoProgress: Int   = 0

    enum SizeChange { case reduced, enlarged, unchanged }
}

nonisolated extension WoundComparisonResult.SizeChange: Equatable { }
nonisolated extension WoundTrend: Equatable { }

class WoundComparisonService {

    static func compare(
        newImage: UIImage,
        previousImage: UIImage,
        injuryType: InjuryType,
        consecutiveNonHealingDays: Int,
        completion: @escaping (WoundComparisonResult) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            var r = WoundComparisonResult()

            // 1. Same-area validation (perceptual hash — unchanged, works fine)
            let sim = imageSimilarity(newImage, previousImage)
            r.sameAreaConfidence = Float(sim)
            r.isSameArea = sim > 0.22
            if !r.isSameArea {
                r.woundPresenceNote = "Angle or distance differs from previous photo."
            }

            // 2. Wound metrics (ratio-based — lighting stable)
            let prev = woundMetrics(in: previousImage)
            let new  = woundMetrics(in: newImage)
            r.woundDetected = new.density > 0.012

            // 3. Size change
            if prev.area > 0.001 {
                let delta = (prev.area - new.area) / prev.area * 100.0
                r.sizeDeltaPct = delta
                r.sizeChange   = delta > 8 ? .reduced : delta < -8 ? .enlarged : .unchanged
            }

            // 4. Colour change — KEY FIX: compare red RATIO not absolute channel values
            //    Old: newRed = nc.r - (nc.g + nc.b)/2  → breaks if lighting changes brightness
            //    New: newRedRatio = nc.r / (nc.r + nc.g + nc.b)  → lighting-independent
            let pc = avgWoundColour(in: previousImage)
            let nc = avgWoundColour(in: newImage)

            let prevBrightness = pc.r + pc.g + pc.b
            let newBrightness  = nc.r + nc.g + nc.b

            // Ratio of red channel to total brightness — stable under lighting changes
            let prevRedRatio = prevBrightness > 5 ? pc.r / prevBrightness : 0.33
            let newRedRatio  = newBrightness  > 5 ? nc.r / newBrightness  : 0.33

            // Scale to 0–100 range so thresholds feel natural
            let ratioDelta = (newRedRatio - prevRedRatio) * 100.0
            r.colourDeltaRedness = ratioDelta

            // Darkness: overall brightness dropped = wound darkening (scab = healing)
            // Normalised so lighting-level shifts don't dominate
            let prevNormBright = prevBrightness / 3.0   // avg channel
            let newNormBright  = newBrightness  / 3.0
            r.colourDeltaDarkness = prevNormBright - newNormBright  // +ve = darker

            // Thresholds tightened vs old version to reduce false positives
            if r.colourDeltaRedness > 8 {
                r.colourNote = "⚠️ Wound appears redder — possible inflammation."
            } else if r.colourDeltaRedness < -8 {
                r.colourNote = "✅ Redness has reduced — a good sign."
            } else if r.colourDeltaDarkness > 15 {
                r.colourNote = "✅ Wound looks darker/drier — scabbing is healthy healing."
            } else if r.colourDeltaDarkness < -15 {
                r.colourNote = "ℹ️ Wound appears lighter — keep monitoring."
            }

            // 5. Overall trend
            let isHealing   = r.sizeChange == .reduced
                           || r.colourDeltaRedness < -6
                           || r.colourDeltaDarkness > 12
            let isWorsening = r.sizeChange == .enlarged
                           || r.colourDeltaRedness > 10
            r.overallTrend = isHealing && !isWorsening ? .healing
                           : isWorsening               ? .worsening
                           :                             .stable

            // 6. Summary text
            r.summary = buildSummary(r)

            // 7. Doctor recommendation after 3 consecutive non-healing days
            let streak = consecutiveNonHealingDays + (r.overallTrend == .healing ? 0 : 1)
            r.consecutiveDaysNoProgress = streak
            if streak >= 3 {
                r.shouldSeeDoctor = true
                r.isInfectionRisk = r.colourDeltaRedness > 8 || r.sizeChange == .enlarged
                r.doctorReason = r.isInfectionRisk
                    ? "Increased redness or wound size after \(streak) days without improvement may indicate infection. Please see a doctor promptly."
                    : "No healing has been detected for \(streak) consecutive days. A doctor can check for complications and update your care plan."
            }

            DispatchQueue.main.async { completion(r) }
        }
    }

    // MARK: - Perceptual hash similarity (0–1, unchanged)
    private static func imageSimilarity(_ a: UIImage, _ b: UIImage) -> Double {
        guard let ha = pHash(a), let hb = pHash(b) else { return 0.5 }
        let match = zip(ha, hb).filter { $0 == $1 }.count
        return Double(match) / Double(ha.count)
    }

    private static func pHash(_ img: UIImage) -> [Bool]? {
        let s = 16
        guard let cg = img.cgImage else { return nil }
        var px = [UInt8](repeating: 0, count: s * s * 4)
        guard let ctx = CGContext(data: &px, width: s, height: s,
            bitsPerComponent: 8, bytesPerRow: s * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: s, height: s))
        var grays = [Double]()
        for i in stride(from: 0, to: s * s * 4, by: 4) {
            grays.append(0.299 * Double(px[i]) + 0.587 * Double(px[i+1]) + 0.114 * Double(px[i+2]))
        }
        let avg = grays.reduce(0, +) / Double(grays.count)
        return grays.map { $0 >= avg }
    }

    // MARK: - Wound metrics (ratio-based detection)
    struct WoundMetrics { var area: Double = 0; var density: Double = 0 }

    private static func woundMetrics(in img: UIImage) -> WoundMetrics {
        guard let cg = img.cgImage else { return WoundMetrics() }
        let w = 120, h = 120
        var px = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &px, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return WoundMetrics() }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        var wc = 0
        for i in stride(from: 0, to: w * h * 4, by: 4) {
            if isWoundPx(r: Int(px[i]), g: Int(px[i+1]), b: Int(px[i+2])) { wc += 1 }
        }
        let a = Double(wc) / Double(w * h)
        return WoundMetrics(area: a, density: a)
    }

    // MARK: - Ratio-based wound pixel detection (KEY FIX — shared logic with WoundProgressService)
    // Uses red ratio instead of absolute values → stable under different lighting/skin tones
    private static func isWoundPx(r: Int, g: Int, b: Int) -> Bool {
        let brightness = r + g + b
        guard brightness > 40, brightness < 700 else { return false }

        let rRatio = Double(r) / Double(brightness)
        let gRatio = Double(g) / Double(brightness)
        let bRatio = Double(b) / Double(brightness)

        let isFreshWound = rRatio > 0.48 && gRatio < 0.31
        let isDriedBlood = rRatio > 0.42 && gRatio < 0.33 && brightness < 320
        let isBurn       = brightness < 120 && rRatio > 0.37
        let isAbrasion   = rRatio > 0.44 && gRatio < 0.35 && bRatio < 0.30
        let isInflamed   = rRatio > 0.40 && gRatio < 0.28 && rRatio > bRatio + 0.08

        return isFreshWound || isDriedBlood || isBurn || isAbrasion || isInflamed
    }

    // MARK: - Average wound colour (ratio-based pixels only)
    struct RGB { var r, g, b: Double }

    private static func avgWoundColour(in img: UIImage) -> RGB {
        guard let cg = img.cgImage else { return RGB(r: 128, g: 80, b: 80) }
        let w = 80, h = 80
        var px = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &px, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return RGB(r: 128, g: 80, b: 80) }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        var sr = 0.0, sg = 0.0, sb = 0.0, n = 0.0
        for i in stride(from: 0, to: w * h * 4, by: 4) {
            let r = Int(px[i]), g = Int(px[i+1]), b = Int(px[i+2])
            if isWoundPx(r: r, g: g, b: b) {
                sr += Double(r); sg += Double(g); sb += Double(b); n += 1
            }
        }
        guard n > 0 else { return RGB(r: 128, g: 80, b: 80) }
        return RGB(r: sr/n, g: sg/n, b: sb/n)
    }

    // MARK: - Summary builder
    private static func buildSummary(_ r: WoundComparisonResult) -> String {
        var lines = [String]()
        if !r.isSameArea {
            lines.append("📸 Photo angle may differ — results are approximate.")
        }
        if !r.woundDetected {
            lines.append("🔍 Wound not clearly visible. Try a closer, well-lit photo.")
        }
        switch r.sizeChange {
        case .reduced:
            lines.append("📉 Wound area ~\(String(format:"%.0f", abs(r.sizeDeltaPct)))% smaller — great progress!")
        case .enlarged:
            lines.append("📈 Wound area ~\(String(format:"%.0f", abs(r.sizeDeltaPct)))% larger — monitor closely.")
        case .unchanged:
            lines.append("↔️ Wound size appears similar to previous photo.")
        }
        if !r.colourNote.isEmpty { lines.append(r.colourNote) }
        switch r.overallTrend {
        case .healing:   lines.append("✅ Overall: wound is healing.")
        case .worsening: lines.append("⚠️ Overall: wound may be worsening.")
        case .stable:    lines.append("⏳ Overall: no significant change yet.")
        case .baseline:  break
        }
        return lines.joined(separator: "\n")
    }
}
