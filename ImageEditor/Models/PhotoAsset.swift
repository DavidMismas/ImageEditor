import Foundation

enum ImageFileKind: String, Codable, Sendable {
    case standard
    case raw
}

struct PhotoAsset: Identifiable, Hashable, Codable, Sendable {
    static let rawExtensions: Set<String> = [
        "cr2", "cr3", "nef", "arw", "raf", "rw2", "orf", "dng", "pef"
    ]

    let id: UUID
    let url: URL
    let filename: String
    let fileKind: ImageFileKind
    let importDate: Date

    init(url: URL) {
        let resolvedURL = url.standardizedResolvedFileURL
        let fileExtension = resolvedURL.pathExtension.lowercased()

        self.id = UUID()
        self.url = resolvedURL
        self.filename = resolvedURL.lastPathComponent
        self.fileKind = PhotoAsset.rawExtensions.contains(fileExtension) ? .raw : .standard
        self.importDate = Date()
    }

    var isRAW: Bool {
        fileKind == .raw
    }
}
