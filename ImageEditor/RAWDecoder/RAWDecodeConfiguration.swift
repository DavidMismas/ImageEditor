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
    
    static func make(
        targetLongSide: CGFloat?,
        intent: RAWDecodeIntent
    ) -> RAWDecodeConfiguration {
        RAWDecodeConfiguration(
            previewDraftMode: false,
            targetLongSide: targetLongSide,
            intent: intent
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
