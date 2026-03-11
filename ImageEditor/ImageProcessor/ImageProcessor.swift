@preconcurrency import AppKit
@preconcurrency import CoreImage
import CoreGraphics
import Foundation

struct PreviewCacheKey: Hashable, Sendable {
    let assetID: UUID
    let settings: AdjustmentSettings
    let previewMode: PreviewMode
    let widthBucket: Int
    let heightBucket: Int
    let fullResolutionPreview: Bool
}

struct PreviewRenderResult: @unchecked Sendable {
    let primaryImage: NSImage?
    let comparisonImage: NSImage?
    let histogram: HistogramData
}

actor ImageProcessor {
    private let context: CIContext
    private let decoder = RAWImageDecoder()
    private let pipeline = AdjustmentPipeline()
    private let histogramGenerator = HistogramGenerator()
    private let exportEngine = ExportEngine()
    private let previewCache = RenderCache<PreviewCacheKey, PreviewRenderResult>()

    init() {
        context = ColorPipeline.makeContext()
    }

    func renderPreview(
        asset: PhotoAsset,
        settings: AdjustmentSettings,
        presets: [UUID: LUTPreset],
        targetSize: CGSize,
        previewMode: PreviewMode,
        fullResolutionPreview: Bool
    ) async throws -> PreviewRenderResult {
        let safeTargetSize = CGSize(
            width: max(targetSize.width, 800),
            height: max(targetSize.height, 600)
        )
        let cacheKey = PreviewCacheKey(
            assetID: asset.id,
            settings: settings,
            previewMode: previewMode,
            widthBucket: Int(safeTargetSize.width / 32),
            heightBucket: Int(safeTargetSize.height / 32),
            fullResolutionPreview: fullResolutionPreview
        )

        if let cached = await previewCache.value(for: cacheKey) {
            return cached
        }

        let editedDecoded = try await decoder.decode(
            asset: asset,
            targetLongSide: fullResolutionPreview ? nil : safeTargetSize.longestSide * 1.8,
            isExport: false,
            settings: settings
        )

        let editedImage = await pipeline.renderEdited(
            from: editedDecoded.image,
            asset: asset,
            settings: settings,
            presets: presets,
            quality: .preview
        )
        let referenceSource: CIImage
        if asset.isRAW, previewMode != .edited {
            let referenceDecoded = try await decoder.decode(
                asset: asset,
                targetLongSide: fullResolutionPreview ? nil : safeTargetSize.longestSide * 1.8,
                isExport: false,
                settings: AdjustmentSettings()
            )
            referenceSource = referenceDecoded.image
        } else {
            referenceSource = editedDecoded.image
        }
        let referenceImage = await pipeline.renderReference(from: referenceSource, settings: settings)

        let primaryCIImage: CIImage
        let comparisonCIImage: CIImage?
        switch previewMode {
        case .edited:
            primaryCIImage = editedImage
            comparisonCIImage = nil
        case .before:
            primaryCIImage = referenceImage
            comparisonCIImage = nil
        case .split:
            primaryCIImage = editedImage
            comparisonCIImage = referenceImage
        }

        let result = PreviewRenderResult(
            primaryImage: renderNSImage(from: primaryCIImage, colorSpace: ColorPipeline.displayP3),
            comparisonImage: comparisonCIImage.flatMap { renderNSImage(from: $0, colorSpace: ColorPipeline.displayP3) },
            histogram: await histogramGenerator.generate(from: primaryCIImage, context: context)
        )

        await previewCache.insert(result, for: cacheKey)
        return result
    }

    func renderThumbnail(for asset: PhotoAsset, size: CGSize = CGSize(width: 180, height: 180)) async -> NSImage? {
        let decoded = try? await decoder.decode(
            asset: asset,
            targetLongSide: size.longestSide,
            isExport: false
        )

        guard let decoded else {
            return nil
        }

        let displayImage = await pipeline.renderReference(
            from: decoded.image,
            settings: AdjustmentSettings()
        )

        return renderNSImage(from: displayImage, colorSpace: ColorPipeline.sRGB)
    }

    func export(
        asset: PhotoAsset,
        settings: AdjustmentSettings,
        presets: [UUID: LUTPreset],
        exportSettings: ExportSettings,
        destinationURL: URL
    ) async throws {
        let decoded = try await decoder.decode(
            asset: asset,
            targetLongSide: nil,
            isExport: true,
            settings: settings
        )

        let editedImage = await pipeline.renderEdited(
            from: decoded.image,
            asset: asset,
            settings: settings,
            presets: presets,
            quality: .export
        )

        try exportEngine.export(editedImage, settings: exportSettings, using: context, to: destinationURL)
    }

    private func renderNSImage(from image: CIImage, colorSpace: CGColorSpace) -> NSImage? {
        guard let cgImage = context.createCGImage(image, from: image.extent, format: .RGBA8, colorSpace: colorSpace) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
