@preconcurrency import AppKit
import SwiftUI

struct AdjustmentSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var format: String = "%.0f"

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary.opacity(0.95))
                Spacer()
                Text(String(format: format, value))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ContinuousSlider(value: $value, range: range)
                .frame(height: 18)
        }
    }
}

struct GradientAdjustmentSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let gradient: LinearGradient
    var format: String = "%.0f"

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary.opacity(0.95))
                Spacer()
                Text(String(format: format, value))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            GradientContinuousSlider(value: $value, range: range, gradient: gradient)
                .frame(height: 20)
        }
    }
}

struct ColorGradingSliders: View {
    let title: String
    @Binding var hue: Double
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary.opacity(0.95))

                Spacer()

                RoundedRectangle(cornerRadius: 4)
                    .fill(previewColor(from: previewRGB))
                    .frame(width: 22, height: 14)
                    .overlay {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    }
            }

            GradientAdjustmentSlider(
                title: "Hue",
                value: $hue,
                range: 0...360,
                gradient: hueGradient,
                format: "%.0f°"
            )

            GradientAdjustmentSlider(
                title: "Value",
                value: $value,
                range: 0...100,
                gradient: valueGradient
            )
        }
    }

    private var previewRGB: SIMD3<Double> {
        ColorWheelMath.wheelValueToRGBPreview(
            ColorWheelValue(
                angleRadians: ColorWheelMath.angleFromDegrees(hue),
                intensity: value / 100
            )
        )
    }

    private var hueGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(
                stops: stride(from: 0.0, through: 1.0, by: 1.0 / 24.0).map { hueUnit in
                    Gradient.Stop(
                        color: previewColor(from: ColorWheelMath.hueToPreviewRGB(hueUnit)),
                        location: hueUnit
                    )
                }
            ),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var valueGradient: LinearGradient {
        let angle = ColorWheelMath.angleFromDegrees(hue)
        return LinearGradient(
            colors: [
                previewColor(
                    from: ColorWheelMath.wheelValueToRGBPreview(
                        ColorWheelValue(angleRadians: angle, intensity: 0)
                    )
                ),
                previewColor(
                    from: ColorWheelMath.wheelValueToRGBPreview(
                        ColorWheelValue(angleRadians: angle, intensity: 0.5)
                    )
                ),
                previewColor(
                    from: ColorWheelMath.wheelValueToRGBPreview(
                        ColorWheelValue(angleRadians: angle, intensity: 1)
                    )
                )
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func previewColor(from preview: SIMD3<Double>) -> Color {
        Color(
            .sRGBLinear,
            red: preview.x,
            green: preview.y,
            blue: preview.z,
            opacity: 1
        )
    }
}

struct HSLHueAdjustmentSlider: View {
    let title: String
    let channel: HSLChannelKind
    @Binding var value: Double

    var body: some View {
        GradientAdjustmentSlider(
            title: title,
            value: $value,
            range: -100...100,
            gradient: gradient
        )
    }

    private var gradient: LinearGradient {
        let hues = channel.previewGradientHues
        let denominator = max(Double(hues.count - 1), 1)
        let stops = hues.enumerated().map { index, hue in
            return Gradient.Stop(
                color: previewColor(forHueDegrees: hue),
                location: Double(index) / denominator
            )
        }

        return LinearGradient(
            gradient: Gradient(stops: stops),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func normalizedHue(_ degrees: Double) -> Double {
        let wrapped = degrees.truncatingRemainder(dividingBy: 360)
        return wrapped >= 0 ? wrapped : wrapped + 360
    }

    private func previewColor(forHueDegrees degrees: Double) -> Color {
        let hueUnit = normalizedHue(degrees) / 360
        let preview = ColorWheelMath.hueToPreviewRGB(hueUnit)
        return Color(
            .sRGBLinear,
            red: preview.x,
            green: preview.y,
            blue: preview.z,
            opacity: 1
        )
    }
}

private struct ContinuousSlider: NSViewRepresentable {
    @Binding var value: Double
    let range: ClosedRange<Double>

    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value)
    }

    func makeNSView(context: Context) -> QuietNSSlider {
        let slider = QuietNSSlider()
        slider.suppressAction = true
        slider.minValue = range.lowerBound
        slider.maxValue = range.upperBound
        slider.doubleValue = value
        slider.isContinuous = true
        slider.controlSize = .small
        slider.target = context.coordinator
        slider.action = #selector(Coordinator.valueChanged(_:))
        slider.suppressAction = false
        return slider
    }

    func updateNSView(_ slider: QuietNSSlider, context: Context) {
        context.coordinator.value = $value
        slider.suppressAction = true
        slider.minValue = range.lowerBound
        slider.maxValue = range.upperBound

        if abs(slider.doubleValue - value) > 0.0001 {
            slider.doubleValue = value
        }
        slider.suppressAction = false
    }

    final class Coordinator: NSObject {
        var value: Binding<Double>

        init(value: Binding<Double>) {
            self.value = value
        }

        @objc func valueChanged(_ sender: NSSlider) {
            value.wrappedValue = sender.doubleValue
        }
    }
}

private final class QuietNSSlider: NSSlider {
    var suppressAction = false

    override func sendAction(_ action: Selector?, to target: Any?) -> Bool {
        guard !suppressAction else {
            return false
        }

        return super.sendAction(action, to: target)
    }
}

private struct GradientContinuousSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let gradient: LinearGradient

    private let handleDiameter: CGFloat = 14

    var body: some View {
        GeometryReader { geometry in
            let usableWidth = max(geometry.size.width - handleDiameter, 1)
            let normalized = normalizedValue
            let handleX = handleDiameter / 2 + usableWidth * normalized

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.06))

                Capsule()
                    .fill(gradient)
                    .padding(.vertical, 3)
                    .overlay {
                        Capsule()
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            .padding(.vertical, 3)
                    }

                Circle()
                    .fill(.white)
                    .frame(width: handleDiameter, height: handleDiameter)
                    .overlay {
                        Circle()
                            .stroke(Color.black.opacity(0.18), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.22), radius: 3, y: 1)
                    .position(x: handleX, y: geometry.size.height / 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        updateValue(from: gesture.location.x, width: geometry.size.width)
                    }
            )
        }
    }

    private var normalizedValue: CGFloat {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else {
            return 0
        }

        return CGFloat(((value - range.lowerBound) / span).clamped(to: 0...1))
    }

    private func updateValue(from x: CGFloat, width: CGFloat) {
        let usableWidth = max(width - handleDiameter, 1)
        let clampedX = min(max(x, handleDiameter / 2), width - handleDiameter / 2)
        let normalized = Double((clampedX - handleDiameter / 2) / usableWidth)
        let span = range.upperBound - range.lowerBound
        value = (range.lowerBound + normalized * span).clamped(to: range)
    }
}
