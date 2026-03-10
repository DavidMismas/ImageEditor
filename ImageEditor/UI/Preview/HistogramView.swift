import SwiftUI

struct HistogramView: View {
    let histogram: HistogramData

    var body: some View {
        Canvas { context, size in
            drawLine(histogram.luma, color: .white.opacity(0.85), in: context, size: size)
            drawLine(histogram.red, color: .red.opacity(0.72), in: context, size: size)
            drawLine(histogram.green, color: .green.opacity(0.72), in: context, size: size)
            drawLine(histogram.blue, color: .blue.opacity(0.72), in: context, size: size)
        }
        .frame(height: 86)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.black.opacity(0.18))
        )
    }

    private func drawLine(_ values: [Double], color: Color, in context: GraphicsContext, size: CGSize) {
        guard values.count > 1 else {
            return
        }

        var path = Path()
        for index in values.indices {
            let x = CGFloat(index) / CGFloat(values.count - 1) * size.width
            let y = size.height - CGFloat(values[index].clamped(to: 0...1)) * size.height
            let point = CGPoint(x: x, y: y)
            if index == values.startIndex {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        context.stroke(path, with: .color(color), lineWidth: 1.25)
    }
}
