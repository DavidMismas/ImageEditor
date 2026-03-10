@preconcurrency import CoreImage
import Foundation

actor HistogramGenerator {
    func generate(from image: CIImage, context: CIContext, bins: Int = HistogramData.defaultBinCount) -> HistogramData {
        // Use the same bounded tonal domain as the preview-facing selective color/LUT
        // stages so the histogram reads like an editing histogram instead of bunching
        // heavily to the left from linear-light values.
        let histogramSource = AdjustmentKernels.sceneCompress?.apply(
            extent: image.extent,
            arguments: [image]
        ) ?? image

        guard let filter = CIFilter(name: "CIAreaHistogram") else {
            return .empty
        }

        filter.setValue(histogramSource, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: histogramSource.extent), forKey: kCIInputExtentKey)
        filter.setValue(bins, forKey: "inputCount")
        filter.setValue(1.0 / max(histogramSource.extent.width * histogramSource.extent.height, 1), forKey: "inputScale")

        guard let output = filter.outputImage else {
            return .empty
        }

        var bitmap = [Float](repeating: 0, count: bins * 4)
        bitmap.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return
            }

            context.render(
                output,
                toBitmap: baseAddress,
                rowBytes: bins * 4 * MemoryLayout<Float>.size,
                bounds: CGRect(x: 0, y: 0, width: bins, height: 1),
                format: .RGBAf,
                colorSpace: nil
            )
        }

        var red = Array(repeating: 0.0, count: bins)
        var green = Array(repeating: 0.0, count: bins)
        var blue = Array(repeating: 0.0, count: bins)
        var luma = Array(repeating: 0.0, count: bins)

        for index in 0..<bins {
            let offset = index * 4
            red[index] = Double(bitmap[offset])
            green[index] = Double(bitmap[offset + 1])
            blue[index] = Double(bitmap[offset + 2])
            luma[index] = red[index] * 0.2126 + green[index] * 0.7152 + blue[index] * 0.0722
        }

        let maxValue = max(
            red.max() ?? 1,
            green.max() ?? 1,
            blue.max() ?? 1,
            luma.max() ?? 1
        )
        let normalizer = max(maxValue, 0.0001)

        return HistogramData(
            red: red.map { $0 / normalizer },
            green: green.map { $0 / normalizer },
            blue: blue.map { $0 / normalizer },
            luma: luma.map { $0 / normalizer }
        )
    }
}
