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
    var aspectPreset: CropAspectPreset = .original
    var straighten: Double = 0
    var rotationQuarterTurns: Int = 0
    var flipHorizontal = false
    var flipVertical = false
    var zoom: Double = 1
    var centerX: Double = 0.5
    var centerY: Double = 0.5
    var freeformWidth: Double = 1
    var freeformHeight: Double = 1
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
