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
    
    static func make(
        targetLongSide: CGFloat?,
        intent: RAWDecodeIntent,
        temperature: Double = 0,
        tint: Double = 0
    ) -> RAWDecodeConfiguration {
        RAWDecodeConfiguration(
            previewDraftMode: false,
            targetLongSide: targetLongSide,
            intent: intent,
            temperature: temperature,
            tint: tint,
            enableHighlightRecovery: true,
            enableLensCorrection: true,
            extendedDynamicRangeAmount: 2
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
