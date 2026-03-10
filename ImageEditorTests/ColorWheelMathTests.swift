import CoreGraphics
import XCTest
@testable import ImageEditorWheelMath

final class ColorWheelMathTests: XCTestCase {
    func testCanonicalHuePreviewColors() {
        assertHue(0, expectsHigh: [.red], expectsLow: [.green, .blue])
        assertHue(60, expectsHigh: [.red, .green], expectsLow: [.blue])
        assertHue(120, expectsHigh: [.green], expectsLow: [.red, .blue])
        assertHue(180, expectsHigh: [.green, .blue], expectsLow: [.red])
        assertHue(240, expectsHigh: [.blue], expectsLow: [.red, .green])
        assertHue(300, expectsHigh: [.red, .blue], expectsLow: [.green])
    }

    func testPointToAngleUsesCanonicalOrientation() {
        let center = CGPoint(x: 100, y: 100)
        let radius: CGFloat = 60

        let right = ColorWheelMath.pointToWheelValue(
            point: CGPoint(x: 160, y: 100),
            center: center,
            maxRadius: radius,
            displayRotationRadians: ColorWheelMath.defaultDisplayRotationRadians
        )

        XCTAssertEqual(ColorWheelMath.degrees(from: right.angleRadians), 0, accuracy: 0.0001)
        XCTAssertEqual(right.intensity, 1, accuracy: 0.0001)
    }

    func testAnglePointRoundTrip() {
        let value = ColorWheelValue(
            angleRadians: ColorWheelMath.hueUnitToAngle(240.0 / 360.0),
            intensity: 0.72,
            luminance: -0.15
        )
        let center = CGPoint(x: 90, y: 90)
        let radius: CGFloat = 50

        let point = ColorWheelMath.wheelValueToPoint(
            value,
            center: center,
            maxRadius: radius,
            displayRotationRadians: ColorWheelMath.defaultDisplayRotationRadians
        )
        let roundTrip = ColorWheelMath.pointToWheelValue(
            point: point,
            center: center,
            maxRadius: radius,
            displayRotationRadians: ColorWheelMath.defaultDisplayRotationRadians
        )

        XCTAssertEqual(roundTrip.intensity, value.intensity, accuracy: 0.0001)
        XCTAssertEqual(roundTrip.angleRadians, value.angleRadians, accuracy: 0.0001)
    }

    func testProcessingTintTracksHueFamily() {
        let redTint = ColorWheelMath.wheelValueToProcessingTint(
            ColorWheelValue(angleRadians: ColorWheelMath.hueUnitToAngle(0), intensity: 1)
        )
        XCTAssertGreaterThan(redTint.x, redTint.y)
        XCTAssertGreaterThan(redTint.x, redTint.z)

        let blueTint = ColorWheelMath.wheelValueToProcessingTint(
            ColorWheelValue(angleRadians: ColorWheelMath.hueUnitToAngle(240.0 / 360.0), intensity: 1)
        )
        XCTAssertGreaterThan(blueTint.z, blueTint.x)
        XCTAssertGreaterThan(blueTint.z, blueTint.y)
    }

    private func assertHue(
        _ degrees: Double,
        expectsHigh highChannels: [Channel],
        expectsLow lowChannels: [Channel]
    ) {
        let rgb = ColorWheelMath.hueToPreviewRGB(degrees / 360)
        for channel in highChannels {
            XCTAssertGreaterThan(channel.value(in: rgb), 0.9, "expected \(degrees)° to keep \(channel) high")
        }
        for channel in lowChannels {
            XCTAssertLessThan(channel.value(in: rgb), 0.1, "expected \(degrees)° to keep \(channel) low")
        }
    }
}

private enum Channel: String {
    case red
    case green
    case blue

    func value(in rgb: SIMD3<Double>) -> Double {
        switch self {
        case .red:
            return rgb.x
        case .green:
            return rgb.y
        case .blue:
            return rgb.z
        }
    }
}
