import AppKit

@MainActor
final class IconCache {
    static let shared = IconCache()

    private let cache = NSCache<NSString, NSImage>()

    func icon(for bundleIdentifier: String) -> NSImage {
        if let cached = cache.object(forKey: bundleIdentifier as NSString) {
            return cached
        }

        let image: NSImage
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            image = NSWorkspace.shared.icon(forFile: appURL.path)
        } else {
            image = NSWorkspace.shared.icon(for: .applicationBundle)
        }

        cache.setObject(image, forKey: bundleIdentifier as NSString)
        return image
    }
}
