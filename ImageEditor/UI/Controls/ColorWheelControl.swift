import Foundation
import SwiftUI

struct ColorWheelControl: View {
    let title: String
    @Binding var hue: Double
    @Binding var intensity: Double
    var diameter: CGFloat = 92
    var showsReadout = false

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            let wheelValue = currentWheelValue
            let previewRGB = ColorWheelMath.wheelValueToRGBPreview(wheelValue)
            let processingTint = ColorWheelMath.wheelValueToProcessingTint(wheelValue)

            Text(title)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            GeometryReader { geometry in
                let diameter = min(geometry.size.width, geometry.size.height)
                let radius = diameter / 2
                let interactionRadius = radius * 0.55
                let handlePoint = ColorWheelMath.wheelValueToPoint(
                    wheelValue,
                    center: CGPoint(x: radius, y: radius),
                    maxRadius: interactionRadius,
                    displayRotationRadians: ColorWheelMath.defaultDisplayRotationRadians
                )

                ZStack {
                    Circle()
                        .strokeBorder(
                            AngularGradient(gradient: Gradient(stops: gradientStops), center: .center),
                            lineWidth: diameter * 0.13
                        )
                        .rotationEffect(.radians(ColorWheelMath.defaultDisplayRotationRadians))

                    Circle()
                        .fill(centerColor.opacity(0.28))
                        .padding(diameter * 0.2)

                    Circle()
                        .strokeBorder(.white.opacity(0.75), lineWidth: 1.5)
                        .frame(width: 12, height: 12)
                        .position(handlePoint)
                        .shadow(radius: 2)
                }
                .contentShape(Circle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            updateValue(from: value.location, size: geometry.size)
                        }
                )
            }
            .frame(width: diameter, height: diameter)

            if showsReadout {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(previewColor(from: previewRGB))
                            .frame(width: 18, height: 12)
                        Text(
                            String(
                                format: "deg %.1f  hue %.3f  int %.2f",
                                ColorWheelMath.degrees(from: wheelValue.angleRadians),
                                ColorWheelMath.angleToHueUnit(wheelValue.angleRadians),
                                wheelValue.intensity
                            )
                        )
                    }
                    Text(
                        String(
                            format: "preview %.2f %.2f %.2f",
                            previewRGB.x,
                            previewRGB.y,
                            previewRGB.z
                        )
                    )
                    Text(
                        String(
                            format: "tint %.2f %.2f %.2f",
                            processingTint.x,
                            processingTint.y,
                            processingTint.z
                        )
                    )
                }
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
            }
        }
    }

    private func updateValue(from location: CGPoint, size: CGSize) {
        let radius = min(size.width, size.height) / 2
        let center = CGPoint(x: radius, y: radius)
        let wheelValue = ColorWheelMath.pointToWheelValue(
            point: location,
            center: center,
            maxRadius: radius * 0.55,
            displayRotationRadians: ColorWheelMath.defaultDisplayRotationRadians
        )

        hue = ColorWheelMath.degrees(from: wheelValue.angleRadians)
        intensity = (wheelValue.intensity * 100).clamped(to: 0...100)

        #if DEBUG
        if showsReadout {
            print(
                String(
                    format: "[ColorWheel] %@ point(%.1f, %.1f) -> deg %.1f hue %.3f intensity %.3f",
                    title,
                    location.x,
                    location.y,
                    hue,
                    ColorWheelMath.angleToHueUnit(wheelValue.angleRadians),
                    wheelValue.intensity
                )
            )
        }
        #endif
    }

    private var gradientStops: [Gradient.Stop] {
        stride(from: 0.0, through: 1.0, by: 1.0 / 24.0).map { hueUnit in
            Gradient.Stop(
                color: previewColor(from: ColorWheelMath.hueToPreviewRGB(hueUnit)),
                location: hueUnit
            )
        }
    }

    private var centerColor: Color {
        previewColor(from: ColorWheelMath.wheelValueToRGBPreview(currentWheelValue))
    }

    private var currentWheelValue: ColorWheelValue {
        ColorWheelValue(
            angleRadians: ColorWheelMath.angleFromDegrees(hue),
            intensity: intensity / 100
        )
    }

    private func previewColor(from preview: SIMD3<Double>) -> Color {
        return Color(
            .sRGBLinear,
            red: preview.x,
            green: preview.y,
            blue: preview.z,
            opacity: 1
        )
    }
}
