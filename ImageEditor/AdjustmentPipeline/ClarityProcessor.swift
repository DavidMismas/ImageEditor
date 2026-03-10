@preconcurrency import CoreImage
import CoreGraphics
import Foundation

struct ClarityProcessor: Sendable {
    func apply(to image: CIImage, amount: Double) -> CIImage {
        guard amount > 0 else {
            return image
        }

        let normalizedAmount = Float(amount.clamped(to: 0...100) / 100)
        let blurRadius = max(image.extent.size.longestSide * 0.008, 10) * CGFloat(0.65 + normalizedAmount)
        let blurred = image
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: blurRadius])
            .cropped(to: image.extent)

        return AdjustmentKernels.clarity?.apply(
            extent: image.extent,
            arguments: [image, blurred, normalizedAmount]
        ) ?? image
    }
}
