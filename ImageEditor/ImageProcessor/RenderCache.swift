import Foundation

actor RenderCache<Key: Hashable & Sendable, Value: Sendable> {
    private var storage: [Key: Value] = [:]

    func value(for key: Key) -> Value? {
        storage[key]
    }

    func insert(_ value: Value, for key: Key) {
        storage[key] = value
    }

    func removeAll() {
        storage.removeAll(keepingCapacity: true)
    }
}
