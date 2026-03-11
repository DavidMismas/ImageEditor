@preconcurrency import CoreImage
import CoreGraphics
import Foundation

struct ClarityProcessor: Sendable {
    func apply(to image: CIImage, amount: Double) -> CIImage {
        guard amount != 0 else {
            return image
        }

        let normalizedAmount = Float(amount.clamped(to: -100...100) / 100)
        let strength = abs(normalizedAmount)
        let blurRadius = max(image.extent.size.longestSide * 0.008, 10) * CGFloat(0.65 + strength)
        let blurred = image
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: blurRadius])
            .cropped(to: image.extent)

        let tunedAmount: Float = normalizedAmount >= 0
            ? normalizedAmount * 1.25
            : normalizedAmount * 1.10

        return AdjustmentKernels.clarity?.apply(
            extent: image.extent,
            arguments: [image, blurred, tunedAmount]
        ) ?? image
    }
}
