@preconcurrency import CoreImage
import Foundation
import simd

struct WhiteBalanceProcessor: Sendable {
    private let rgbToLMS = simd_float3x3(
        columns: (
            SIMD3<Float>(0.8951, -0.7502, 0.0389),
            SIMD3<Float>(0.2664, 1.7135, -0.0685),
            SIMD3<Float>(-0.1614, 0.0367, 1.0296)
        )
    )

    private let lmsToRGB = simd_float3x3(
        columns: (
            SIMD3<Float>(0.9869929, 0.4323053, -0.0085287),
            SIMD3<Float>(-0.1470543, 0.5183603, 0.0400428),
            SIMD3<Float>(0.1599627, 0.0492912, 0.9684867)
        )
    )

    func apply(to image: CIImage, asset: PhotoAsset, settings: AdjustmentSettings) -> CIImage {
        guard !asset.isRAW else {
            return image
        }

        let temperature = Float(settings.base.temperature / 100)
        let tint = Float(settings.base.tint / 100)
        guard temperature != 0 || tint != 0 else {
            return image
        }

        let matrix = whiteBalanceMatrix(temperature: temperature, tint: tint)
        return applyMatrix(matrix, to: image)
    }

    private func whiteBalanceMatrix(temperature: Float, tint: Float) -> simd_float3x3 {
        // Bradford-like LMS scaling gives temperature/tint behavior that is much closer
        // to photographic white balance than naive RGB offsets.
        let lGain = Foundation.pow(2.0, Double((temperature * 0.22) + (tint * 0.05))).toFloat
        let mGain = Foundation.pow(2.0, Double(-tint * 0.16)).toFloat
        let sGain = Foundation.pow(2.0, Double((-temperature * 0.28) + (tint * 0.05))).toFloat
        let diagonal = simd_float3x3(diagonal: SIMD3<Float>(lGain, mGain, sGain))
        return lmsToRGB * diagonal * rgbToLMS
    }

    private func applyMatrix(_ matrix: simd_float3x3, to image: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CIColorMatrix") else {
            return image
        }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(vector(from: matrix.columns.0), forKey: "inputRVector")
        filter.setValue(vector(from: matrix.columns.1), forKey: "inputGVector")
        filter.setValue(vector(from: matrix.columns.2), forKey: "inputBVector")
        filter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
        filter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputBiasVector")
        return filter.outputImage ?? image
    }

    private func vector(from column: SIMD3<Float>) -> CIVector {
        CIVector(x: CGFloat(column.x), y: CGFloat(column.y), z: CGFloat(column.z), w: 0)
    }
}

private extension Double {
    var toFloat: Float { Float(self) }
}
