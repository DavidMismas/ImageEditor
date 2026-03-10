import Foundation
import simd

struct ColorCubeSignature: Hashable, Sendable {
    let saturation: Int
    let vibrance: Int
    let color: ColorAdjustments
    let dimension: Int

    init(settings: AdjustmentSettings, dimension: Int) {
        saturation = Int(settings.base.saturation.rounded())
        vibrance = Int(settings.base.vibrance.rounded())
        color = settings.color
        self.dimension = dimension
    }
}

actor ColorCubeBuilder {
    private var cache: [ColorCubeSignature: Data] = [:]

    private let globalProcessor = GlobalColorProcessor()
    private let hslProcessor = HSLProcessor()
    private let gradingProcessor = ColorGradingProcessor()

    func cubeData(for settings: AdjustmentSettings, dimension: Int) -> Data {
        let signature = ColorCubeSignature(settings: settings, dimension: dimension)
        if let cached = cache[signature] {
            return cached
        }

        let data = buildCube(signature: signature)
        cache[signature] = data
        return data
    }

    private func buildCube(signature: ColorCubeSignature) -> Data {
        let dimension = signature.dimension
        let maxIndex = Float(max(dimension - 1, 1))
        let curveProcessor = CurveProcessor(settings: signature.color.curves)
        var data = [Float]()
        data.reserveCapacity(dimension * dimension * dimension * 4)

        // The cube runs in a bounded scene-referred domain. The pipeline compresses
        // extended linear values before entering the cube and expands them afterwards,
        // which preserves highlight latitude while allowing stable perceptual edits.
        for blueIndex in 0..<dimension {
            let blue = Float(blueIndex) / maxIndex
            for greenIndex in 0..<dimension {
                let green = Float(greenIndex) / maxIndex
                for redIndex in 0..<dimension {
                    var color = SIMD3<Float>(Float(redIndex) / maxIndex, green, blue)
                    var lch = ProcessingMath.oklabToLCh(ProcessingMath.linearSRGBToOklab(color))

                    lch = globalProcessor.apply(
                        to: lch,
                        saturation: Double(signature.saturation),
                        vibrance: Double(signature.vibrance)
                    )
                    lch = hslProcessor.apply(to: lch, settings: signature.color.hsl)

                    var lab = ProcessingMath.lChToOklab(lch)
                    lab = gradingProcessor.apply(to: lab, sourceColor: color, settings: signature.color.grading)
                    color = ProcessingMath.oklabToLinearSRGB(lab)
                    color = curveProcessor.apply(to: color)
                    color = simd_clamp(color, SIMD3<Float>(repeating: 0), SIMD3<Float>(repeating: 1))

                    data.append(color.x)
                    data.append(color.y)
                    data.append(color.z)
                    data.append(1)
                }
            }
        }

        return data.withUnsafeBufferPointer { Data(buffer: $0) }
    }
}
