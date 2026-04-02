import SwiftUI
struct WoundBoundaryOverlay: View {
    let region: CGRect
    @State private var pulse: Bool = false
    @State private var scanLine: CGFloat = 0
    @State private var dashPhase: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let frameW = geo.size.width
            let frameH = geo.size.height
            let x = region.minX * frameW
            let y = region.minY * frameH
            let w = region.width * frameW
            let h = region.height * frameH

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color.black.opacity(0.35))
                    .mask(
                        Rectangle()
                            .overlay(
                                Rectangle()
                                    .frame(width: w, height: h)
                                    .offset(x: x, y: y)
                                    .blendMode(.destinationOut)
                            )
                    )
                Rectangle()
                    .strokeBorder(
                        style: StrokeStyle(
                            lineWidth: 2.5,
                            lineCap: .round,
                            dash: [8, 6],
                            dashPhase: dashPhase
                        )
                    )
                    .foregroundColor(.cyan)
                    .frame(width: w, height: h)
                    .offset(x: x, y: y)
                    .opacity(pulse ? 1.0 : 0.7)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
                CornerBrackets(x: x, y: y, w: w, h: h)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .cyan.opacity(0.8), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: w, height: 3)
                    .offset(x: x, y: y + scanLine * h)
                    .clipped()
                    .animation(.linear(duration: 1.5).repeatForever(autoreverses: true), value: scanLine)

                Text("⚠️ Wound Detected")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(4)
                    .offset(x: x, y: max(0, y - 22))
            }
        }
        .onAppear {
            pulse = true
            scanLine = 1.0
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                dashPhase = 14
            }
        }
    }
}

struct CornerBrackets: View {
    let x, y, w, h: CGFloat
    let size: CGFloat = 18
    let thickness: CGFloat = 3

    var body: some View {
        ZStack {
            Path {
                p in
                p.move(to: CGPoint(x: x, y: y + size))
                p.addLine(to: CGPoint(x: x, y: y))
                p.addLine(to: CGPoint(x: x + size, y: y))
            }.stroke(Color.cyan, lineWidth: thickness)
            Path {
                p in
                p.move(to: CGPoint(x: x + w - size, y: y))
                p.addLine(to: CGPoint(x: x + w, y: y))
                p.addLine(to: CGPoint(x: x + w, y: y + size))
            }.stroke(Color.cyan, lineWidth: thickness)
            Path {
                p in
                p.move(to: CGPoint(x: x, y: y + h - size))
                p.addLine(to: CGPoint(x: x, y: y + h))
                p.addLine(to: CGPoint(x: x + size, y: y + h))
            }.stroke(Color.cyan, lineWidth: thickness)
            Path {
                p in
                p.move(to: CGPoint(x: x + w - size, y: y + h))
                p.addLine(to: CGPoint(x: x + w, y: y + h))
                p.addLine(to: CGPoint(x: x + w, y: y + h - size))
            }.stroke(Color.cyan, lineWidth: thickness)
        }
    }
}
