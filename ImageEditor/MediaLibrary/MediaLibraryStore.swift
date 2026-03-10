@preconcurrency import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class MediaLibraryStore {
    func importDocuments(existingURLs: Set<URL>) -> [PhotoDocument] {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        panel.prompt = "Import"
        panel.title = "Import Images"

        guard panel.runModal() == .OK else {
            return []
        }

        return panel.urls
            .map(\.standardizedResolvedFileURL)
            .filter { !existingURLs.contains($0) }
            .map { PhotoDocument(asset: PhotoAsset(url: $0)) }
    }
}
