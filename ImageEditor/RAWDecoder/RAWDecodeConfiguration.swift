import CoreGraphics
import Foundation

enum RAWDecodeIntent: String, Hashable, Codable, Sendable {
    case preview
    case export
}

struct RAWDecodeConfiguration: Hashable, Sendable {
    var previewDraftMode = false
    var targetLongSide: CGFloat?
    var intent: RAWDecodeIntent = .preview
    var temperature: Double = 0
    var tint: Double = 0
    var enableHighlightRecovery = true
    var enableLensCorrection = true
    var extendedDynamicRangeAmount: Double = 2
    var luminanceNoiseReductionScale: Double = 0.55
    var colorNoiseReductionScale: Double = 0.72
    
    static func make(
        targetLongSide: CGFloat?,
        intent: RAWDecodeIntent,
        temperature: Double = 0,
        tint: Double = 0
    ) -> RAWDecodeConfiguration {
        let luminanceNoiseReductionScale: Double
        let colorNoiseReductionScale: Double
        switch intent {
        case .preview:
            luminanceNoiseReductionScale = 0.55
            colorNoiseReductionScale = 0.72
        case .export:
            // Preserve more native RAW detail and color separation in the
            // final file than in the interactive preview.
            luminanceNoiseReductionScale = 0.28
            colorNoiseReductionScale = 0.52
        }

        return RAWDecodeConfiguration(
            previewDraftMode: false,
            targetLongSide: targetLongSide,
            intent: intent,
            temperature: temperature,
            tint: tint,
            enableHighlightRecovery: true,
            enableLensCorrection: true,
            extendedDynamicRangeAmount: 2,
            luminanceNoiseReductionScale: luminanceNoiseReductionScale,
            colorNoiseReductionScale: colorNoiseReductionScale
        )
    }

    func resolvingTargetLongSide(with previewSize: CGSize?) -> RAWDecodeConfiguration {
        guard targetLongSide == nil, let previewSize else {
            return self
        }

        var resolved = self
        resolved.targetLongSide = previewSize.longestSide
        return resolved
    }
}
