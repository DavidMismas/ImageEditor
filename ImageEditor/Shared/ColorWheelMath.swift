import CoreGraphics
import Foundation
import simd

struct ColorWheelValue: Equatable, Sendable {
    var angleRadians: Double
    var intensity: Double
    var luminance: Double

    init(angleRadians: Double, intensity: Double, luminance: Double = 0) {
        self.angleRadians = ColorWheelMath.normalizeAngle(angleRadians)
        self.intensity = ColorWheelMath.clamp(intensity, to: 0...1)
        self.luminance = ColorWheelMath.clamp(luminance, to: -1...1)
    }
}

enum ColorWheelMath {
    static let defaultDisplayRotationRadians = -Double.pi / 2
    private static let tau = Double.pi * 2
    private static let neutralPreviewRGB = SIMD3<Double>(repeating: 0.18)

    static func normalizeAngle(_ angle: Double) -> Double {
        let wrapped = angle.truncatingRemainder(dividingBy: tau)
        return wrapped >= 0 ? wrapped : wrapped + tau
    }

    static func angleToHueUnit(_ angle: Double) -> Double {
        normalizeAngle(angle) / tau
    }

    static func hueUnitToAngle(_ hueUnit: Double) -> Double {
        normalizeAngle(hueUnit.truncatingRemainder(dividingBy: 1) * tau)
    }

    static func angleFromDegrees(_ degrees: Double) -> Double {
        hueUnitToAngle(degrees / 360)
    }

    static func degrees(from angleRadians: Double) -> Double {
        angleToHueUnit(angleRadians) * 360
    }

    static func pointToWheelValue(
        point: CGPoint,
        center: CGPoint,
        maxRadius: CGFloat,
        displayRotationRadians: Double
    ) -> ColorWheelValue {
        let dx = Double(point.x - center.x)
        let dy = Double(point.y - center.y)
        let distance = sqrt(dx * dx + dy * dy)
        let displayAngle = normalizeAngle(atan2(dy, dx))
        let canonicalAngle = normalizeAngle(displayAngle - displayRotationRadians)
        let safeRadius = max(Double(maxRadius), 0.0001)
        let intensity = clamp(distance / safeRadius, to: 0...1)
        return ColorWheelValue(angleRadians: canonicalAngle, intensity: intensity)
    }

    static func wheelValueToPoint(
        _ value: ColorWheelValue,
        center: CGPoint,
        maxRadius: CGFloat,
        displayRotationRadians: Double
    ) -> CGPoint {
        let displayAngle = normalizeAngle(value.angleRadians + displayRotationRadians)
        let radius = Double(maxRadius) * value.intensity
        let dx = cos(displayAngle) * radius
        let dy = sin(displayAngle) * radius
        return CGPoint(
            x: center.x + CGFloat(dx),
            y: center.y + CGFloat(dy)
        )
    }

    static func hueToPreviewRGB(_ hueUnit: Double) -> SIMD3<Double> {
        let rgb = hsvToSRGB(hueUnit: hueUnit, saturation: 1, value: 1)
        return SIMD3<Double>(
            sRGBToLinear(rgb.x),
            sRGBToLinear(rgb.y),
            sRGBToLinear(rgb.z)
        )
    }

    static func wheelValueToProcessingTint(_ value: ColorWheelValue) -> SIMD3<Double> {
        let hueRGB = hueToPreviewRGB(angleToHueUnit(value.angleRadians))
        let centered = hueRGB - SIMD3<Double>(repeating: 0.5)
        let magnitude = simd_length(centered)
        guard magnitude > 0.000_001 else {
            return SIMD3<Double>(repeating: 0)
        }

        return centered / magnitude * value.intensity
    }

    static func wheelValueToRGBPreview(_ value: ColorWheelValue) -> SIMD3<Double> {
        let hueRGB = hueToPreviewRGB(angleToHueUnit(value.angleRadians))
        return mix(neutralPreviewRGB, hueRGB, amount: value.intensity)
    }

    static func wheelValueToLabTint(_ value: ColorWheelValue) -> SIMD2<Double> {
        let hueRGB = hueToPreviewRGB(angleToHueUnit(value.angleRadians))
        let lab = linearSRGBToOklab(hueRGB)
        let chroma = SIMD2<Double>(lab.y, lab.z)
        let magnitude = simd_length(chroma)
        guard magnitude > 0.000_001 else {
            return SIMD2<Double>(repeating: 0)
        }

        return chroma / magnitude * value.intensity
    }

    private static func hsvToSRGB(hueUnit: Double, saturation: Double, value: Double) -> SIMD3<Double> {
        let safeHue = hueUnit.truncatingRemainder(dividingBy: 1) >= 0
            ? hueUnit.truncatingRemainder(dividingBy: 1)
            : hueUnit.truncatingRemainder(dividingBy: 1) + 1
        let scaled = safeHue * 6
        let sector = Int(floor(scaled)) % 6
        let fraction = scaled - floor(scaled)
        let p = value * (1 - saturation)
        let q = value * (1 - fraction * saturation)
        let t = value * (1 - (1 - fraction) * saturation)

        switch sector {
        case 0:
            return SIMD3<Double>(value, t, p)
        case 1:
            return SIMD3<Double>(q, value, p)
        case 2:
            return SIMD3<Double>(p, value, t)
        case 3:
            return SIMD3<Double>(p, q, value)
        case 4:
            return SIMD3<Double>(t, p, value)
        default:
            return SIMD3<Double>(value, p, q)
        }
    }

    private static func sRGBToLinear(_ value: Double) -> Double {
        value <= 0.04045
            ? value / 12.92
            : Foundation.pow((value + 0.055) / 1.055, 2.4)
    }

    private static func linearSRGBToOklab(_ color: SIMD3<Double>) -> SIMD3<Double> {
        let l = 0.4122214708 * color.x + 0.5363325363 * color.y + 0.0514459929 * color.z
        let m = 0.2119034982 * color.x + 0.6806995451 * color.y + 0.1073969566 * color.z
        let s = 0.0883024619 * color.x + 0.2817188376 * color.y + 0.6299787005 * color.z

        let lPrime = cubeRoot(max(l, 0))
        let mPrime = cubeRoot(max(m, 0))
        let sPrime = cubeRoot(max(s, 0))

        return SIMD3<Double>(
            0.2104542553 * lPrime + 0.7936177850 * mPrime - 0.0040720468 * sPrime,
            1.9779984951 * lPrime - 2.4285922050 * mPrime + 0.4505937099 * sPrime,
            0.0259040371 * lPrime + 0.7827717662 * mPrime - 0.8086757660 * sPrime
        )
    }

    private static func cubeRoot(_ value: Double) -> Double {
        guard value != 0 else {
            return 0
        }

        return value > 0
            ? Foundation.pow(value, 1.0 / 3.0)
            : -Foundation.pow(-value, 1.0 / 3.0)
    }

    private static func mix(_ a: SIMD3<Double>, _ b: SIMD3<Double>, amount: Double) -> SIMD3<Double> {
        a + (b - a) * clamp(amount, to: 0...1)
    }

    fileprivate static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
