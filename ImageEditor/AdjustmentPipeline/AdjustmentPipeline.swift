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
        quality: RenderQuality
    ) async -> CIImage {
        var image = normalizeSourceImage(applyGeometry(to: baseImage, settings: settings))
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

    func renderReference(from baseImage: CIImage, settings: AdjustmentSettings) -> CIImage {
        normalizeSourceImage(applyGeometry(to: baseImage, settings: settings))
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

    private func applyGeometry(to image: CIImage, settings: AdjustmentSettings) -> CIImage {
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
        let cropRect = cropRect(for: transformedExtent, crop: crop)
        return transformed.cropped(to: cropRect.integral)
    }

    private func cropRect(for extent: CGRect, crop: CropSettings) -> CGRect {
        let zoom = CGFloat(crop.zoom.clamped(to: 1...5))
        let aspectRatio: CGFloat? = switch crop.aspectPreset {
        case .original:
            extent.width / max(extent.height, 1)
        case .free:
            nil
        default:
            CGFloat(crop.aspectPreset.aspectRatio ?? 1)
        }

        var cropWidth = extent.width
        var cropHeight = extent.height

        if let aspectRatio {
            if extent.width / max(extent.height, 1) > aspectRatio {
                cropHeight = extent.height / zoom
                cropWidth = cropHeight * aspectRatio
            } else {
                cropWidth = extent.width / zoom
                cropHeight = cropWidth / max(aspectRatio, 0.0001)
            }
        } else {
            cropWidth = extent.width * CGFloat(crop.freeformWidth.clamped(to: 0.2...1))
            cropHeight = extent.height * CGFloat(crop.freeformHeight.clamped(to: 0.2...1))
            cropWidth /= zoom
            cropHeight /= zoom
        }

        cropWidth = max(16, min(cropWidth, extent.width))
        cropHeight = max(16, min(cropHeight, extent.height))

        let centerX = extent.minX + extent.width * CGFloat(crop.centerX.clamped(to: 0...1))
        let centerY = extent.minY + extent.height * CGFloat(crop.centerY.clamped(to: 0...1))

        var originX = centerX - cropWidth / 2
        var originY = centerY - cropHeight / 2

        originX = originX.clamped(to: extent.minX...(extent.maxX - cropWidth))
        originY = originY.clamped(to: extent.minY...(extent.maxY - cropHeight))

        return CGRect(x: originX, y: originY, width: cropWidth, height: cropHeight)
    }
}

typealias AdjustmentPipeline = ImageAdjustmentPipeline
