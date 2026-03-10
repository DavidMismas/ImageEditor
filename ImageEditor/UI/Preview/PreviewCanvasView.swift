@preconcurrency import AppKit
import SwiftUI

struct PreviewCanvasView: View {
    let primaryImage: NSImage?
    let comparisonImage: NSImage?
    let mode: PreviewMode
    let zoomScale: CGFloat
    let fitToScreen: Bool
    let isRendering: Bool
    let onSizeChange: (CGSize) -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.08, green: 0.10, blue: 0.14), Color(red: 0.04, green: 0.05, blue: 0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Color.clear
                    .onAppear { onSizeChange(geometry.size) }
                    .onChange(of: geometry.size) { _, newValue in
                        onSizeChange(newValue)
                    }

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

                if isRendering {
                    ProgressView()
                        .controlSize(.large)
                        .padding(20)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }
}

private struct PreviewImageSurface: View {
    let title: String?
    let image: NSImage?
    let zoomScale: CGFloat
    let fitToScreen: Bool

    var body: some View {
        GeometryReader { geometry in
            let renderedSize = image.map { displaySize(for: $0.size, in: geometry.size) } ?? .zero

            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.black.opacity(0.20))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                        }

                    if let image {
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: renderedSize.width, height: renderedSize.height)
                            .shadow(color: .black.opacity(0.35), radius: 16, y: 10)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(14)
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 30, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text("Import an image to start editing")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(24)
                    }

                    if let title {
                        Text(title)
                            .font(.system(.caption, design: .monospaced, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.55), in: Capsule())
                            .padding(14)
                    }
                }
                .frame(
                    width: max(renderedSize.width + 28, geometry.size.width - 2),
                    height: max(renderedSize.height + 28, geometry.size.height - 2)
                )
            }
        }
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
}
