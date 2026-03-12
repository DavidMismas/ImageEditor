@preconcurrency import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class EditorViewModel: ObservableObject {
    @Published private(set) var documents: [PhotoDocument] = []
    @Published var selectedDocumentID: UUID? {
        didSet { requestRender() }
    }
    @Published var activeTab: EditorTab = .base
    @Published var previewMode: PreviewMode = .edited {
        didSet { requestRender() }
    }
    @Published var isCropOverlayActive = false {
        didSet {
            if isCropOverlayActive != oldValue {
                requestRender()
            }
        }
    }
    @Published var previewImage: NSImage?
    @Published var comparisonImage: NSImage?
    @Published var cropPreviewImage: NSImage?
    @Published var histogram: HistogramData = .empty
    @Published var zoomScale: CGFloat = 1 {
        didSet {
            if abs(zoomScale - oldValue) > 0.02 {
                requestRender()
            }
        }
    }
    @Published var fitToScreen = true {
        didSet {
            if fitToScreen != oldValue, !suppressZoomRenderRequest {
                requestRender()
            }
        }
    }
    @Published var exportFormat: ExportFormat = .jpeg
    @Published var outputColorSpace: OutputColorSpaceOption = .displayP3
    @Published var jpegQuality: Double = 92
    @Published var importedLUTs: [LUTPreset] = []
    @Published var isRendering = false
    @Published var errorMessage: String?

    private let mediaLibrary = MediaLibraryStore()
    private let processor = ImageProcessor()
    private let lutEngine = LUTEngine()

    private var documentSubscriptions: [UUID: AnyCancellable] = [:]
    private var renderTask: Task<Void, Never>?
    private var renderRequestPending = false
    private var requestedRenderRevision: UInt64 = 0
    private var previewSize = CGSize(width: 1280, height: 820)
    private var pendingActualPixelZoom = false
    private var suppressZoomRenderRequest = false

    private static var adjustmentClipboard: AdjustmentSettings?

    var selectedDocument: PhotoDocument? {
        documents.first(where: { $0.id == selectedDocumentID })
    }

    private var importedLUTLookup: [UUID: LUTPreset] {
        Dictionary(uniqueKeysWithValues: importedLUTs.map { ($0.id, $0) })
    }

    func importImages() {
        let existingURLs = Set(documents.map { $0.asset.url })
        let importedDocuments = mediaLibrary.importDocuments(existingURLs: existingURLs)
        guard !importedDocuments.isEmpty else {
            return
        }

        for document in importedDocuments {
            documents.append(document)
            observe(document)
            loadThumbnail(for: document)
        }

        selectedDocumentID = importedDocuments.first?.id ?? selectedDocumentID
    }

    func importLUT() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [UTType(filenameExtension: "cube") ?? .data]
        panel.prompt = "Import LUT"
        panel.title = "Import LUT"

        guard panel.runModal() == .OK else {
            return
        }

        do {
            for url in panel.urls.map(\.standardizedResolvedFileURL) where !importedLUTs.contains(where: { $0.url == url }) {
                importedLUTs.append(try lutEngine.importLUT(from: url))
            }

            if let document = selectedDocument,
               document.settings.lut.selectedLUTID == nil,
               let firstLUT = importedLUTs.first {
                document.updateSettings { $0.lut.selectedLUTID = firstLUT.id }
            }

            requestRender()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func exportSelectedImage() {
        guard let document = selectedDocument else {
            return
        }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [exportFormat.utType]
        savePanel.canCreateDirectories = true
        savePanel.title = "Export Image"
        savePanel.prompt = "Export"
        savePanel.directoryURL = document.asset.url.deletingLastPathComponent()
        savePanel.nameFieldStringValue = exportFilename(for: document)

        guard savePanel.runModal() == .OK, var destinationURL = savePanel.url else {
            return
        }

        if destinationURL.pathExtension.isEmpty {
            destinationURL.appendPathExtension(exportFormat.fileExtension)
        }

        let exportSettings = ExportSettings(
            format: exportFormat,
            colorSpace: outputColorSpace,
            jpegQuality: jpegQuality
        )
        let asset = document.asset
        let settings = document.settings
        let presets = importedLUTLookup

        Task {
            do {
                try await processor.export(
                    asset: asset,
                    settings: settings,
                    presets: presets,
                    exportSettings: exportSettings,
                    destinationURL: destinationURL
                )
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func resetAdjustments() {
        selectedDocument?.settings = AdjustmentSettings()
    }

    func copyAdjustments() {
        Self.adjustmentClipboard = selectedDocument?.settings
    }

    func pasteAdjustments() {
        guard let copiedSettings = Self.adjustmentClipboard else {
            return
        }

        selectedDocument?.settings = copiedSettings
    }

    func fitPreview() {
        pendingActualPixelZoom = false
        fitToScreen = true
        zoomScale = 1
    }

    func zoomToActualPixels() {
        zoomScale = 1
        pendingActualPixelZoom = true
        requestRender()
    }

    func toggleActualPixelsZoom() {
        if !fitToScreen, abs(zoomScale - 1) < 0.01 {
            fitPreview()
        } else {
            zoomToActualPixels()
        }
    }

    func setPreviewSize(_ size: CGSize) {
        let normalizedSize = CGSize(width: size.width.rounded(), height: size.height.rounded())
        guard abs(normalizedSize.width - previewSize.width) > 12 || abs(normalizedSize.height - previewSize.height) > 12 else {
            return
        }

        previewSize = normalizedSize
        requestRender()
    }

    private func observe(_ document: PhotoDocument) {
        documentSubscriptions[document.id] = document.$settings
            .sink { [weak self, weak document] _ in
                guard let self, let document, self.selectedDocumentID == document.id else {
                    return
                }
                self.requestRender()
            }
    }

    private func loadThumbnail(for document: PhotoDocument) {
        let asset = document.asset
        Task {
            let thumbnail = await processor.renderThumbnail(for: asset)
            await MainActor.run {
                document.thumbnail = thumbnail
            }
        }
    }

    private func exportFilename(for document: PhotoDocument) -> String {
        let basename = document.asset.url.deletingPathExtension().lastPathComponent
        return "\(basename)-edit.\(exportFormat.fileExtension)"
    }

    private func requestRender() {
        requestedRenderRevision &+= 1

        guard !renderRequestPending else {
            return
        }

        renderRequestPending = true
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            self.renderRequestPending = false
            self.startRenderLoopIfNeeded()
        }
    }

    private func startRenderLoopIfNeeded() {
        guard renderTask == nil else {
            return
        }

        renderTask = Task { [weak self] in
            guard let self else {
                return
            }

            await self.renderLoop()
        }
    }

    private func renderLoop() async {
        defer { renderTask = nil }

        while true {
            guard let request = makeCurrentRenderRequest() else {
                previewImage = nil
                comparisonImage = nil
                cropPreviewImage = nil
                histogram = .empty
                isRendering = false
                return
            }

            isRendering = true
            errorMessage = nil

            do {
                let result = try await processor.renderPreview(
                    asset: request.asset,
                    settings: request.settings,
                    presets: request.presets,
                    targetSize: request.targetSize,
                    previewMode: request.previewMode,
                    fullResolutionPreview: request.fullResolutionPreview,
                    includeCropSource: request.includeCropSource
                )

                guard selectedDocumentID == request.asset.id else {
                    if requestedRenderRevision == request.revision {
                        isRendering = false
                        return
                    }
                    continue
                }

                previewImage = result.primaryImage
                comparisonImage = result.comparisonImage
                cropPreviewImage = result.cropImage
                histogram = result.histogram

                if pendingActualPixelZoom, request.fullResolutionPreview {
                    pendingActualPixelZoom = false
                    suppressZoomRenderRequest = true
                    fitToScreen = false
                    suppressZoomRenderRequest = false
                }
            } catch {
                guard selectedDocumentID == request.asset.id else {
                    if requestedRenderRevision == request.revision {
                        isRendering = false
                        return
                    }
                    continue
                }

                errorMessage = error.localizedDescription
            }

            if requestedRenderRevision == request.revision {
                isRendering = false
                return
            }
        }
    }

    private func makeCurrentRenderRequest() -> RenderRequest? {
        guard let document = selectedDocument else {
            return nil
        }

        return RenderRequest(
            revision: requestedRenderRevision,
            asset: document.asset,
            settings: document.settings,
            presets: importedLUTLookup,
            previewMode: previewMode,
            targetSize: CGSize(
                width: previewSize.width * max(zoomScale, 1),
                height: previewSize.height * max(zoomScale, 1)
            ),
            fullResolutionPreview: pendingActualPixelZoom || (!fitToScreen && zoomScale >= 1),
            includeCropSource: isCropOverlayActive
        )
    }
}

private struct RenderRequest {
    let revision: UInt64
    let asset: PhotoAsset
    let settings: AdjustmentSettings
    let presets: [UUID: LUTPreset]
    let previewMode: PreviewMode
    let targetSize: CGSize
    let fullResolutionPreview: Bool
    let includeCropSource: Bool
}
