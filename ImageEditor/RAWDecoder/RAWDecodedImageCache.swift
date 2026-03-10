import Foundation

private struct RAWDecodedImageCacheKey: Hashable, Sendable {
    let url: URL
    let intent: RAWDecodeIntent
    let scaleBucket: Int
    let previewDraftMode: Bool

    init(url: URL, configuration: RAWDecodeConfiguration) {
        self.url = url
        intent = configuration.intent
        scaleBucket = Int((configuration.targetLongSide ?? 0).rounded())
        previewDraftMode = configuration.previewDraftMode
    }
}

actor RAWDecodedImageCache {
    private var previewStorage: [RAWDecodedImageCacheKey: DecodedImage] = [:]
    private var exportStorage: [RAWDecodedImageCacheKey: DecodedImage] = [:]

    func value(for url: URL, configuration: RAWDecodeConfiguration) -> DecodedImage? {
        let key = RAWDecodedImageCacheKey(url: url, configuration: configuration)
        switch configuration.intent {
        case .preview:
            return previewStorage[key]
        case .export:
            return exportStorage[key]
        }
    }

    func insert(_ image: DecodedImage, for url: URL, configuration: RAWDecodeConfiguration) {
        let key = RAWDecodedImageCacheKey(url: url, configuration: configuration)
        switch configuration.intent {
        case .preview:
            previewStorage[key] = image
        case .export:
            exportStorage[key] = image
        }
    }

    func removeAll() {
        previewStorage.removeAll(keepingCapacity: true)
        exportStorage.removeAll(keepingCapacity: true)
    }
}
