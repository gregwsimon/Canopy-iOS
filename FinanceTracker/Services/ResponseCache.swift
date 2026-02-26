import Foundation

/// Simple in-memory stale-while-revalidate cache for API responses.
/// Shows cached data instantly, refreshes in background.
final class ResponseCache {
    static let shared = ResponseCache()
    private var store: [String: Data] = [:]
    private let queue = DispatchQueue(label: "response-cache")

    func get<T: Decodable>(_ key: String) -> T? {
        queue.sync {
            guard let data = store[key] else { return nil }
            return try? JSONDecoder().decode(T.self, from: data)
        }
    }

    func set<T: Encodable>(_ key: String, value: T) {
        if let data = try? JSONEncoder().encode(value) {
            queue.sync {
                store[key] = data
            }
        }
    }

    func clear() {
        queue.sync { store.removeAll() }
    }
}
