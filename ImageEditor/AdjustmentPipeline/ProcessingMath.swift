import Foundation
import simd

enum ProcessingMath {
    static let luminanceWeights = SIMD3<Float>(0.2126, 0.7152, 0.0722)

    private static let oklabForward = simd_float3x3(
        columns: (
            SIMD3<Float>(0.4122214708, 0.2119034982, 0.0883024619),
            SIMD3<Float>(0.5363325363, 0.6806995451, 0.2817188376),
            SIMD3<Float>(0.0514459929, 0.1073969566, 0.6299787005)
        )
    )

    private static let oklabInverse = simd_float3x3(
        columns: (
            SIMD3<Float>(4.0767416621, -1.2684380046, -0.0041960863),
            SIMD3<Float>(-3.3077115913, 2.6097574011, -0.7034186147),
            SIMD3<Float>(0.2309699292, -0.3413193965, 1.7076147010)
        )
    )

    static func linearLuminance(_ color: SIMD3<Float>) -> Float {
        simd_dot(color, luminanceWeights)
    }

    static func compressSceneValue(_ value: Float) -> Float {
        let clamped = max(value, 0)
        return clamped / (1 + clamped)
    }

    static func expandSceneValue(_ value: Float) -> Float {
        let clamped = value.clamped(to: 0...0.9995)
        return clamped / max(1 - clamped, 0.0005)
    }

    static func linearSRGBToOklab(_ color: SIMD3<Float>) -> SIMD3<Float> {
        let clipped = simd.max(color, SIMD3<Float>(repeating: 0))
        let lms = oklabForward * clipped
        let lmsPrime = SIMD3<Float>(
            cubeRoot(lms.x),
            cubeRoot(lms.y),
            cubeRoot(lms.z)
        )

        return SIMD3<Float>(
            0.2104542553 * lmsPrime.x + 0.7936177850 * lmsPrime.y - 0.0040720468 * lmsPrime.z,
            1.9779984951 * lmsPrime.x - 2.4285922050 * lmsPrime.y + 0.4505937099 * lmsPrime.z,
            0.0259040371 * lmsPrime.x + 0.7827717662 * lmsPrime.y - 0.8086757660 * lmsPrime.z
        )
    }

    static func oklabToLinearSRGB(_ lab: SIMD3<Float>) -> SIMD3<Float> {
        let l = lab.x + 0.3963377774 * lab.y + 0.2158037573 * lab.z
        let m = lab.x - 0.1055613458 * lab.y - 0.0638541728 * lab.z
        let s = lab.x - 0.0894841775 * lab.y - 1.2914855480 * lab.z

        let l3 = l * l * l
        let m3 = m * m * m
        let s3 = s * s * s

        return simd.max(oklabInverse * SIMD3<Float>(l3, m3, s3), SIMD3<Float>(repeating: 0))
    }

    static func linearToSRGB(_ color: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3<Float>(
            linearToSRGB(color.x),
            linearToSRGB(color.y),
            linearToSRGB(color.z)
        )
    }

    static func sRGBToLinear(_ color: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3<Float>(
            sRGBToLinear(color.x),
            sRGBToLinear(color.y),
            sRGBToLinear(color.z)
        )
    }

    static func oklabToLCh(_ lab: SIMD3<Float>) -> SIMD3<Float> {
        let chroma = sqrt(lab.y * lab.y + lab.z * lab.z)
        let hue = wrapDegrees(atan2(lab.z, lab.y) * 180 / .pi)
        return SIMD3<Float>(lab.x, hue, chroma)
    }

    static func lChToOklab(_ lch: SIMD3<Float>) -> SIMD3<Float> {
        let radians = lch.y * .pi / 180
        return SIMD3<Float>(
            lch.x,
            Foundation.cos(Double(radians)).toFloat * lch.z,
            Foundation.sin(Double(radians)).toFloat * lch.z
        )
    }

    static func softHueWeight(hue: Float, center: Float, width: Float) -> Float {
        let distance = circularHueDistance(hue, center)
        guard distance < width else {
            return 0
        }

        let normalized = 1 - distance / width
        return smootherstep(normalized)
    }

    static func circularHueDistance(_ a: Float, _ b: Float) -> Float {
        let delta = abs(a - b).truncatingRemainder(dividingBy: 360)
        return min(delta, 360 - delta)
    }

    static func smoothstep(_ edge0: Float, _ edge1: Float, _ value: Float) -> Float {
        let x = ((value - edge0) / max(edge1 - edge0, 0.0001)).clamped(to: 0...1)
        return x * x * (3 - 2 * x)
    }

    static func smootherstep(_ value: Float) -> Float {
        let x = value.clamped(to: 0...1)
        return x * x * x * (x * (x * 6 - 15) + 10)
    }

    static func mix(_ a: Float, _ b: Float, amount: Float) -> Float {
        a + (b - a) * amount
    }

    static func mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>, amount: Float) -> SIMD3<Float> {
        a + (b - a) * amount
    }

    static func wrapDegrees(_ degrees: Float) -> Float {
        let wrapped = degrees.truncatingRemainder(dividingBy: 360)
        return wrapped >= 0 ? wrapped : wrapped + 360
    }

    static func cubeRoot(_ value: Float) -> Float {
        guard value != 0 else {
            return 0
        }

        return value > 0
            ? Foundation.pow(Double(value), 1.0 / 3.0).toFloat
            : -Foundation.pow(Double(-value), 1.0 / 3.0).toFloat
    }

    private static func linearToSRGB(_ value: Float) -> Float {
        let clamped = max(value, 0)
        if clamped <= 0.0031308 {
            return clamped * 12.92
        }

        return (1.055 * Foundation.pow(Double(clamped), 1.0 / 2.4).toFloat) - 0.055
    }

    private static func sRGBToLinear(_ value: Float) -> Float {
        let clamped = value.clamped(to: 0...1)
        if clamped <= 0.04045 {
            return clamped / 12.92
        }

        return Foundation.pow(Double((clamped + 0.055) / 1.055), 2.4).toFloat
    }
}

private extension Double {
    var toFloat: Float { Float(self) }
}
