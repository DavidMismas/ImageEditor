import Foundation
import simd

struct GlobalColorProcessor: Sendable {
    func apply(to lch: SIMD3<Float>, saturation: Double, vibrance: Double) -> SIMD3<Float> {
        let saturationAmount = Float(saturation / 100)
        let vibranceAmount = Float(vibrance / 100)
        guard saturationAmount != 0 || vibranceAmount != 0 else {
            return lch
        }

        var adjusted = lch
        let chroma = adjusted.z
        let chromaMask = ProcessingMath.smoothstep(0.01, 0.14, chroma)
        let chromaNormalized = (chroma / 0.32).clamped(to: 0...1)
        let skinWeight = ProcessingMath.softHueWeight(hue: adjusted.y, center: 42, width: 28) * chromaMask

        adjusted.z *= max(0, 1 + saturationAmount * 0.82)

        let weakColorWeight: Float = vibranceAmount >= 0
            ? 1 - chromaNormalized
            : 0.35 + chromaNormalized * 0.65

        let protectedVibrance = vibranceAmount * weakColorWeight * (1 - skinWeight * 0.5)
        adjusted.z *= Foundation.pow(2.0, Double(protectedVibrance * 0.95)).toFloat
        adjusted.z = max(adjusted.z, 0)
        return adjusted
    }
}

struct HSLProcessor: Sendable {
    func apply(to lch: SIMD3<Float>, settings: HSLSettings) -> SIMD3<Float> {
        let chromaGate = ProcessingMath.smoothstep(0.012, 0.09, lch.z)
        guard chromaGate > 0 else {
            return lch
        }

        var totalWeight: Float = 0
        var hueDelta: Float = 0
        var saturationDelta: Float = 0
        var luminanceDelta: Float = 0

        for channel in settings.channels {
            guard channel.hue != 0 || channel.saturation != 0 || channel.luminance != 0 else {
                continue
            }

            let width = hueWidth(for: channel.channel)
            let weight = ProcessingMath.softHueWeight(hue: lch.y, center: channel.channel.hueCenter, width: width) * chromaGate
            guard weight > 0 else {
                continue
            }

            totalWeight += weight
            hueDelta += weight * Float(channel.hue / 100) * 46
            saturationDelta += weight * Float(channel.saturation / 100)
            luminanceDelta += weight * Float(channel.luminance / 100)
        }

        guard totalWeight > 0 else {
            return lch
        }

        var adjusted = lch
        adjusted.y = ProcessingMath.wrapDegrees(adjusted.y + (hueDelta / totalWeight))
        adjusted.z *= Foundation.pow(2.0, Double((saturationDelta / totalWeight) * 0.9)).toFloat
        adjusted.x = (adjusted.x + (luminanceDelta / totalWeight) * 0.18 * chromaGate).clamped(to: 0...1)
        adjusted.z = max(adjusted.z, 0)
        return adjusted
    }

    private func hueWidth(for channel: HSLChannelKind) -> Float {
        switch channel {
        case .orange:
            return 42
        case .yellow, .aqua:
            return 38
        default:
            return 34
        }
    }
}

struct ColorGradingProcessor: Sendable {
    func apply(to lab: SIMD3<Float>, sourceColor: SIMD3<Float>, settings: ColorGradingSettings) -> SIMD3<Float> {
        // `sourceColor` is already in the bounded grading domain used by the color cube,
        // so using direct luminance here gives the shadows/highlights wheels meaningful
        // range. The highlights mask needs to start earlier than a specular-only
        // shoulder or the wheel feels dead on most photographs.
        let tonal = ProcessingMath.linearLuminance(sourceColor).clamped(to: 0...1)
        let shadowMask = Foundation.pow(Double(1 - ProcessingMath.smoothstep(0.16, 0.52, tonal)), 1.15).toFloat
        let highlightBase = ProcessingMath.smoothstep(0.24, 0.60, tonal)
        let highlightMask = (
            highlightBase * 0.35
            + Foundation.pow(Double(highlightBase), 0.72).toFloat * 0.65
        ).clamped(to: 0...1)

        var adjusted = lab
        adjusted = apply(settings.global, mask: 1, to: adjusted)
        adjusted = apply(settings.shadows, mask: shadowMask, to: adjusted)
        adjusted = apply(settings.highlights, mask: highlightMask, to: adjusted)
        adjusted.x = adjusted.x.clamped(to: 0...1)
        return adjusted
    }

    private func apply(_ wheel: ColorWheelSettings, mask: Float, to lab: SIMD3<Float>) -> SIMD3<Float> {
        let wheelValue = ColorWheelValue(
            angleRadians: ColorWheelMath.angleFromDegrees(wheel.hue),
            intensity: wheel.intensity / 100,
            luminance: wheel.luminance / 100
        )
        guard wheelValue.intensity != 0 || wheelValue.luminance != 0 else {
            return lab
        }

        var adjusted = lab
        let tint = ColorWheelMath.wheelValueToLabTint(wheelValue)
        let chromaAmount = mask * 0.15
        adjusted.y += Float(tint.x) * chromaAmount
        adjusted.z += Float(tint.y) * chromaAmount
        adjusted.x += Float(wheelValue.luminance) * mask * 0.20
        return adjusted
    }
}

struct CurveProcessor: Sendable {
    private let lumaCurve: ToneCurveInterpolator
    private let redCurve: ToneCurveInterpolator
    private let greenCurve: ToneCurveInterpolator
    private let blueCurve: ToneCurveInterpolator

    init(settings: ColorCurveSettings) {
        lumaCurve = ToneCurveInterpolator(curve: settings.luma)
        redCurve = ToneCurveInterpolator(curve: settings.red)
        greenCurve = ToneCurveInterpolator(curve: settings.green)
        blueCurve = ToneCurveInterpolator(curve: settings.blue)
    }

    func apply(to color: SIMD3<Float>) -> SIMD3<Float> {
        var adjusted = simd.max(color, SIMD3<Float>(repeating: 0))
        let luminance = max(ProcessingMath.linearLuminance(adjusted), 0.0001)
        let curvedLuminance = lumaCurve.sample(luminance.clamped(to: 0...1))
        adjusted *= curvedLuminance / luminance

        adjusted.x = redCurve.sample(adjusted.x.clamped(to: 0...1))
        adjusted.y = greenCurve.sample(adjusted.y.clamped(to: 0...1))
        adjusted.z = blueCurve.sample(adjusted.z.clamped(to: 0...1))
        return simd.max(adjusted, SIMD3<Float>(repeating: 0))
    }
}

private extension Double {
    var toFloat: Float { Float(self) }
}
