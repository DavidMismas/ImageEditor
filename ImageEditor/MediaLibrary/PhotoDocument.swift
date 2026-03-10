@preconcurrency import AppKit
import Combine
import SwiftUI

@MainActor
final class PhotoDocument: ObservableObject, Identifiable {
    let id: UUID
    let asset: PhotoAsset

    @Published var settings: AdjustmentSettings
    @Published var thumbnail: NSImage?

    init(asset: PhotoAsset, settings: AdjustmentSettings = AdjustmentSettings()) {
        self.id = asset.id
        self.asset = asset
        self.settings = settings
    }

    var title: String {
        asset.filename
    }

    func updateSettings(_ mutate: (inout AdjustmentSettings) -> Void) {
        var updated = settings
        mutate(&updated)
        settings = updated
    }

    func binding<Value>(for keyPath: WritableKeyPath<AdjustmentSettings, Value>) -> Binding<Value> {
        Binding(
            get: { self.settings[keyPath: keyPath] },
            set: { newValue in
                var updated = self.settings
                updated[keyPath: keyPath] = newValue
                self.settings = updated
            }
        )
    }
}
