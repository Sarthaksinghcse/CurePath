import UIKit
import CoreML
import Vision

class WoundProgressService {

    // MARK: - Public entry point
    /// Analyse `image` and return a `DailyCheckIn` compared against `previous` (the LAST check-in).
    /// Trend = change vs previous only. Baseline comparison is done separately in the UI.
    static func analyse(
        image: UIImage,
        injuryType: InjuryType,
        previous: DailyCheckIn?,       // must be the IMMEDIATELY previous check-in
        completion: @escaping (DailyCheckIn?) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {

            // 1️⃣  Detect wound bounding box
            let box     = detectBoundingBox(in: image)
            let boxArea = box.map { Double($0.width * $0.height) } ?? 0.0

            // 2️⃣  Pixel density (ratio-based — lighting stable)
            let density = measureWoundDensity(in: image, region: box, type: injuryType)

            // 3️⃣  Raw combined score
            let rawScore = min(max((boxArea + density) / 2.0, 0.0), 1.0)

            // 4️⃣  Smoothed score — average with previous to absorb camera-angle noise
            //     Weighted: 60% new, 40% previous — new photo dominates but noise is damped
            let smoothedScore: Double
            if let prev = previous {
                smoothedScore = min(max(rawScore * 0.6 + prev.woundScore * 0.4, 0.0), 1.0)
            } else {
                smoothedScore = rawScore
            }

            // 5️⃣  Trend = vs immediately previous check-in only
            //     Wider noise band (±6%) prevents angle-jitter false alerts
            //
            //     SPECIAL CASE: If new score is near zero but previous had a real wound,
            //     this is a healed photo — force .healing regardless of smoothed score math.
            //     Without this, the 40% smoothing weight from previous keeps score high enough
            //     to land in "stable" instead of "healing".
            let delta: Double?
            let trend: WoundTrend
            if let prev = previous {
                let d = smoothedScore - prev.woundScore
                delta = d

                // Healed photo: no wound pixels found, but there was a wound before
                if rawScore < 0.02 && prev.woundScore > 0.05 {
                    trend = .healing
                } else if d < -0.06 {
                    trend = .healing
                } else if d >  0.06 {
                    trend = .worsening
                } else {
                    trend = .stable
                }
            } else {
                delta = nil
                trend = .baseline
            }

            // 6️⃣  Save image
            let filename = saveImage(image)

            let checkIn = DailyCheckIn(
                id:                UUID(),
                date:              Date(),
                imagePath:         filename,
                boundingBoxArea:   boxArea,
                woundPixelDensity: density,
                woundScore:        smoothedScore,
                deltaScore:        delta,
                trend:             trend
            )

            DispatchQueue.main.async { completion(checkIn) }
        }
    }

    // MARK: - Bounding Box via pixel analysis
    // Note: WoundClassifier is a classifier model (returns labels, not bounding boxes),
    // so we use ratio-based pixel detection for the bounding box — much more reliable
    // than the old absolute RGB thresholds, especially across lighting and skin tones.
    private static func detectBoundingBox(in image: UIImage) -> CGRect? {
        return pixelBasedBoundingBox(in: image)
    }

    // MARK: - Pixel-based bounding box (ratio-based detection)
    private static func pixelBasedBoundingBox(in image: UIImage) -> CGRect? {
        guard let cgImage = image.cgImage else { return nil }
        let w = 120, h = 120
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &pixels, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))

        var woundPixels: [(x: Int, y: Int)] = []
        for y in 0..<h { for x in 0..<w {
            let i = (y * w + x) * 4
            if isAnyWoundPixel(r: Int(pixels[i]), g: Int(pixels[i+1]), b: Int(pixels[i+2])) {
                woundPixels.append((x, y))
            }
        }}
        guard woundPixels.count > 30 else { return nil }
        let minX = woundPixels.min { $0.x < $1.x }!.x
        let maxX = woundPixels.max { $0.x < $1.x }!.x
        let minY = woundPixels.min { $0.y < $1.y }!.y
        let maxY = woundPixels.max { $0.y < $1.y }!.y
        let rect = CGRect(x: CGFloat(minX)/CGFloat(w), y: CGFloat(minY)/CGFloat(h),
                          width: CGFloat(maxX-minX)/CGFloat(w), height: CGFloat(maxY-minY)/CGFloat(h))
        let area = rect.width * rect.height
        return (area > 0.01 && area < 0.95) ? rect : nil
    }

    // MARK: - Ratio-based wound pixel detection
    // KEY FIX: Instead of checking absolute RGB values like r > 120 (which breaks under
    // different lighting), we check the RATIO of red to total brightness.
    // A wound pixel is red-dominant regardless of whether the photo is bright or dim.
    private static func isAnyWoundPixel(r: Int, g: Int, b: Int) -> Bool {
        let brightness = r + g + b
        // Ignore near-black pixels (shadows, hair) and near-white (blown highlights)
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

    // MARK: - Pixel density (ratio-based)
    private static func measureWoundDensity(in image: UIImage, region: CGRect?, type: InjuryType) -> Double {
        guard let cgImage = image.cgImage else { return 0 }
        let w = 120, h = 120
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &pixels, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return 0 }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        let rx = region.map { Int($0.minX * CGFloat(w)) } ?? 0
        let ry = region.map { Int($0.minY * CGFloat(h)) } ?? 0
        let rw = region.map { max(1, Int($0.width  * CGFloat(w))) } ?? w
        let rh = region.map { max(1, Int($0.height * CGFloat(h))) } ?? h
        var woundCount = 0, totalCount = 0
        for y in ry..<min(ry+rh,h) { for x in rx..<min(rx+rw,w) {
            let i = (y*w+x)*4
            if isAnyWoundPixel(r: Int(pixels[i]), g: Int(pixels[i+1]), b: Int(pixels[i+2])) { woundCount += 1 }
            totalCount += 1
        }}
        return totalCount > 0 ? Double(woundCount)/Double(totalCount) : 0
    }

    // MARK: - Persistence helpers
    private static let documentsDirectory = FileManager.default.urls(
        for: .documentDirectory, in: .userDomainMask).first!

    static func saveImage(_ image: UIImage) -> String {
        let filename = "checkin_\(UUID().uuidString).jpg"
        if let data = image.jpegData(compressionQuality: 0.85) {
            try? data.write(to: documentsDirectory.appendingPathComponent(filename))
        }
        return filename
    }

    static func loadImage(filename: String) -> UIImage? {
        guard let data = try? Data(contentsOf: documentsDirectory.appendingPathComponent(filename)) else { return nil }
        return UIImage(data: data)
    }

    static func deleteImage(filename: String) {
        try? FileManager.default.removeItem(at: documentsDirectory.appendingPathComponent(filename))
    }

    // MARK: - Consecutive stable days helper
    static func updateConsecutiveStableDays(checkIns: [DailyCheckIn]) -> Int {
        var count = 0
        for checkIn in checkIns.reversed() {
            if checkIn.trend == .stable || checkIn.trend == .worsening { count += 1 }
            else { break }
        }
        return count
    }
}
