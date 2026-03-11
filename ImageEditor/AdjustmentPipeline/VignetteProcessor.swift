@preconcurrency import CoreImage
import Foundation

struct VignetteProcessor: Sendable {
    func apply(to image: CIImage, amount: Double) -> CIImage {
        guard amount > 0, let filter = CIFilter(name: "CIVignetteEffect") else {
            return image
        }

        let normalizedAmount = amount.clamped(to: 0...100) / 100
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(x: image.extent.midX, y: image.extent.midY), forKey: kCIInputCenterKey)
        filter.setValue(max(image.extent.width, image.extent.height) * 0.70, forKey: kCIInputRadiusKey)
        filter.setValue(normalizedAmount * 1.05, forKey: kCIInputIntensityKey)
        filter.setValue(0.72, forKey: "inputFalloff")
        return filter.outputImage ?? image
    }
}
