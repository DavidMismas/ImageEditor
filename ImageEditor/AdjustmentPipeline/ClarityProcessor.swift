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
        let broadRadius = max(image.extent.size.longestSide * 0.0048, 6) * CGFloat(0.8 + strength * 0.7)
        let fineRadius = max(image.extent.size.longestSide * 0.0011, 1.2) * CGFloat(0.9 + strength * 0.35)

        let broadBlur = image
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: broadRadius])
            .cropped(to: image.extent)
        let fineBlur = image
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: fineRadius])
            .cropped(to: image.extent)

        let tunedAmount: Float = normalizedAmount >= 0
            ? normalizedAmount * 1.15
            : normalizedAmount * 1.10

        return AdjustmentKernels.clarity?.apply(
            extent: image.extent,
            arguments: [image, broadBlur, fineBlur, tunedAmount]
        ) ?? image
    }
}
