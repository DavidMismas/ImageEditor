import CoreGraphics
import Foundation

struct CurvePointSet: Hashable, Codable, Sendable {
    static let linearValues = [0.0, 0.25, 0.5, 0.75, 1.0]

    var values: [Double]

    init(values: [Double] = CurvePointSet.linearValues) {
        if values.count == 5 {
            self.values = values.map { $0.clamped(to: 0...1) }
        } else {
            self.values = CurvePointSet.linearValues
        }
    }

    subscript(index: Int) -> Double {
        get { values[index] }
        set { values[index] = newValue.clamped(to: 0...1) }
    }
}

struct BaseAdjustments: Hashable, Codable, Sendable {
    var exposure: Double = 0
    var contrast: Double = 0
    var highlights: Double = 0
    var shadows: Double = 0
    var whites: Double = 0
    var blacks: Double = 0
    var temperature: Double = 0
    var tint: Double = 0
    var saturation: Double = 0
    var vibrance: Double = 0
}

struct ColorWheelSettings: Hashable, Codable, Sendable {
    var hue: Double = 0
    var intensity: Double = 0
    var luminance: Double = 0
}

struct ColorGradingSettings: Hashable, Codable, Sendable {
    var global = ColorWheelSettings()
    var shadows = ColorWheelSettings()
    var highlights = ColorWheelSettings()
}

struct HSLChannelAdjustment: Hashable, Codable, Identifiable, Sendable {
    var channel: HSLChannelKind
    var hue: Double = 0
    var saturation: Double = 0
    var luminance: Double = 0

    var id: HSLChannelKind { channel }
}

struct HSLSettings: Hashable, Codable, Sendable {
    var channels: [HSLChannelAdjustment] = HSLChannelKind.allCases.map {
        HSLChannelAdjustment(channel: $0)
    }

    subscript(channel: HSLChannelKind) -> HSLChannelAdjustment {
        get {
            channels.first(where: { $0.channel == channel }) ?? HSLChannelAdjustment(channel: channel)
        }
        set {
            if let index = channels.firstIndex(where: { $0.channel == channel }) {
                channels[index] = newValue
            } else {
                channels.append(newValue)
            }
        }
    }
}

struct ColorCurveSettings: Hashable, Codable, Sendable {
    var luma = CurvePointSet()
    var red = CurvePointSet()
    var green = CurvePointSet()
    var blue = CurvePointSet()
}

struct ColorAdjustments: Hashable, Codable, Sendable {
    var grading = ColorGradingSettings()
    var hsl = HSLSettings()
    var curves = ColorCurveSettings()
}

struct EffectsSettings: Hashable, Codable, Sendable {
    var clarity: Double = 0
    var sharpness: Double = 0
    var grain: Double = 0
    var vignette: Double = 0
}

struct CropSettings: Hashable, Codable, Sendable {
    var rect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    var aspectPreset: CropAspectPreset = .original
    var overlay: CropOverlayPreset = .ruleOfThirds
    var straighten: Double = 0
    var rotationQuarterTurns: Int = 0
    var flipHorizontal = false
    var flipVertical = false

    var rotation: Double {
        get { straighten }
        set { straighten = newValue.clamped(to: -45...45) }
    }
}

enum CropMath {
    static let minimumNormalizedLength: CGFloat = 0.02
    static let defaultRect = CGRect(x: 0, y: 0, width: 1, height: 1)

    static func aspectRatio(for preset: CropAspectPreset, in extent: CGSize) -> CGFloat? {
        switch preset {
        case .original:
            guard extent.width > 0, extent.height > 0 else {
                return nil
            }
            return extent.width / extent.height
        case .free:
            return nil
        default:
            return CGFloat(preset.aspectRatio ?? 1)
        }
    }

    static func normalizedQuarterTurns(_ quarterTurns: Int) -> Int {
        let value = quarterTurns % 4
        return value >= 0 ? value : value + 4
    }

    static func orientedSize(for sourceSize: CGSize, quarterTurns: Int) -> CGSize {
        switch normalizedQuarterTurns(quarterTurns) {
        case 1, 3:
            return CGSize(width: sourceSize.height, height: sourceSize.width)
        default:
            return sourceSize
        }
    }

    static func orientationTransform(for extent: CGRect, crop: CropSettings) -> CGAffineTransform {
        let turns = normalizedQuarterTurns(crop.rotationQuarterTurns)
        var transform = CGAffineTransform.identity

        switch turns {
        case 1:
            transform = transform
                .translatedBy(x: extent.height, y: 0)
                .rotated(by: .pi / 2)
        case 2:
            transform = transform
                .translatedBy(x: extent.width, y: extent.height)
                .rotated(by: .pi)
        case 3:
            transform = transform
                .translatedBy(x: 0, y: extent.width)
                .rotated(by: -.pi / 2)
        default:
            break
        }

        let orientedExtent = extent.applying(transform).standardized

        if crop.flipHorizontal {
            transform = transform
                .translatedBy(x: orientedExtent.maxX + orientedExtent.minX, y: 0)
                .scaledBy(x: -1, y: 1)
        }

        if crop.flipVertical {
            transform = transform
                .translatedBy(x: 0, y: orientedExtent.maxY + orientedExtent.minY)
                .scaledBy(x: 1, y: -1)
        }

        return transform
    }

    static func rotatePoint(
        _ point: CGPoint,
        around center: CGPoint,
        degrees: Double
    ) -> CGPoint {
        guard degrees != 0 else {
            return point
        }

        let radians = CGFloat(degrees * .pi / 180)
        let translated = CGPoint(x: point.x - center.x, y: point.y - center.y)
        let cosAngle = cos(radians)
        let sinAngle = sin(radians)

        return CGPoint(
            x: translated.x * cosAngle - translated.y * sinAngle + center.x,
            y: translated.x * sinAngle + translated.y * cosAngle + center.y
        )
    }

    static func cropRect(
        for extent: CGRect,
        crop: CropSettings,
        minimumLength: CGFloat = 36,
        flipY: Bool = false
    ) -> CGRect {
        guard extent.width > 0, extent.height > 0 else {
            return extent
        }

        let proposedRect = denormalizedRect(for: crop.rect, in: extent, flipY: flipY)
        return constrainedRect(
            proposedRect,
            aspectRatio: aspectRatio(for: crop.aspectPreset, in: extent.size),
            within: extent,
            minimumLength: minimumLength
        )
    }

    static func denormalizedRect(
        for rect: CGRect,
        in extent: CGRect,
        flipY: Bool = false
    ) -> CGRect {
        guard extent.width > 0, extent.height > 0 else {
            return extent
        }

        let standardized = rect.standardized
        let originX = extent.minX + extent.width * standardized.minX.clamped(to: 0...(1 - minimumNormalizedLength))
        let width = extent.width * standardized.width.clamped(to: minimumNormalizedLength...1)
        let height = extent.height * standardized.height.clamped(to: minimumNormalizedLength...1)
        let normalizedY = standardized.minY.clamped(to: 0...(1 - minimumNormalizedLength))
        let originY: CGFloat
        if flipY {
            originY = extent.minY + extent.height * (1 - normalizedY - standardized.height.clamped(to: minimumNormalizedLength...1))
        } else {
            originY = extent.minY + extent.height * normalizedY
        }
        return CGRect(x: originX, y: originY, width: width, height: height)
    }

    static func normalizedRect(for rect: CGRect, in extent: CGRect) -> CGRect {
        guard extent.width > 0, extent.height > 0 else {
            return defaultRect
        }

        let boundedRect = rect.standardized.intersection(extent)
        guard !boundedRect.isNull, boundedRect.width > 0, boundedRect.height > 0 else {
            return defaultRect
        }

        return CGRect(
            x: ((boundedRect.minX - extent.minX) / extent.width).clamped(to: 0...(1 - minimumNormalizedLength)),
            y: ((boundedRect.minY - extent.minY) / extent.height).clamped(to: 0...(1 - minimumNormalizedLength)),
            width: (boundedRect.width / extent.width).clamped(to: minimumNormalizedLength...1),
            height: (boundedRect.height / extent.height).clamped(to: minimumNormalizedLength...1)
        )
    }

    static func settings(for rect: CGRect, in extent: CGRect, basedOn crop: CropSettings) -> CropSettings {
        guard extent.width > 0, extent.height > 0 else {
            return crop
        }

        let constrained = constrainedRect(
            rect,
            aspectRatio: aspectRatio(for: crop.aspectPreset, in: extent.size),
            within: extent,
            minimumLength: 36
        )

        var updated = crop
        updated.rect = normalizedRect(for: constrained, in: extent)
        return updated
    }

    static func isRectFullyCovered(
        _ rect: CGRect,
        in extent: CGRect,
        withStraightenDegrees degrees: Double
    ) -> Bool {
        guard abs(degrees) > 0.0001 else {
            return extent.contains(rect)
        }

        let center = CGPoint(x: extent.midX, y: extent.midY)
        let corners = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.maxY)
        ]

        return corners.allSatisfy { point in
            let unrotated = rotatePoint(point, around: center, degrees: -degrees)
            return extent.contains(unrotated)
        }
    }

    static func fittedRectInsideCoverage(
        from rect: CGRect,
        extent: CGRect,
        straightenDegrees: Double,
        aspectRatio: CGFloat?,
        minimumLength: CGFloat
    ) -> CGRect {
        var candidate = constrainedRect(rect, aspectRatio: aspectRatio, within: extent, minimumLength: minimumLength)
        guard abs(straightenDegrees) > 0.0001 else {
            return candidate
        }

        var iterations = 0
        while !isRectFullyCovered(candidate, in: extent, withStraightenDegrees: straightenDegrees), iterations < 24 {
            let shrinkScale: CGFloat = 0.96
            let nextWidth = max(candidate.width * shrinkScale, min(minimumLength, extent.width))
            let nextHeight: CGFloat
            if let aspectRatio {
                nextHeight = nextWidth / max(aspectRatio, 0.0001)
            } else {
                nextHeight = max(candidate.height * shrinkScale, min(minimumLength, extent.height))
            }

            let nextRect = CGRect(
                x: candidate.midX - nextWidth / 2,
                y: candidate.midY - nextHeight / 2,
                width: nextWidth,
                height: nextHeight
            )
            let constrainedNextRect = constrainedRect(
                nextRect,
                aspectRatio: aspectRatio,
                within: extent,
                minimumLength: minimumLength
            )

            if constrainedNextRect.equalTo(candidate) {
                break
            }

            candidate = constrainedNextRect
            iterations += 1
        }

        return candidate
    }

    static func constrainedRect(
        _ rect: CGRect,
        aspectRatio: CGFloat?,
        within extent: CGRect,
        minimumLength: CGFloat
    ) -> CGRect {
        guard extent.width > 0, extent.height > 0 else {
            return extent
        }

        var bounded = rect.standardized
        if bounded.width <= 0 || bounded.height <= 0 {
            bounded = extent
        }

        bounded.size.width = bounded.width.clamped(to: min(minimumLength, extent.width)...extent.width)
        bounded.size.height = bounded.height.clamped(to: min(minimumLength, extent.height)...extent.height)

        if let aspectRatio {
            bounded = fitAspectLockedRect(
                bounded,
                aspectRatio: aspectRatio,
                within: extent,
                minimumLength: minimumLength
            )
        } else {
            bounded.origin.x = bounded.minX.clamped(to: extent.minX...(extent.maxX - bounded.width))
            bounded.origin.y = bounded.minY.clamped(to: extent.minY...(extent.maxY - bounded.height))
        }

        return bounded
    }

    private static func fitAspectLockedRect(
        _ rect: CGRect,
        aspectRatio: CGFloat,
        within extent: CGRect,
        minimumLength: CGFloat
    ) -> CGRect {
        let safeAspectRatio = max(aspectRatio, 0.0001)
        let center = CGPoint(x: rect.midX, y: rect.midY)

        var width = rect.width
        var height = rect.height
        if width / max(height, 0.0001) > safeAspectRatio {
            width = height * safeAspectRatio
        } else {
            height = width / safeAspectRatio
        }

        let minimumWidth = min(minimumLength, extent.width, extent.height * safeAspectRatio)
        width = max(width, minimumWidth)
        height = width / safeAspectRatio

        if height > extent.height {
            height = extent.height
            width = height * safeAspectRatio
        }
        if width > extent.width {
            width = extent.width
            height = width / safeAspectRatio
        }

        let originX = (center.x - width / 2).clamped(to: extent.minX...(extent.maxX - width))
        let originY = (center.y - height / 2).clamped(to: extent.minY...(extent.maxY - height))
        return CGRect(x: originX, y: originY, width: width, height: height)
    }
}

struct LUTSelection: Hashable, Codable, Sendable {
    var selectedLUTID: UUID?
    var intensity: Double = 100
}

struct AdjustmentSettings: Hashable, Codable, Sendable {
    var base = BaseAdjustments()
    var color = ColorAdjustments()
    var effects = EffectsSettings()
    var crop = CropSettings()
    var lut = LUTSelection()
}
