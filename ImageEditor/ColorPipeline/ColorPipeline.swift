@preconcurrency import CoreImage
@preconcurrency import Metal
import CoreGraphics

enum ColorPipeline {
    static let workingColorSpace = CGColorSpace(name: CGColorSpace.linearSRGB)!
    static let displayP3 = CGColorSpace(name: CGColorSpace.displayP3)!
    static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

    static func makeContext(device: MTLDevice? = MTLCreateSystemDefaultDevice()) -> CIContext {
        let options: [CIContextOption: Any] = [
            .workingColorSpace: workingColorSpace,
            .workingFormat: CIFormat.RGBAh,
            .cacheIntermediates: true,
            .useSoftwareRenderer: false
        ]

        if let device {
            return CIContext(mtlDevice: device, options: options)
        }

        return CIContext(options: options)
    }
}
