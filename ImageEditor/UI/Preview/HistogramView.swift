import SwiftUI

private enum HistogramDisplayMode: String, CaseIterable, Identifiable {
    case luma = "L"
    case rgb = "RGB"

    var id: String { rawValue }
}

struct HistogramView: View {
    let histogram: HistogramData

    @State private var displayMode: HistogramDisplayMode = .rgb

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                Text("Histogram")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                Picker("Histogram", selection: $displayMode) {
                    ForEach(HistogramDisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .controlSize(.small)
                .frame(width: 112)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.06))

                if histogram.isEmpty {
                    Text("No histogram")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Canvas { context, size in
                        drawGrid(in: context, size: size)

                        if displayMode == .luma {
                            drawFilled(histogram.luma, color: .white.opacity(0.78), in: context, size: size)
                            drawLine(histogram.luma, color: .white, in: context, size: size, lineWidth: 1.0)
                        } else {
                            drawFilled(histogram.luma, color: .white.opacity(0.70), in: context, size: size)
                            drawFilled(histogram.red, color: .red.opacity(0.18), in: context, size: size)
                            drawFilled(histogram.green, color: .green.opacity(0.18), in: context, size: size)
                            drawFilled(histogram.blue, color: .blue.opacity(0.18), in: context, size: size)
                            drawLine(histogram.red, color: .red.opacity(0.90), in: context, size: size, lineWidth: 1.0)
                            drawLine(histogram.green, color: .green.opacity(0.90), in: context, size: size, lineWidth: 1.0)
                            drawLine(histogram.blue, color: .blue.opacity(0.90), in: context, size: size, lineWidth: 1.0)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 3)
                }
            }
            .frame(height: 108)

            legend
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.34))
        )
    }

    @ViewBuilder
    private var legend: some View {
        HStack(spacing: 10) {
            if displayMode == .luma {
                legendChip(title: "L", color: .white.opacity(0.9))
            } else {
                legendChip(title: "L", color: .white.opacity(0.9))
                legendChip(title: "R", color: .red.opacity(0.9))
                legendChip(title: "G", color: .green.opacity(0.9))
                legendChip(title: "B", color: .blue.opacity(0.9))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendChip(title: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func drawGrid(in context: GraphicsContext, size: CGSize) {
        for fraction in [CGFloat(0.25), 0.5, 0.75] {
            var path = Path()
            let x = size.width * fraction
            let y = size.height * fraction

            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))

            context.stroke(path, with: .color(.white.opacity(0.06)), lineWidth: 1)
        }
    }

    private func drawFilled(_ values: [Double], color: Color, in context: GraphicsContext, size: CGSize) {
        guard values.count > 1 else {
            return
        }

        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height))

        for index in values.indices {
            let x = CGFloat(index) / CGFloat(values.count - 1) * size.width
            let y = size.height - CGFloat(values[index].clamped(to: 0...1)) * size.height
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.closeSubpath()
        context.fill(path, with: .color(color))
    }

    private func drawLine(_ values: [Double], color: Color, in context: GraphicsContext, size: CGSize, lineWidth: CGFloat) {
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

        context.stroke(path, with: .color(color), lineWidth: lineWidth)
    }
}
