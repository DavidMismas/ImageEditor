import CoreImage
import CoreGraphics
import Foundation

struct DecodedImage: @unchecked Sendable {
    let image: CIImage
    let nativeSize: CGSize
    let isRAW: Bool
    let properties: [String: Any]
}

enum RAWImageDecoderError: LocalizedError {
    case unsupportedFile(URL)
    case decodeFailed(URL)

    var errorDescription: String? {
        switch self {
        case let .unsupportedFile(url):
            return "macOS RAW support could not open \(url.lastPathComponent). The file may not be supported by the current Apple RAW engine."
        case let .decodeFailed(url):
            return "The RAW decode for \(url.lastPathComponent) failed."
        }
    }
}

actor RAWImageDecoder {
    private let decodedImageCache = RAWDecodedImageCache()
    private var standardCache: [URL: DecodedImage] = [:]

    func decode(
        asset: PhotoAsset,
        targetLongSide: CGFloat?,
        isExport: Bool,
        settings: AdjustmentSettings = AdjustmentSettings()
    ) async throws -> DecodedImage {
        if asset.isRAW {
            let configuration = RAWDecodeConfiguration.make(
                targetLongSide: targetLongSide,
                intent: isExport ? .export : .preview,
                temperature: settings.base.temperature,
                tint: settings.base.tint
            )
            return try await decodeRAWImage(at: asset.url, configuration: configuration)
        }

        if let cached = standardCache[asset.url] {
            return cached
        }

        let decodedImage = try decodeStandard(asset: asset)
        standardCache[asset.url] = decodedImage
        return decodedImage
    }

    func decodeRAW(
        at url: URL,
        configuration: RAWDecodeConfiguration,
        targetPreviewSize: CGSize? = nil
    ) async throws -> CIImage {
        let resolvedConfiguration = configuration.resolvingTargetLongSide(with: targetPreviewSize)
        let decoded = try await decodeRAWImage(at: url, configuration: resolvedConfiguration)
        return decoded.image
    }

    private func decodeRAWImage(
        at url: URL,
        configuration: RAWDecodeConfiguration
    ) async throws -> DecodedImage {
        if let cached = await decodedImageCache.value(for: url, configuration: configuration) {
            return cached
        }

        guard let filter = CIRAWFilter(imageURL: url) else {
            throw RAWImageDecoderError.unsupportedFile(url)
        }

        let scaleFactor: Float
        if let target = configuration.targetLongSide, filter.nativeSize.longestSide > 1 {
            let desiredScale = target / filter.nativeSize.longestSide
            scaleFactor = Float(desiredScale.clamped(to: 0.12...1))
        } else {
            scaleFactor = 1
        }

        filter.scaleFactor = scaleFactor
        // Keep Apple's default RAW rendering curve so untouched imports look
        // natural and camera-appropriate. We still request extra dynamic range
        // below, which preserves highlight headroom for the editor controls.
        filter.isDraftModeEnabled = configuration.previewDraftMode && scaleFactor < 0.92
        filter.extendedDynamicRangeAmount = Float(configuration.extendedDynamicRangeAmount)
        filter.isGamutMappingEnabled = true

        // Apple's RAW defaults can be overly smoothing on some files. Keep the
        // camera-aware baseline, but back off built-in noise reduction so fine
        // detail and color separation survive into our editor pipeline.
        if filter.isLuminanceNoiseReductionSupported {
            filter.luminanceNoiseReductionAmount *= Float(configuration.luminanceNoiseReductionScale)
        }
        if filter.isColorNoiseReductionSupported {
            filter.colorNoiseReductionAmount *= Float(configuration.colorNoiseReductionScale)
        }

        if filter.isHighlightRecoverySupported {
            filter.isHighlightRecoveryEnabled = configuration.enableHighlightRecovery
        }
        if filter.isLensCorrectionSupported {
            filter.isLensCorrectionEnabled = configuration.enableLensCorrection
        }

        // RAW white balance belongs at decode time. Start from the file's
        // metadata-derived neutral point and apply user deltas there so RAW
        // files respond naturally instead of relying on downstream RGB hacks.
        let defaultTemperature = filter.neutralTemperature
        let defaultTint = filter.neutralTint
        if configuration.temperature != 0 {
            let adjustedTemperature = defaultTemperature + Float(configuration.temperature * 24)
            filter.neutralTemperature = adjustedTemperature.clamped(to: 1_500...50_000)
        }
        if configuration.tint != 0 {
            filter.neutralTint = (defaultTint + Float(configuration.tint * 0.9)).clamped(to: -250...250)
        }

        guard let outputImage = filter.outputImage else {
            throw RAWImageDecoderError.decodeFailed(url)
        }

        let decodedImage = DecodedImage(
            image: outputImage,
            nativeSize: filter.nativeSize,
            isRAW: true,
            properties: filter.properties as? [String: Any] ?? [:]
        )

        await decodedImageCache.insert(decodedImage, for: url, configuration: configuration)
        return decodedImage
    }

    private func decodeStandard(asset: PhotoAsset) throws -> DecodedImage {
        guard let image = CIImage(contentsOf: asset.url) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        return DecodedImage(
            image: image,
            nativeSize: image.extent.size,
            isRAW: false,
            properties: image.properties
        )
    }
}

typealias RAWDecoder = RAWImageDecoder
