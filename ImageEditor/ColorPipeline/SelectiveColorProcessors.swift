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

            let width = channel.channel.hueWidth
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
        let normalizedSaturation = (saturationDelta / totalWeight).clamped(to: -1...1)
        adjusted.y = ProcessingMath.wrapDegrees(adjusted.y + (hueDelta / totalWeight))
        adjusted.z *= saturationScale(for: normalizedSaturation)
        adjusted.x = (adjusted.x + (luminanceDelta / totalWeight) * 0.18 * chromaGate).clamped(to: 0...1)
        adjusted.z = max(adjusted.z, 0)
        return adjusted
    }

    private func saturationScale(for amount: Float) -> Float {
        if amount <= 0 {
            // Match pro HSL behavior: -100 can fully neutralize the targeted hue family.
            return max(0, 1 + amount)
        }

        return Foundation.pow(2.0, Double(amount * 0.9)).toFloat
    }
}

struct ColorGradingProcessor: Sendable {
    func apply(to lab: SIMD3<Float>, sourceColor: SIMD3<Float>, settings: ColorGradingSettings) -> SIMD3<Float> {
        // `sourceColor` is already in the bounded grading domain used by the color cube,
        // so using direct luminance here gives the grading masks a stable tonal anchor.
        let tonal = ProcessingMath.linearLuminance(sourceColor).clamped(to: 0...1)
        // Keep shadows out of the midtones so they stop behaving like a second global wheel.
        let shadowMask = Foundation.pow(Double(1 - ProcessingMath.smoothstep(0.10, 0.34, tonal)), 1.45).toFloat
        // Highlights can reach a bit further down into the upper mids, but should still
        // stay meaningfully narrower than the global correction.
        let highlightBase = ProcessingMath.smoothstep(0.20, 0.58, tonal)
        let highlightMask = (
            highlightBase * 0.30
            + Foundation.pow(Double(highlightBase), 0.82).toFloat * 0.70
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
            intensity: wheel.intensity / 100
        )
        // Grading now uses a simpler hue/value model, so legacy luminance
        // values are intentionally ignored to keep the result aligned with the UI.
        guard wheelValue.intensity != 0 else {
            return lab
        }

        var adjusted = lab
        let tint = ColorWheelMath.wheelValueToLabTint(wheelValue)
        let chromaAmount = mask * 0.15
        adjusted.y += Float(tint.x) * chromaAmount
        adjusted.z += Float(tint.y) * chromaAmount
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

        // Apply the master curve in perceptual lightness space so the right side of
        // the graph meaningfully controls highlights instead of only scaling luminance.
        var lab = ProcessingMath.linearSRGBToOklab(adjusted)
        lab.x = lumaCurve.sample(lab.x.clamped(to: 0...1))
        adjusted = ProcessingMath.oklabToLinearSRGB(lab)

        // RGB curves behave more like pro editors when the channel mapping happens in
        // display-encoded space, especially in the bright end of the range.
        var encoded = simd_clamp(
            ProcessingMath.linearToSRGB(adjusted),
            SIMD3<Float>(repeating: 0),
            SIMD3<Float>(repeating: 1)
        )
        encoded.x = redCurve.sample(encoded.x)
        encoded.y = greenCurve.sample(encoded.y)
        encoded.z = blueCurve.sample(encoded.z)
        adjusted = ProcessingMath.sRGBToLinear(encoded)
        return simd.max(adjusted, SIMD3<Float>(repeating: 0))
    }
}

private extension Double {
    var toFloat: Float { Float(self) }
}
