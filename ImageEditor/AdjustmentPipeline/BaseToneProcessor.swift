@preconcurrency import CoreImage
import Foundation

struct BaseToneProcessor: Sendable {
    func apply(to image: CIImage, asset: PhotoAsset, settings: AdjustmentSettings) -> CIImage {
        let exposureEV = Float(settings.base.exposure)
        let contrast = Float(settings.base.contrast / 100)
        let highlights = Float(settings.base.highlights / 100)
        let shadows = Float(settings.base.shadows / 100)
        let whites = Float(settings.base.whites / 100)
        let blacks = Float(settings.base.blacks / 100)

        guard exposureEV != 0 || contrast != 0 || highlights != 0 || shadows != 0 || whites != 0 || blacks != 0 else {
            return image
        }

        // Use Apple's HDR-capable highlight/shadow operator for the heavy lifting
        // of detail recovery. It preserves spatial detail much better than the
        // old global-only curve and gives RAW files a meaningful recovery path.
        var workingImage = applyExposure(exposureEV, to: image)
        workingImage = applyHighlightShadowRecovery(
            highlights: highlights,
            shadows: shadows,
            to: workingImage
        )

        // Keep our custom contrast / whites / blacks shaping after recovery so
        // those controls refine the tone curve instead of fighting the recovery.
        return AdjustmentKernels.baseTone?.apply(
            extent: workingImage.extent,
            arguments: [
                workingImage,
                0,
                contrast,
                max(highlights, 0),
                0,
                whites,
                blacks
            ]
        ) ?? workingImage
    }

    private func applyExposure(_ exposureEV: Float, to image: CIImage) -> CIImage {
        guard exposureEV != 0, let filter = CIFilter(name: "CIExposureAdjust") else {
            return image
        }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(exposureEV * 0.6, forKey: kCIInputEVKey)
        return filter.outputImage ?? image
    }

    private func applyHighlightShadowRecovery(
        highlights: Float,
        shadows: Float,
        to image: CIImage
    ) -> CIImage {
        guard (highlights != 0 || shadows != 0), let filter = CIFilter(name: "CIHighlightShadowAdjust") else {
            return image
        }

        let highlightAmount = highlights < 0 ? (1 + highlights).clamped(to: 0...1) : 1
        let shadowAmount = shadows.clamped(to: -1...1)

        let compressed = AdjustmentKernels.sceneCompress?.apply(
            extent: image.extent,
            arguments: [image]
        ) ?? image

        filter.setValue(compressed, forKey: kCIInputImageKey)
        filter.setValue(highlightAmount, forKey: "inputHighlightAmount")
        filter.setValue(shadowAmount, forKey: "inputShadowAmount")
        filter.setValue(6.0, forKey: "inputRadius")

        guard let recovered = filter.outputImage else {
            return image
        }

        let expanded = AdjustmentKernels.sceneExpand?.apply(
            extent: recovered.extent,
            arguments: [recovered]
        ) ?? recovered

        let chromaProtection = ((-highlights) - 0.35).clamped(to: 0...0.65) / 0.65
        guard chromaProtection > 0 else {
            return expanded
        }

        return AdjustmentKernels.highlightColorProtect?.apply(
            extent: expanded.extent,
            arguments: [expanded, chromaProtection]
        ) ?? expanded
    }
}
