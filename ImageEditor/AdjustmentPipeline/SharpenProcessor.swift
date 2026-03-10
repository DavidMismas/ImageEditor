@preconcurrency import CoreImage
import CoreGraphics
import Foundation

struct SharpenProcessor: Sendable {
    func apply(to image: CIImage, amount: Double) -> CIImage {
        guard amount > 0 else {
            return image
        }

        let normalizedAmount = Float(amount.clamped(to: 0...100) / 100)
        let blurRadius = max(0.7, image.extent.size.longestSide * 0.0008)
        let blurred = image
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: blurRadius])
            .cropped(to: image.extent)

        let threshold = Float(0.0025 + (1 - normalizedAmount) * 0.01)
        return AdjustmentKernels.sharpen?.apply(
            extent: image.extent,
            arguments: [image, blurred, normalizedAmount, threshold]
        ) ?? image
    }
}
