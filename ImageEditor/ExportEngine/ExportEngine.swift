@preconcurrency import CoreImage
import Foundation
import ImageIO

struct ExportSettings: Hashable, Sendable {
    var format: ExportFormat
    var colorSpace: OutputColorSpaceOption
    var jpegQuality: Double
}

struct ExportEngine: Sendable {
    func export(_ image: CIImage, settings: ExportSettings, using context: CIContext, to url: URL) throws {
        let destinationURL = url.standardizedResolvedFileURL
        let colorSpace = settings.colorSpace.cgColorSpace

        switch settings.format {
        case .jpeg:
            try context.writeJPEGRepresentation(
                of: image,
                to: destinationURL,
                colorSpace: colorSpace,
                options: [
                    CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): settings.jpegQuality.clamped(to: 0...100) / 100
                ]
            )
        case .png:
            try context.writePNGRepresentation(of: image, to: destinationURL, format: .RGBA8, colorSpace: colorSpace)
        case .tiff:
            try context.writeTIFFRepresentation(of: image, to: destinationURL, format: .RGBA8, colorSpace: colorSpace, options: [:])
        }
    }
}

typealias ExportRenderer = ExportEngine
