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

        // This stage works on luminance in a bounded scene-referred domain.
        // It keeps 0 pinned, treats exposure as photographic stops in linear space,
        // and uses smooth toe/shoulder shaping for shadows/highlights/whites/blacks.
        return AdjustmentKernels.baseTone?.apply(
            extent: image.extent,
            arguments: [image, exposureEV, contrast, highlights, shadows, whites, blacks]
        ) ?? image
    }
}
