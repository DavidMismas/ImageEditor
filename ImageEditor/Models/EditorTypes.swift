import CoreGraphics
import Foundation
import UniformTypeIdentifiers

enum EditorTab: String, CaseIterable, Identifiable, Sendable {
    case base = "Base"
    case color = "Color"
    case effects = "Effects"
    case crop = "Crop"
    case lut = "LUT"

    var id: String { rawValue }
}

enum PreviewMode: String, CaseIterable, Identifiable, Sendable {
    case edited = "Edited"
    case before = "Before"
    case split = "Split"

    var id: String { rawValue }
}

enum RenderQuality: Sendable {
    case thumbnail
    case preview
    case export

    var selectiveColorCubeDimension: Int {
        switch self {
        case .thumbnail:
            return 20
        case .preview:
            return 28
        case .export:
            return 40
        }
    }
}

enum OutputColorSpaceOption: String, CaseIterable, Identifiable, Sendable {
    case sRGB = "sRGB"
    case displayP3 = "Display P3"

    var id: String { rawValue }

    var cgColorSpace: CGColorSpace {
        switch self {
        case .sRGB:
            return CGColorSpace(name: CGColorSpace.sRGB)!
        case .displayP3:
            return CGColorSpace(name: CGColorSpace.displayP3)!
        }
    }
}

enum ExportFormat: String, CaseIterable, Identifiable, Sendable {
    case jpeg = "JPEG"
    case png = "PNG"
    case tiff = "TIFF"

    var id: String { rawValue }

    var utType: UTType {
        switch self {
        case .jpeg:
            return .jpeg
        case .png:
            return .png
        case .tiff:
            return .tiff
        }
    }

    var fileExtension: String {
        switch self {
        case .jpeg:
            return "jpg"
        case .png:
            return "png"
        case .tiff:
            return "tiff"
        }
    }
}

enum CropAspectPreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case square1x1 = "1:1"
    case ratio3x2 = "3:2"
    case ratio4x3 = "4:3"
    case ratio5x4 = "5:4"
    case ratio16x9 = "16:9"
    case ratio21x9 = "21:9"
    case ratio9x16 = "9:16"
    case original = "Original"
    case free = "Free"

    var id: String { rawValue }

    var aspectRatio: Double? {
        switch self {
        case .original, .free:
            return nil
        case .square1x1:
            return 1.0
        case .ratio3x2:
            return 3.0 / 2.0
        case .ratio4x3:
            return 4.0 / 3.0
        case .ratio5x4:
            return 5.0 / 4.0
        case .ratio16x9:
            return 16.0 / 9.0
        case .ratio21x9:
            return 21.0 / 9.0
        case .ratio9x16:
            return 9.0 / 16.0
        }
    }
}

enum CropOverlayPreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case none = "Off"
    case ruleOfThirds = "Thirds"
    case goldenRatio = "Golden"
    case diagonal = "Diagonal"
    case grid = "Grid"

    var id: String { rawValue }
}

enum HSLChannelKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case red = "Red"
    case orange = "Orange"
    case yellow = "Yellow"
    case green = "Green"
    case aqua = "Aqua"
    case blue = "Blue"
    case purple = "Purple"
    case magenta = "Magenta"

    var id: String { rawValue }

    var hueCenter: Float {
        switch self {
        case .red:
            return 0
        case .orange:
            return 35
        case .yellow:
            return 62
        case .green:
            return 130
        case .aqua:
            return 185
        case .blue:
            return 242
        case .purple:
            return 278
        case .magenta:
            return 322
        }
    }

    var hueWidth: Float {
        switch self {
        case .orange:
            return 42
        case .yellow, .aqua:
            return 38
        default:
            return 34
        }
    }

    var previewGradientHues: [Double] {
        switch self {
        case .red:
            return [304, 340, 0, 28, 52]
        case .orange:
            return [350, 18, 35, 54, 74]
        case .yellow:
            return [22, 42, 62, 96, 124]
        case .green:
            return [28, 72, 130, 184, 224]
        case .aqua:
            return [108, 150, 185, 214, 238]
        case .blue:
            return [176, 214, 242, 278, 308]
        case .purple:
            return [224, 258, 278, 304, 330]
        case .magenta:
            return [266, 300, 322, 344, 18]
        }
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

extension CGSize {
    var longestSide: CGFloat {
        max(width, height)
    }
}

extension URL {
    var standardizedResolvedFileURL: URL {
        standardizedFileURL.resolvingSymlinksInPath()
    }
}
