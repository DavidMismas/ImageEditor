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

    enum GeometryRenderStage: Sendable {
        case full
        case orientedPreview
    }

    func renderEdited(
        from baseImage: CIImage,
        asset: PhotoAsset,
        settings: AdjustmentSettings,
        presets: [UUID: LUTPreset],
        quality: RenderQuality,
        geometryStage: GeometryRenderStage = .full
    ) async -> CIImage {
        var image = normalizeSourceImage(applyGeometry(to: baseImage, settings: settings, stage: geometryStage))
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

    func renderReference(
        from baseImage: CIImage,
        settings: AdjustmentSettings,
        geometryStage: GeometryRenderStage = .full
    ) -> CIImage {
        normalizeSourceImage(applyGeometry(to: baseImage, settings: settings, stage: geometryStage))
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

    private func applyGeometry(
        to image: CIImage,
        settings: AdjustmentSettings,
        stage: GeometryRenderStage
    ) -> CIImage {
        let crop = settings.crop
        let oriented = applyOrientation(to: image, crop: crop)
        guard stage == .full else {
            return oriented
        }

        let baseCropRect = CropMath.cropRect(for: oriented.extent, crop: crop, flipY: true)
        let aspectRatio = CropMath.aspectRatio(for: crop.aspectPreset, in: oriented.extent.size)
        let cropRect = CropMath.fittedRectInsideCoverage(
            from: baseCropRect,
            extent: oriented.extent,
            straightenDegrees: crop.straighten,
            aspectRatio: aspectRatio,
            minimumLength: 36
        )

        guard abs(crop.straighten) > 0.0001 else {
            return oriented.cropped(to: cropRect)
        }

        let center = CGPoint(x: oriented.extent.midX, y: oriented.extent.midY)
        var straightenTransform = CGAffineTransform.identity
        straightenTransform = straightenTransform.translatedBy(x: center.x, y: center.y)
        straightenTransform = straightenTransform.rotated(by: CGFloat(crop.straighten * .pi / 180))
        straightenTransform = straightenTransform.translatedBy(x: -center.x, y: -center.y)

        let straightened = oriented
            .clampedToExtent()
            .transformed(by: straightenTransform)

        return straightened.cropped(to: cropRect)
    }

    private func applyOrientation(to image: CIImage, crop: CropSettings) -> CIImage {
        let transform = CropMath.orientationTransform(for: image.extent, crop: crop)
        return image.transformed(by: transform)
    }
}

typealias AdjustmentPipeline = ImageAdjustmentPipeline
