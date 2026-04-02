import SwiftUI
import UIKit

struct CameraPickerView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    @Binding var selectedImage: UIImage?

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPickerView
        init(_ parent: CameraPickerView) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage { parent.selectedImage = image }
            parent.isPresented = false
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.cameraDevice = .rear
        picker.allowsEditing = false

        // White "Use Photo" / "Retake" buttons
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.black
        appearance.titleTextAttributes       = [.foregroundColor: UIColor.white]
        appearance.buttonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white]
        picker.navigationBar.standardAppearance   = appearance
        picker.navigationBar.scrollEdgeAppearance = appearance
        picker.navigationBar.compactAppearance    = appearance
        picker.navigationBar.tintColor = .white

        // Orientation-aware overlay — must NOT intercept touches
        let overlay = CameraOverlayView(frame: UIScreen.main.bounds)
        overlay.backgroundColor = .clear
        overlay.isUserInteractionEnabled = false
        picker.cameraOverlayView = overlay

        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}
class CameraOverlayView: UIView {
    private let surroundLayer = CAShapeLayer()
    private let pulseLayer    = CAShapeLayer()
    private let ringLayer     = CAShapeLayer()
    private let dashedLayer   = CAShapeLayer()
    private var bracketLayers: [CAShapeLayer] = []
    private let instructionLabel = UILabel()
    private let tipsLabel        = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildLayers()
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() {
        super.layoutSubviews()
        repositionForCurrentBounds()
    }
    private func buildLayers() {
        surroundLayer.fillRule  = .evenOdd
        layer.addSublayer(surroundLayer)
        pulseLayer.fillColor   = UIColor.clear.cgColor
        pulseLayer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.35).cgColor
        pulseLayer.lineWidth   = 3
        layer.addSublayer(pulseLayer)
        let pulseAnim        = CABasicAnimation(keyPath: "opacity")
        pulseAnim.fromValue  = 0.8
        pulseAnim.toValue    = 0.0
        pulseAnim.duration   = 1.5
        pulseAnim.repeatCount = .infinity
        pulseLayer.add(pulseAnim, forKey: "pulse")
        ringLayer.fillColor   = UIColor.clear.cgColor
        ringLayer.strokeColor = UIColor.systemBlue.cgColor
        ringLayer.lineWidth   = 3
        layer.addSublayer(ringLayer)
        dashedLayer.fillColor       = UIColor.clear.cgColor
        dashedLayer.strokeColor     = UIColor.white.withAlphaComponent(0.5).cgColor
        dashedLayer.lineWidth       = 2
        dashedLayer.lineDashPattern = [8, 6]
        layer.addSublayer(dashedLayer)
        instructionLabel.text               = "Place wound inside circle"
        instructionLabel.font               = UIFont.systemFont(ofSize: 16, weight: .semibold)
        instructionLabel.textColor          = .white
        instructionLabel.textAlignment      = .center
        instructionLabel.backgroundColor    = UIColor.black.withAlphaComponent(0.65)
        instructionLabel.layer.cornerRadius = 8
        instructionLabel.layer.masksToBounds = true
        addSubview(instructionLabel)
        tipsLabel.text          = "📸 Steady  💡 Good light  📏 15-30 cm away"
        tipsLabel.font          = UIFont.systemFont(ofSize: 12, weight: .medium)
        tipsLabel.textColor     = UIColor.white.withAlphaComponent(0.85)
        tipsLabel.textAlignment = .center
        tipsLabel.numberOfLines = 0
        addSubview(tipsLabel)
        repositionForCurrentBounds()
    }
    private func repositionForCurrentBounds() {
        let isLandscape = bounds.width > bounds.height
        let shortEdge   = min(bounds.width, bounds.height)
        let fraction: CGFloat = isLandscape ? 0.55 : 0.65
        let circleSize: CGFloat = shortEdge * fraction
        let circleRect = CGRect(
            x: (bounds.width  - circleSize) / 2,
            y: (bounds.height - circleSize) / 2,
            width:  circleSize,
            height: circleSize
        )
        surroundLayer.fillColor = UIColor.black.withAlphaComponent(0.45).cgColor
        let path = UIBezierPath(rect: bounds)
        path.append(UIBezierPath(ovalIn: circleRect))
        path.usesEvenOddFillRule = true
        surroundLayer.path = path.cgPath
        pulseLayer.path = UIBezierPath(ovalIn: circleRect.insetBy(dx: -8, dy: -8)).cgPath
        ringLayer.path = UIBezierPath(ovalIn: circleRect).cgPath
        dashedLayer.path = UIBezierPath(ovalIn: circleRect.insetBy(dx: 20, dy: 20)).cgPath

        // Corner brackets — remove old, add new
        bracketLayers.forEach { $0.removeFromSuperlayer() }
        bracketLayers = buildBrackets(in: circleRect)
        bracketLayers.forEach { layer.addSublayer($0) }

        // Instruction label — below circle, 18pt gap, capped so it doesn't overflow
        let labelW: CGFloat = min(260, bounds.width - 32)
        let labelY  = circleRect.maxY + 18
        instructionLabel.frame = CGRect(
            x: (bounds.width - labelW) / 2,
            y: labelY,
            width: labelW, height: 34
        )

        // Tips label — above circle
        let tipsY = max(4, circleRect.minY - 44)
        tipsLabel.frame = CGRect(x: 16, y: tipsY, width: bounds.width - 32, height: 36)
    }

    // MARK: - Corner brackets

    private func buildBrackets(in rect: CGRect) -> [CAShapeLayer] {
        let len: CGFloat = 20, lw: CGFloat = 3
        let corners: [(CGPoint, CGPoint, CGPoint)] = [
            // top-left
            (CGPoint(x: rect.minX,          y: rect.minY + len),
             CGPoint(x: rect.minX,          y: rect.minY),
             CGPoint(x: rect.minX + len,    y: rect.minY)),
            // top-right
            (CGPoint(x: rect.maxX - len,    y: rect.minY),
             CGPoint(x: rect.maxX,          y: rect.minY),
             CGPoint(x: rect.maxX,          y: rect.minY + len)),
            // bottom-left
            (CGPoint(x: rect.minX,          y: rect.maxY - len),
             CGPoint(x: rect.minX,          y: rect.maxY),
             CGPoint(x: rect.minX + len,    y: rect.maxY)),
            // bottom-right
            (CGPoint(x: rect.maxX - len,    y: rect.maxY),
             CGPoint(x: rect.maxX,          y: rect.maxY),
             CGPoint(x: rect.maxX,          y: rect.maxY - len))
        ]
        return corners.map { (s, c, e) in
            let p = UIBezierPath()
            p.move(to: s); p.addLine(to: c); p.addLine(to: e)
            let sl = CAShapeLayer()
            sl.path        = p.cgPath
            sl.strokeColor = UIColor.cyan.cgColor
            sl.fillColor   = UIColor.clear.cgColor
            sl.lineWidth   = lw
            sl.lineCap     = .round
            return sl
        }
    }
}
