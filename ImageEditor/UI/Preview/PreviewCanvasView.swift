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
            let renderedSize = image.map { displaySize(for: $0.size, in: geometry.size) } ?? .zero

            if cropSettings != nil {
                surfaceContent(renderedSize: renderedSize, containerSize: geometry.size)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                ZStack {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: renderedSize.width, height: renderedSize.height)
                        .shadow(color: .black.opacity(0.35), radius: 16, y: 10)

                    if let cropSettings, let onCropChange {
                        CropOverlayView(crop: cropSettings, onCropChange: onCropChange)
                    }
                }
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
        let appliedScale: CGFloat
        if cropSettings != nil {
            appliedScale = max(fitScale, 0.1)
        } else {
            let baseScale = fitToScreen ? fitScale : 1
            appliedScale = max(baseScale * zoomScale, 0.1)
        }
        return CGSize(width: imageSize.width * appliedScale, height: imageSize.height * appliedScale)
    }
}

private struct CropOverlayView: View {
    let crop: CropSettings
    let onCropChange: (CropSettings) -> Void

    @State private var dragState: CropDragState?

    private let minCropLength: CGFloat = 72
    private let handleHitSize: CGFloat = 26
    private let cornerHandleSize: CGFloat = 14
    private let edgeHandleLength: CGFloat = 34

    var body: some View {
        GeometryReader { geometry in
            let bounds = CGRect(origin: .zero, size: geometry.size)
            let cropRect = CropMath.cropRect(for: bounds, crop: crop)

            ZStack {
                Path { path in
                    path.addRect(bounds)
                    path.addRect(cropRect)
                }
                .fill(Color.black.opacity(0.44), style: FillStyle(eoFill: true))

                thirdsGrid(in: cropRect)
                    .stroke(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                Rectangle()
                    .strokeBorder(Color.white.opacity(0.95), lineWidth: 1.5)
                    .frame(width: cropRect.width, height: cropRect.height)
                    .position(x: cropRect.midX, y: cropRect.midY)

                // Drag inside the crop to reposition it.
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: max(cropRect.width - handleHitSize * 2, 24), height: max(cropRect.height - handleHitSize * 2, 24))
                    .position(x: cropRect.midX, y: cropRect.midY)
                    .highPriorityGesture(dragGesture(for: .move, cropRect: cropRect, bounds: bounds))

                handleHitArea(for: .top, cropRect: cropRect, bounds: bounds)
                handleHitArea(for: .bottom, cropRect: cropRect, bounds: bounds)
                handleHitArea(for: .left, cropRect: cropRect, bounds: bounds)
                handleHitArea(for: .right, cropRect: cropRect, bounds: bounds)
                handleHitArea(for: .topLeft, cropRect: cropRect, bounds: bounds)
                handleHitArea(for: .topRight, cropRect: cropRect, bounds: bounds)
                handleHitArea(for: .bottomLeft, cropRect: cropRect, bounds: bounds)
                handleHitArea(for: .bottomRight, cropRect: cropRect, bounds: bounds)
            }
        }
    }

    private func handleHitArea(for handle: CropHandle, cropRect: CGRect, bounds: CGRect) -> some View {
        let position = handle.position(in: cropRect, inset: 10)
        let hitSize = handle.hitSize(handleHitSize: handleHitSize, edgeHandleLength: edgeHandleLength)
        let markerSize = handle.markerSize(cornerHandleSize: cornerHandleSize, edgeHandleLength: edgeHandleLength)

        return ZStack {
            marker(for: handle)
                .frame(width: markerSize.width, height: markerSize.height)
        }
        .frame(width: hitSize.width, height: hitSize.height)
        .position(position)
        .contentShape(Rectangle())
        .highPriorityGesture(dragGesture(for: handle, cropRect: cropRect, bounds: bounds))
    }

    private func marker(for handle: CropHandle) -> some View {
        Group {
            switch handle {
            case .left, .right:
                Capsule()
                    .fill(Color.white)
                    .frame(width: 5, height: edgeHandleLength)
            case .top, .bottom:
                Capsule()
                    .fill(Color.white)
                    .frame(width: edgeHandleLength, height: 5)
            case .move:
                EmptyView()
            default:
                Circle()
                    .fill(Color.white)
                    .overlay {
                        Circle()
                            .stroke(Color.black.opacity(0.18), lineWidth: 1)
                    }
            }
        }
        .shadow(color: .black.opacity(0.24), radius: 2, y: 1)
    }

    private func dragGesture(for handle: CropHandle, cropRect: CGRect, bounds: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragState?.handle != handle {
                    dragState = CropDragState(handle: handle, initialRect: cropRect)
                }

                let startingRect = dragState?.initialRect ?? cropRect
                let aspectRatio = CropMath.aspectRatio(for: crop.aspectPreset, in: bounds.size)
                let updatedRect = updatedRect(
                    for: handle,
                    initialRect: startingRect,
                    translation: value.translation,
                    bounds: bounds,
                    aspectRatio: aspectRatio
                )
                let updatedCrop = CropMath.settings(for: updatedRect, in: bounds, basedOn: crop)
                if updatedCrop != crop {
                    onCropChange(updatedCrop)
                }
            }
            .onEnded { _ in
                dragState = nil
            }
    }

    private func thirdsGrid(in rect: CGRect) -> Path {
        Path { path in
            guard rect.width > 0, rect.height > 0 else {
                return
            }

            for fraction in [CGFloat(1.0 / 3.0), CGFloat(2.0 / 3.0)] {
                let x = rect.minX + rect.width * fraction
                let y = rect.minY + rect.height * fraction

                path.move(to: CGPoint(x: x, y: rect.minY))
                path.addLine(to: CGPoint(x: x, y: rect.maxY))
                path.move(to: CGPoint(x: rect.minX, y: y))
                path.addLine(to: CGPoint(x: rect.maxX, y: y))
            }
        }
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
        case .left:
            if let aspectRatio {
                return fixedAspectRectForHorizontalEdge(
                    proposedX: initialRect.minX + translation.width,
                    anchorX: initialRect.maxX,
                    centerY: initialRect.midY,
                    movingLeft: true,
                    bounds: bounds,
                    aspectRatio: aspectRatio
                )
            }
            return freeRect(initialRect, movingLeftTo: initialRect.minX + translation.width, bounds: bounds)
        case .right:
            if let aspectRatio {
                return fixedAspectRectForHorizontalEdge(
                    proposedX: initialRect.maxX + translation.width,
                    anchorX: initialRect.minX,
                    centerY: initialRect.midY,
                    movingLeft: false,
                    bounds: bounds,
                    aspectRatio: aspectRatio
                )
            }
            return freeRect(initialRect, movingRightTo: initialRect.maxX + translation.width, bounds: bounds)
        case .top:
            if let aspectRatio {
                return fixedAspectRectForVerticalEdge(
                    proposedY: initialRect.minY + translation.height,
                    anchorY: initialRect.maxY,
                    centerX: initialRect.midX,
                    movingUp: true,
                    bounds: bounds,
                    aspectRatio: aspectRatio
                )
            }
            return freeRect(initialRect, movingTopTo: initialRect.minY + translation.height, bounds: bounds)
        case .bottom:
            if let aspectRatio {
                return fixedAspectRectForVerticalEdge(
                    proposedY: initialRect.maxY + translation.height,
                    anchorY: initialRect.minY,
                    centerX: initialRect.midX,
                    movingUp: false,
                    bounds: bounds,
                    aspectRatio: aspectRatio
                )
            }
            return freeRect(initialRect, movingBottomTo: initialRect.maxY + translation.height, bounds: bounds)
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

    private func fixedAspectRectForHorizontalEdge(
        proposedX: CGFloat,
        anchorX: CGFloat,
        centerY: CGFloat,
        movingLeft: Bool,
        bounds: CGRect,
        aspectRatio: CGFloat
    ) -> CGRect {
        let horizontalLimit = movingLeft ? anchorX - bounds.minX : bounds.maxX - anchorX
        let verticalLimit = min(centerY - bounds.minY, bounds.maxY - centerY) * 2 * aspectRatio
        let maxWidth = max(min(horizontalLimit, verticalLimit), 1)
        let minWidth = min(minCropLength, maxWidth)
        let rawWidth = movingLeft ? anchorX - proposedX : proposedX - anchorX
        let width = rawWidth.clamped(to: minWidth...max(maxWidth, minWidth))
        let height = width / aspectRatio
        let y = (centerY - height / 2).clamped(to: bounds.minY...(bounds.maxY - height))
        let x = movingLeft ? anchorX - width : anchorX
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func fixedAspectRectForVerticalEdge(
        proposedY: CGFloat,
        anchorY: CGFloat,
        centerX: CGFloat,
        movingUp: Bool,
        bounds: CGRect,
        aspectRatio: CGFloat
    ) -> CGRect {
        let verticalLimit = movingUp ? anchorY - bounds.minY : bounds.maxY - anchorY
        let horizontalLimit = min(centerX - bounds.minX, bounds.maxX - centerX) * 2 / max(aspectRatio, 0.0001)
        let maxHeight = max(min(verticalLimit, horizontalLimit), 1)
        let minHeight = min(minCropLength / max(aspectRatio, 0.0001), maxHeight)
        let rawHeight = movingUp ? anchorY - proposedY : proposedY - anchorY
        let height = rawHeight.clamped(to: minHeight...max(maxHeight, minHeight))
        let width = height * aspectRatio
        let x = (centerX - width / 2).clamped(to: bounds.minX...(bounds.maxX - width))
        let y = movingUp ? anchorY - height : anchorY
        return CGRect(x: x, y: y, width: width, height: height)
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

private struct CropDragState {
    let handle: CropHandle
    let initialRect: CGRect
}

private enum CropHandle {
    case move
    case top
    case bottom
    case left
    case right
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    func position(in rect: CGRect, inset: CGFloat) -> CGPoint {
        let insetX = min(inset, rect.width / 2)
        let insetY = min(inset, rect.height / 2)

        switch self {
        case .move:
            return CGPoint(x: rect.midX, y: rect.midY)
        case .top:
            return CGPoint(x: rect.midX, y: rect.minY + insetY)
        case .bottom:
            return CGPoint(x: rect.midX, y: rect.maxY - insetY)
        case .left:
            return CGPoint(x: rect.minX + insetX, y: rect.midY)
        case .right:
            return CGPoint(x: rect.maxX - insetX, y: rect.midY)
        case .topLeft:
            return CGPoint(x: rect.minX + insetX, y: rect.minY + insetY)
        case .topRight:
            return CGPoint(x: rect.maxX - insetX, y: rect.minY + insetY)
        case .bottomLeft:
            return CGPoint(x: rect.minX + insetX, y: rect.maxY - insetY)
        case .bottomRight:
            return CGPoint(x: rect.maxX - insetX, y: rect.maxY - insetY)
        }
    }

    func hitSize(handleHitSize: CGFloat, edgeHandleLength: CGFloat) -> CGSize {
        switch self {
        case .left, .right:
            return CGSize(width: handleHitSize, height: edgeHandleLength + 10)
        case .top, .bottom:
            return CGSize(width: edgeHandleLength + 10, height: handleHitSize)
        case .move:
            return .zero
        default:
            return CGSize(width: handleHitSize, height: handleHitSize)
        }
    }

    func markerSize(cornerHandleSize: CGFloat, edgeHandleLength: CGFloat) -> CGSize {
        switch self {
        case .left, .right:
            return CGSize(width: 5, height: edgeHandleLength)
        case .top, .bottom:
            return CGSize(width: edgeHandleLength, height: 5)
        case .move:
            return .zero
        default:
            return CGSize(width: cornerHandleSize, height: cornerHandleSize)
        }
    }
}
