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
        isExport: Bool
    ) async throws -> DecodedImage {
        if asset.isRAW {
            let configuration = RAWDecodeConfiguration.make(
                targetLongSide: targetLongSide,
                intent: isExport ? .export : .preview
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
        // Keep the imported RAW visually neutral by preserving Apple's default
        // decode look. Preview only uses scale reduction for interactivity and
        // does not force draft mode or gamut remapping overrides.
        filter.isDraftModeEnabled = configuration.previewDraftMode && scaleFactor < 0.92

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
