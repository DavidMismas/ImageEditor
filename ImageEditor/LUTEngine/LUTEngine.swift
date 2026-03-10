@preconcurrency import CoreImage
import Foundation
import simd

struct LUTEngine: Sendable {
    private let parser = LUTParser()

    func importLUT(from url: URL) throws -> LUTPreset {
        try parser.parse(at: url)
    }

    func apply(selection: LUTSelection, presets: [UUID: LUTPreset], to image: CIImage) -> CIImage {
        guard let selectedLUTID = selection.selectedLUTID,
              let preset = presets[selectedLUTID],
              selection.intensity > 0 else {
            return image
        }

        let compressedInput = AdjustmentKernels.sceneCompress?.apply(
            extent: image.extent,
            arguments: [image]
        ) ?? image

        var mappedInput = compressedInput
        if preset.domainMin != SIMD3<Float>(repeating: 0) || preset.domainMax != SIMD3<Float>(repeating: 1) {
            mappedInput = AdjustmentKernels.domainRemap?.apply(
                extent: compressedInput.extent,
                arguments: [
                    compressedInput,
                    CIVector(x: CGFloat(preset.domainMin.x), y: CGFloat(preset.domainMin.y), z: CGFloat(preset.domainMin.z)),
                    CIVector(x: CGFloat(preset.domainMax.x), y: CGFloat(preset.domainMax.y), z: CGFloat(preset.domainMax.z))
                ]
            ) ?? compressedInput
        }

        guard let filter = CIFilter(name: "CIColorCubeWithColorSpace") else {
            return image
        }

        filter.setValue(mappedInput, forKey: kCIInputImageKey)
        filter.setValue(preset.dimension, forKey: "inputCubeDimension")
        filter.setValue(preset.cubeData, forKey: "inputCubeData")
        filter.setValue(ColorPipeline.workingColorSpace, forKey: "inputColorSpace")
        filter.setValue(true, forKey: "inputExtrapolate")

        guard let processedImage = filter.outputImage else {
            return image
        }

        let intensity = Float(selection.intensity.clamped(to: 0...100) / 100)
        let blended = AdjustmentKernels.blend?.apply(
            extent: compressedInput.extent,
            arguments: [compressedInput, processedImage, intensity]
        ) ?? processedImage

        // The LUT runs in the same bounded domain used by the selective color cube.
        // Expand back into the linear working space so even an identity LUT preserves
        // scene energy instead of brightening the image.
        return AdjustmentKernels.sceneExpand?.apply(
            extent: blended.extent,
            arguments: [blended]
        ) ?? blended
    }
}

typealias LUTProcessor = LUTEngine
