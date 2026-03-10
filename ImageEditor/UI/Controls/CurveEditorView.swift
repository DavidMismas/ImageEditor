import SwiftUI

struct CurveEditorView: View {
    let title: String
    @Binding var curve: CurvePointSet
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 8) {
            Text(title)
                .font(.system(compact ? .caption : .headline, design: .rounded, weight: .semibold))

            GeometryReader { geometry in
                ZStack {
                    RoundedRectangle(cornerRadius: compact ? 10 : 12)
                        .fill(.black.opacity(0.18))

                    grid(in: geometry.size)
                        .stroke(.white.opacity(0.08), lineWidth: 1)

                    curvePath(in: geometry.size)
                        .stroke(.orange, style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))

                    ForEach(Array(curve.values.enumerated()), id: \.offset) { index, value in
                        Circle()
                            .fill(Color.white)
                            .frame(width: 10, height: 10)
                            .overlay {
                                Circle().stroke(Color.orange, lineWidth: compact ? 1.4 : 2)
                            }
                            .position(pointPosition(index: index, value: value, size: geometry.size))
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            updateCurve(at: value.location, size: geometry.size)
                        }
                )
            }
            .frame(height: compact ? 68 : 132)
        }
    }

    private func grid(in size: CGSize) -> Path {
        Path { path in
            for index in 0..<5 {
                let ratio = CGFloat(index) / 4
                path.move(to: CGPoint(x: size.width * ratio, y: 0))
                path.addLine(to: CGPoint(x: size.width * ratio, y: size.height))
                path.move(to: CGPoint(x: 0, y: size.height * ratio))
                path.addLine(to: CGPoint(x: size.width, y: size.height * ratio))
            }
        }
    }

    private func curvePath(in size: CGSize) -> Path {
        Path { path in
            for index in curve.values.indices {
                let point = pointPosition(index: index, value: curve.values[index], size: size)
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
        }
    }

    private func pointPosition(index: Int, value: Double, size: CGSize) -> CGPoint {
        let x = CGFloat(index) / 4 * size.width
        let y = (1 - CGFloat(value)) * size.height
        return CGPoint(x: x, y: y)
    }

    private func updateCurve(at location: CGPoint, size: CGSize) {
        let normalizedX = (location.x / max(size.width, 1)).clamped(to: 0...1)
        let closestIndex = Int((normalizedX * 4).rounded()).clamped(to: 0...4)
        let normalizedY = (1 - location.y / max(size.height, 1)).clamped(to: 0...1)

        var updated = curve
        updated[closestIndex] = normalizedY
        curve = updated
    }
}
