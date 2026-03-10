@preconcurrency import CoreImage
import CoreGraphics
import Foundation

struct GrainProcessor: Sendable {
    func apply(to image: CIImage, amount: Double) -> CIImage {
        guard amount > 0 else {
            return image
        }

        let normalizedAmount = Float(amount.clamped(to: 0...100) / 100)
        let longSide = max(image.extent.size.longestSide, 1)
        let scale = CGFloat(max(0.22, min(0.9, 1400 / longSide)))

        let randomA = CIFilter(name: "CIRandomGenerator")?.outputImage?
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .cropped(to: image.extent)

        let randomB = CIFilter(name: "CIRandomGenerator")?.outputImage?
            .transformed(
                by: CGAffineTransform(translationX: 137, y: 53)
                    .scaledBy(x: scale * 0.58, y: scale * 0.58)
            )
            .cropped(to: image.extent)

        guard let randomA, let randomB else {
            return image
        }

        return AdjustmentKernels.grain?.apply(
            extent: image.extent,
            arguments: [image, randomA, randomB, normalizedAmount]
        ) ?? image
    }
}
