@preconcurrency import AppKit
import SwiftUI

struct PreviewCanvasView: View {
    let primaryImage: NSImage?
    let comparisonImage: NSImage?
    let cropOverlayImage: NSImage?
    let cropSettings: CropSettings?
    let mode: PreviewMode
    let zoomScale: CGFloat
    let fitToScreen: Bool
    let isRendering: Bool
    let isCropOverlayActive: Bool
    let onCropChange: (CropSettings) -> Void
    let onSizeChange: (CGSize) -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.10, blue: 0.14), Color(red: 0.04, green: 0.05, blue: 0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            PreviewSizeObserver(onSizeChange: onSizeChange)
                .allowsHitTesting(false)

            if isCropOverlayActive {
                PreviewImageSurface(
                    title: nil,
                    image: cropOverlayImage ?? primaryImage,
                    zoomScale: zoomScale,
                    fitToScreen: fitToScreen,
                    cropSettings: cropSettings,
                    onCropChange: onCropChange
                )
                .padding(12)
            } else {
                switch mode {
                case .split:
                    VStack(spacing: 12) {
                        PreviewImageSurface(
                            title: "Before",
                            image: comparisonImage,
                            zoomScale: zoomScale,
                            fitToScreen: fitToScreen
                        )
                        PreviewImageSurface(
                            title: "Edited",
                            image: primaryImage,
                            zoomScale: zoomScale,
                            fitToScreen: fitToScreen
                        )
                    }
                    .padding(12)
                case .edited:
                    PreviewImageSurface(
                        title: nil,
                        image: primaryImage,
                        zoomScale: zoomScale,
                        fitToScreen: fitToScreen
                    )
                    .padding(12)
                case .before:
                    PreviewImageSurface(
                        title: "Before",
                        image: primaryImage,
                        zoomScale: zoomScale,
                        fitToScreen: fitToScreen
                    )
                    .padding(12)
                }
            }

            if isRendering && primaryImage == nil && comparisonImage == nil {
                ProgressView()
                    .controlSize(.large)
                    .padding(20)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}

private struct PreviewSizeObserver: NSViewRepresentable {
    let onSizeChange: (CGSize) -> Void

    func makeNSView(context: Context) -> ObserverView {
        let view = ObserverView()
        view.onSizeChange = onSizeChange
        return view
    }

    func updateNSView(_ nsView: ObserverView, context: Context) {
        nsView.onSizeChange = onSizeChange
    }

    final class ObserverView: NSView {
        var onSizeChange: ((CGSize) -> Void)?
        private var lastReportedSize = CGSize.zero

        override func layout() {
            super.layout()
            reportIfNeeded()
        }

        override func setFrameSize(_ newSize: NSSize) {
            super.setFrameSize(newSize)
            reportIfNeeded()
        }

        func reportIfNeeded() {
            let size = CGSize(width: bounds.width.rounded(), height: bounds.height.rounded())
            guard size.width > 0, size.height > 0, size != lastReportedSize else {
                return
            }

            lastReportedSize = size
            DispatchQueue.main.async { [onSizeChange] in
                onSizeChange?(size)
            }
        }
    }
}

private struct PreviewImageSurface: View {
    let title: String?
    let image: NSImage?
    let zoomScale: CGFloat
    let fitToScreen: Bool
    var cropSettings: CropSettings? = nil
    var onCropChange: ((CropSettings) -> Void)? = nil

    var body: some View {
        GeometryReader { geometry in
            let renderedSize = image.map {
                cropSettings == nil
                    ? displaySize(for: $0.size, in: geometry.size)
                    : cropDisplaySize(for: $0.size, in: geometry.size)
            } ?? .zero

            if cropSettings != nil {
                surfaceContent(renderedSize: renderedSize, containerSize: geometry.size)
            } else {
                ScrollView([.horizontal, .vertical]) {
                    surfaceContent(renderedSize: renderedSize, containerSize: geometry.size)
                }
            }
        }
    }

    @ViewBuilder
    private func surfaceContent(renderedSize: CGSize, containerSize: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(.black.opacity(0.20))
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                }

            if let image {
                Group {
                    if let cropSettings, let onCropChange {
                        CropEditingSurface(image: image, crop: cropSettings, onCropChange: onCropChange)
                    } else {
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.high)
                    }
                }
                .frame(width: renderedSize.width, height: renderedSize.height)
                .shadow(color: .black.opacity(0.35), radius: 16, y: 10)
                .frame(width: renderedSize.width, height: renderedSize.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(14)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.largeTitle)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    Text("Import an image to start editing")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)
            }

            if let title {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.55), in: Capsule())
                    .padding(14)
            }
        }
        .frame(
            width: max(renderedSize.width + 28, containerSize.width - 2),
            height: max(renderedSize.height + 28, containerSize.height - 2)
        )
    }

    private func displaySize(for imageSize: CGSize, in container: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return .zero
        }

        let paddedContainer = CGSize(
            width: max(container.width - 28, 120),
            height: max(container.height - 28, 120)
        )
        let fitScale = min(paddedContainer.width / imageSize.width, paddedContainer.height / imageSize.height)
        let baseScale = fitToScreen ? fitScale : 1
        let appliedScale = max(baseScale * zoomScale, 0.1)
        return CGSize(width: imageSize.width * appliedScale, height: imageSize.height * appliedScale)
    }

    private func cropDisplaySize(for imageSize: CGSize, in container: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return .zero
        }

        let paddedContainer = CGSize(
            width: max(container.width - 28, 120),
            height: max(container.height - 28, 120)
        )
        let fitScale = min(paddedContainer.width / imageSize.width, paddedContainer.height / imageSize.height)
        let appliedScale = max(fitScale, 0.1)
        return CGSize(width: imageSize.width * appliedScale, height: imageSize.height * appliedScale)
    }
}

private struct CropEditingSurface: View {
    let image: NSImage
    let crop: CropSettings
    let onCropChange: (CropSettings) -> Void

    @State private var workingCrop: CropSettings
    @State private var dragState: CropDragState?

    private let minCropLength: CGFloat = 72
    private let handleHitSize: CGFloat = 64
    private let cornerHandleSize: CGFloat = 20

    init(image: NSImage, crop: CropSettings, onCropChange: @escaping (CropSettings) -> Void) {
        self.image = image
        self.crop = crop
        self.onCropChange = onCropChange
        _workingCrop = State(initialValue: crop)
    }

    var body: some View {
        GeometryReader { geometry in
            let canvasBounds = CGRect(origin: .zero, size: geometry.size)
            let imageBounds = canvasBounds.insetBy(dx: handleHitSize / 2, dy: handleHitSize / 2)
            let activeFrameRect = resolvedFrameRect(in: imageBounds)

            ZStack {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: imageBounds.width, height: imageBounds.height)
                    .rotationEffect(.degrees(workingCrop.straighten))
                    .position(x: imageBounds.midX, y: imageBounds.midY)

                Path { path in
                    path.addRect(canvasBounds)
                    path.addRect(activeFrameRect)
                }
                .fill(Color.black.opacity(0.46), style: FillStyle(eoFill: true))

                CropOverlayGuides(style: workingCrop.overlay)
                    .stroke(Color.white.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .frame(width: activeFrameRect.width, height: activeFrameRect.height)
                    .position(x: activeFrameRect.midX, y: activeFrameRect.midY)

                Rectangle()
                    .strokeBorder(Color.white.opacity(0.95), lineWidth: 1.5)
                    .frame(width: activeFrameRect.width, height: activeFrameRect.height)
                    .position(x: activeFrameRect.midX, y: activeFrameRect.midY)

                cornerMarker(for: .topLeft, frameRect: activeFrameRect)
                cornerMarker(for: .topRight, frameRect: activeFrameRect)
                cornerMarker(for: .bottomLeft, frameRect: activeFrameRect)
                cornerMarker(for: .bottomRight, frameRect: activeFrameRect)

                Rectangle()
                    .fill(Color.white.opacity(0.001))
                    .contentShape(Rectangle())
                    .frame(width: canvasBounds.width, height: canvasBounds.height)
                    .gesture(unifiedDragGesture(frameRect: activeFrameRect, bounds: imageBounds))
                    .zIndex(10)
            }
            .onAppear {
                synchronizeState(with: crop, bounds: imageBounds)
            }
            .onChange(of: crop) { _, newCrop in
                synchronizeState(with: newCrop, bounds: imageBounds)
            }
        }
    }

    private func resolvedFrameRect(in bounds: CGRect) -> CGRect {
        let baseRect = CropMath.cropRect(for: bounds, crop: workingCrop, minimumLength: minCropLength)
        let aspectRatio = CropMath.aspectRatio(for: workingCrop.aspectPreset, in: bounds.size)
        return CropMath.fittedRectInsideCoverage(
            from: baseRect,
            extent: bounds,
            straightenDegrees: workingCrop.straighten,
            aspectRatio: aspectRatio,
            minimumLength: minCropLength
        )
    }

    private func synchronizeState(with newCrop: CropSettings, bounds: CGRect) {
        guard bounds.width > 0, bounds.height > 0, dragState == nil else {
            return
        }

        let baseRect = CropMath.cropRect(for: bounds, crop: newCrop, minimumLength: minCropLength)
        let aspectRatio = CropMath.aspectRatio(for: newCrop.aspectPreset, in: bounds.size)
        let safeRect = CropMath.fittedRectInsideCoverage(
            from: baseRect,
            extent: bounds,
            straightenDegrees: newCrop.straighten,
            aspectRatio: aspectRatio,
            minimumLength: minCropLength
        )
        let sanitizedCrop = CropMath.settings(for: safeRect, in: bounds, basedOn: newCrop)
        workingCrop = sanitizedCrop

        guard sanitizedCrop != newCrop else {
            return
        }

        DispatchQueue.main.async {
            onCropChange(sanitizedCrop)
        }
    }

    private func cornerMarker(for handle: CropHandle, frameRect: CGRect) -> some View {
        let position = handle.position(in: frameRect)
        let markerSize = handle.markerSize(cornerHandleSize: cornerHandleSize)

        return marker(for: handle)
            .frame(width: markerSize.width, height: markerSize.height)
            .position(position)
            .zIndex(6)
    }

    private func marker(for handle: CropHandle) -> some View {
        Group {
            switch handle {
            case .move:
                EmptyView()
            default:
                Circle()
                    .fill(Color.white)
                    .overlay {
                        Circle()
                            .stroke(Color.black.opacity(0.22), lineWidth: 1.5)
                    }
            }
        }
        .shadow(color: .black.opacity(0.28), radius: 4, y: 1)
    }

    private func unifiedDragGesture(frameRect: CGRect, bounds: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragState == nil {
                    guard let resolvedHandle = detectHandle(at: value.startLocation, in: frameRect) else {
                        return
                    }

                    dragState = CropDragState(
                        handle: resolvedHandle,
                        initialFrameRect: frameRect,
                        initialCrop: workingCrop
                    )
                }

                guard let handle = dragState?.handle else {
                    return
                }

                let startingFrameRect = dragState?.initialFrameRect ?? frameRect
                let baseCrop = dragState?.initialCrop ?? workingCrop
                let aspectRatio = CropMath.aspectRatio(for: baseCrop.aspectPreset, in: bounds.size)
                let updatedFrameRect = updatedRect(
                    for: handle,
                    initialRect: startingFrameRect,
                    translation: value.translation,
                    bounds: bounds,
                    aspectRatio: aspectRatio
                )
                let safeRect = CropMath.fittedRectInsideCoverage(
                    from: updatedFrameRect,
                    extent: bounds,
                    straightenDegrees: baseCrop.straighten,
                    aspectRatio: aspectRatio,
                    minimumLength: minCropLength
                )
                workingCrop = CropMath.settings(for: safeRect, in: bounds, basedOn: baseCrop)
            }
            .onEnded { _ in
                dragState = nil
                if workingCrop != crop {
                    onCropChange(workingCrop)
                }
            }
    }

    private func detectHandle(at location: CGPoint, in frameRect: CGRect) -> CropHandle? {
        let threshold = handleHitSize * 0.7
        let corners: [(CropHandle, CGPoint)] = [
            (.topLeft, CGPoint(x: frameRect.minX, y: frameRect.minY)),
            (.topRight, CGPoint(x: frameRect.maxX, y: frameRect.minY)),
            (.bottomLeft, CGPoint(x: frameRect.minX, y: frameRect.maxY)),
            (.bottomRight, CGPoint(x: frameRect.maxX, y: frameRect.maxY))
        ]

        for (handle, point) in corners {
            if hypot(location.x - point.x, location.y - point.y) <= threshold {
                return handle
            }
        }

        if frameRect.contains(location) {
            return .move
        }

        return nil
    }

    private func updatedRect(
        for handle: CropHandle,
        initialRect: CGRect,
        translation: CGSize,
        bounds: CGRect,
        aspectRatio: CGFloat?
    ) -> CGRect {
        switch handle {
        case .move:
            return movedRect(initialRect, translation: translation, bounds: bounds)
        case .topLeft:
            return cornerRect(
                initialRect: initialRect,
                movingPoint: CGPoint(x: initialRect.minX + translation.width, y: initialRect.minY + translation.height),
                oppositePoint: CGPoint(x: initialRect.maxX, y: initialRect.maxY),
                horizontalDirection: -1,
                verticalDirection: -1,
                bounds: bounds,
                aspectRatio: aspectRatio
            )
        case .topRight:
            return cornerRect(
                initialRect: initialRect,
                movingPoint: CGPoint(x: initialRect.maxX + translation.width, y: initialRect.minY + translation.height),
                oppositePoint: CGPoint(x: initialRect.minX, y: initialRect.maxY),
                horizontalDirection: 1,
                verticalDirection: -1,
                bounds: bounds,
                aspectRatio: aspectRatio
            )
        case .bottomLeft:
            return cornerRect(
                initialRect: initialRect,
                movingPoint: CGPoint(x: initialRect.minX + translation.width, y: initialRect.maxY + translation.height),
                oppositePoint: CGPoint(x: initialRect.maxX, y: initialRect.minY),
                horizontalDirection: -1,
                verticalDirection: 1,
                bounds: bounds,
                aspectRatio: aspectRatio
            )
        case .bottomRight:
            return cornerRect(
                initialRect: initialRect,
                movingPoint: CGPoint(x: initialRect.maxX + translation.width, y: initialRect.maxY + translation.height),
                oppositePoint: CGPoint(x: initialRect.minX, y: initialRect.minY),
                horizontalDirection: 1,
                verticalDirection: 1,
                bounds: bounds,
                aspectRatio: aspectRatio
            )
        }
    }

    private func movedRect(_ rect: CGRect, translation: CGSize, bounds: CGRect) -> CGRect {
        var moved = rect.offsetBy(dx: translation.width, dy: translation.height)
        moved.origin.x = moved.origin.x.clamped(to: bounds.minX...(bounds.maxX - rect.width))
        moved.origin.y = moved.origin.y.clamped(to: bounds.minY...(bounds.maxY - rect.height))
        return moved
    }

    private func freeRect(_ rect: CGRect, movingLeftTo proposedX: CGFloat, bounds: CGRect) -> CGRect {
        let minX = proposedX.clamped(to: bounds.minX...(rect.maxX - minCropLength))
        return CGRect(x: minX, y: rect.minY, width: rect.maxX - minX, height: rect.height)
    }

    private func freeRect(_ rect: CGRect, movingRightTo proposedX: CGFloat, bounds: CGRect) -> CGRect {
        let maxX = proposedX.clamped(to: (rect.minX + minCropLength)...bounds.maxX)
        return CGRect(x: rect.minX, y: rect.minY, width: maxX - rect.minX, height: rect.height)
    }

    private func freeRect(_ rect: CGRect, movingTopTo proposedY: CGFloat, bounds: CGRect) -> CGRect {
        let minY = proposedY.clamped(to: bounds.minY...(rect.maxY - minCropLength))
        return CGRect(x: rect.minX, y: minY, width: rect.width, height: rect.maxY - minY)
    }

    private func freeRect(_ rect: CGRect, movingBottomTo proposedY: CGFloat, bounds: CGRect) -> CGRect {
        let maxY = proposedY.clamped(to: (rect.minY + minCropLength)...bounds.maxY)
        return CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: maxY - rect.minY)
    }

    private func cornerRect(
        initialRect: CGRect,
        movingPoint: CGPoint,
        oppositePoint: CGPoint,
        horizontalDirection: CGFloat,
        verticalDirection: CGFloat,
        bounds: CGRect,
        aspectRatio: CGFloat?
    ) -> CGRect {
        if let aspectRatio {
            return fixedAspectCornerRect(
                movingPoint: movingPoint,
                oppositePoint: oppositePoint,
                horizontalDirection: horizontalDirection,
                verticalDirection: verticalDirection,
                bounds: bounds,
                aspectRatio: aspectRatio
            )
        }

        var rect = initialRect
        if horizontalDirection < 0 {
            rect = freeRect(rect, movingLeftTo: movingPoint.x, bounds: bounds)
        } else {
            rect = freeRect(rect, movingRightTo: movingPoint.x, bounds: bounds)
        }

        if verticalDirection < 0 {
            rect = freeRect(rect, movingTopTo: movingPoint.y, bounds: bounds)
        } else {
            rect = freeRect(rect, movingBottomTo: movingPoint.y, bounds: bounds)
        }

        return rect
    }

    private func fixedAspectCornerRect(
        movingPoint: CGPoint,
        oppositePoint: CGPoint,
        horizontalDirection: CGFloat,
        verticalDirection: CGFloat,
        bounds: CGRect,
        aspectRatio: CGFloat
    ) -> CGRect {
        let horizontalLimit = horizontalDirection < 0 ? oppositePoint.x - bounds.minX : bounds.maxX - oppositePoint.x
        let verticalLimit = verticalDirection < 0 ? oppositePoint.y - bounds.minY : bounds.maxY - oppositePoint.y
        let maxWidth = max(min(horizontalLimit, verticalLimit * aspectRatio), 1)
        let minWidth = min(minCropLength, maxWidth)
        let rawWidth = abs(oppositePoint.x - movingPoint.x)
        let rawHeightWidth = abs(oppositePoint.y - movingPoint.y) * aspectRatio
        let width = min(rawWidth, rawHeightWidth).clamped(to: minWidth...max(maxWidth, minWidth))
        let height = width / aspectRatio
        let originX = horizontalDirection < 0 ? oppositePoint.x - width : oppositePoint.x
        let originY = verticalDirection < 0 ? oppositePoint.y - height : oppositePoint.y
        return CGRect(x: originX, y: originY, width: width, height: height)
    }
}

private struct CropOverlayGuides: Shape {
    let style: CropOverlayPreset

    func path(in rect: CGRect) -> Path {
        guard style != .none, rect.width > 0, rect.height > 0 else {
            return Path()
        }

        switch style {
        case .none:
            return Path()
        case .ruleOfThirds:
            return fractionalGrid(in: rect, fractions: [1.0 / 3.0, 2.0 / 3.0])
        case .goldenRatio:
            let phi = (sqrt(5.0) - 1.0) / 2.0
            return fractionalGrid(in: rect, fractions: [1.0 - phi, phi])
        case .diagonal:
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            return path
        case .grid:
            return fractionalGrid(in: rect, fractions: [0.2, 0.4, 0.6, 0.8])
        }
    }

    private func fractionalGrid(in rect: CGRect, fractions: [Double]) -> Path {
        Path { path in
            for fraction in fractions {
                let x = rect.minX + rect.width * fraction
                let y = rect.minY + rect.height * fraction

                path.move(to: CGPoint(x: x, y: rect.minY))
                path.addLine(to: CGPoint(x: x, y: rect.maxY))
                path.move(to: CGPoint(x: rect.minX, y: y))
                path.addLine(to: CGPoint(x: rect.maxX, y: y))
            }
        }
    }
}

private struct CropDragState {
    let handle: CropHandle
    let initialFrameRect: CGRect
    let initialCrop: CropSettings
}

private enum CropHandle {
    case move
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    func position(in rect: CGRect) -> CGPoint {
        switch self {
        case .move:
            return CGPoint(x: rect.midX, y: rect.midY)
        case .topLeft:
            return CGPoint(x: rect.minX, y: rect.minY)
        case .topRight:
            return CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeft:
            return CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomRight:
            return CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }

    func hitSize(handleHitSize: CGFloat) -> CGSize {
        switch self {
        case .move:
            return .zero
        default:
            return CGSize(width: handleHitSize, height: handleHitSize)
        }
    }

    func markerSize(cornerHandleSize: CGFloat) -> CGSize {
        switch self {
        case .move:
            return .zero
        default:
            return CGSize(width: cornerHandleSize, height: cornerHandleSize)
        }
    }
}
