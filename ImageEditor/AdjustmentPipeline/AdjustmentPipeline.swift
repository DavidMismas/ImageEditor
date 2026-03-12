@preconcurrency import CoreImage
import CoreGraphics
import Foundation

actor ImageAdjustmentPipeline {
    private let baseToneProcessor = BaseToneProcessor()
    private let whiteBalanceProcessor = WhiteBalanceProcessor()
    private let clarityProcessor = ClarityProcessor()
    private let sharpenProcessor = SharpenProcessor()
    private let vignetteProcessor = VignetteProcessor()
    private let grainProcessor = GrainProcessor()
    private let cubeBuilder = ColorCubeBuilder()
    private let lutEngine = LUTEngine()

    func renderEdited(
        from baseImage: CIImage,
        asset: PhotoAsset,
        settings: AdjustmentSettings,
        presets: [UUID: LUTPreset],
        quality: RenderQuality,
        includeCrop: Bool = true
    ) async -> CIImage {
        var image = normalizeSourceImage(applyGeometry(to: baseImage, settings: settings, includeCrop: includeCrop))
        image = baseToneProcessor.apply(to: image, asset: asset, settings: settings)
        image = whiteBalanceProcessor.apply(to: image, asset: asset, settings: settings)
        image = await applySelectiveColorAdjustments(to: image, settings: settings, quality: quality)
        image = clarityProcessor.apply(to: image, amount: settings.effects.clarity)
        image = sharpenProcessor.apply(to: image, amount: settings.effects.sharpness)
        image = vignetteProcessor.apply(to: image, amount: settings.effects.vignette)
        image = grainProcessor.apply(to: image, amount: settings.effects.grain)
        image = lutEngine.apply(selection: settings.lut, presets: presets, to: image)
        return image
    }

    func renderReference(from baseImage: CIImage, settings: AdjustmentSettings, includeCrop: Bool = true) -> CIImage {
        normalizeSourceImage(applyGeometry(to: baseImage, settings: settings, includeCrop: includeCrop))
    }

    private func normalizeSourceImage(_ image: CIImage) -> CIImage {
        // Core Image converts source images into the linear working space declared on
        // the CIContext. This stage exists to make that normalization boundary explicit.
        image
    }

    private func applySelectiveColorAdjustments(
        to image: CIImage,
        settings: AdjustmentSettings,
        quality: RenderQuality
    ) async -> CIImage {
        guard settings.base.saturation != 0
                || settings.base.vibrance != 0
                || settings.color != ColorAdjustments() else {
            return image
        }

        let compressed = AdjustmentKernels.sceneCompress?.apply(
            extent: image.extent,
            arguments: [image]
        ) ?? image

        let cubeDimension = quality.selectiveColorCubeDimension
        let cubeData = await cubeBuilder.cubeData(for: settings, dimension: cubeDimension)

        guard let filter = CIFilter(name: "CIColorCube") else {
            return image
        }

        filter.setValue(compressed, forKey: kCIInputImageKey)
        filter.setValue(cubeDimension, forKey: "inputCubeDimension")
        filter.setValue(cubeData, forKey: "inputCubeData")
        filter.setValue(true, forKey: "inputExtrapolate")

        guard let boundedOutput = filter.outputImage else {
            return image
        }

        return AdjustmentKernels.sceneExpand?.apply(
            extent: boundedOutput.extent,
            arguments: [boundedOutput]
        ) ?? boundedOutput
    }

    private func applyGeometry(to image: CIImage, settings: AdjustmentSettings, includeCrop: Bool) -> CIImage {
        let crop = settings.crop
        let sourceExtent = image.extent
        let center = CGPoint(x: sourceExtent.midX, y: sourceExtent.midY)
        let angle = CGFloat((Double(crop.rotationQuarterTurns) * 90 + crop.straighten) * .pi / 180)

        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: center.x, y: center.y)
        transform = transform.scaledBy(
            x: crop.flipHorizontal ? -1 : 1,
            y: crop.flipVertical ? -1 : 1
        )
        transform = transform.rotated(by: angle)
        transform = transform.translatedBy(x: -center.x, y: -center.y)

        let transformed = image.transformed(by: transform)
        let transformedExtent = transformed.extent.integral
        guard includeCrop else {
            return transformed
        }

        let cropRect = CropMath.cropRect(for: transformedExtent, crop: crop)
        return transformed.cropped(to: cropRect)
    }
}

typealias AdjustmentPipeline = ImageAdjustmentPipeline
