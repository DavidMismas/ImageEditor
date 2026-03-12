import Foundation

private struct RAWDecodedImageCacheKey: Hashable, Sendable {
    let url: URL
    let intent: RAWDecodeIntent
    let scaleBucket: Int
    let previewDraftMode: Bool
    let temperatureBucket: Int
    let tintBucket: Int
    let highlightRecoveryEnabled: Bool
    let lensCorrectionEnabled: Bool
    let extendedDynamicRangeBucket: Int
    let luminanceNoiseReductionBucket: Int
    let colorNoiseReductionBucket: Int

    init(url: URL, configuration: RAWDecodeConfiguration) {
        self.url = url
        intent = configuration.intent
        scaleBucket = Int((configuration.targetLongSide ?? 0).rounded())
        previewDraftMode = configuration.previewDraftMode
        temperatureBucket = Int((configuration.temperature * 10).rounded())
        tintBucket = Int((configuration.tint * 10).rounded())
        highlightRecoveryEnabled = configuration.enableHighlightRecovery
        lensCorrectionEnabled = configuration.enableLensCorrection
        extendedDynamicRangeBucket = Int((configuration.extendedDynamicRangeAmount * 100).rounded())
        luminanceNoiseReductionBucket = Int((configuration.luminanceNoiseReductionScale * 100).rounded())
        colorNoiseReductionBucket = Int((configuration.colorNoiseReductionScale * 100).rounded())
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
