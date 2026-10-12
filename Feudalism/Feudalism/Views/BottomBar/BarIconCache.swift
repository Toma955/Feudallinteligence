import AppKit

final class BarIconCache {
    static let shared = BarIconCache()

    private let lock = NSLock()
    private var cache: [String: NSImage] = [:]

    private static let subdirs = [
        "Icons",
        "Icons/resources",
        "icons",
        "Core/Icons",
        "Feudalism/Icons",
        "Feudalism/Icons/resources",
        "Feudalism/Feudalism/Icons",
        "Feudalism/Feudalism/Icons/resources",
        "Feudalism/Feudalism/Feudalism/Icons",
        "Feudalism/Feudalism/Feudalism/Icons/resources",
        "Feudalism/Core/Icons",
        "Feudalism/icons",
    ]

    private init() {}

    func image(named name: String, bundle: Bundle = .main) -> NSImage? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[name] { return cached }
        let img = loadUncached(named: name, bundle: bundle)
        if let img = img { cache[name] = img }
        return img
    }

    private func loadUncached(named name: String, bundle: Bundle) -> NSImage? {
        if let img = NSImage(named: name) { return img }
        if let url = bundle.url(forResource: name, withExtension: "png", subdirectory: nil),
           let img = NSImage(contentsOf: url) {
            return img
        }
        for sub in Self.subdirs {
            if let url = bundle.url(forResource: name, withExtension: "png", subdirectory: sub),
               let img = NSImage(contentsOf: url) {
                return img
            }
        }
        return nil
    }
}
