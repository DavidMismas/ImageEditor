@preconcurrency import CoreImage
import Foundation

actor HistogramGenerator {
    func generate(from image: CIImage, context: CIContext, bins: Int = HistogramData.defaultBinCount) -> HistogramData {
        guard !image.extent.isEmpty else {
            return .empty
        }

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
        filter.setValue(1.0, forKey: "inputScale")

        guard let output = filter.outputImage else {
            return .empty
        }

        let translatedOutput = output.transformed(
            by: CGAffineTransform(
                translationX: -output.extent.origin.x,
                y: -output.extent.origin.y
            )
        )
        let renderBounds = CGRect(x: 0, y: 0, width: bins, height: 1)

        var bitmap = [Float](repeating: 0, count: bins * 4)
        bitmap.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return
            }

            context.render(
                translatedOutput,
                toBitmap: baseAddress,
                rowBytes: bins * 4 * MemoryLayout<Float>.size,
                bounds: renderBounds,
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
            red: normalized(red, by: normalizer),
            green: normalized(green, by: normalizer),
            blue: normalized(blue, by: normalizer),
            luma: normalized(luma, by: normalizer)
        )
    }

    private func normalized(_ values: [Double], by normalizer: Double) -> [Double] {
        values.map { value in
            let finiteValue = value.isFinite ? value : 0
            return max(0, finiteValue / normalizer)
        }
    }
}
