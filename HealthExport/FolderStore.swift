import Foundation
import Combine

@MainActor
final class FolderStore: ObservableObject {

    @Published private(set) var folderURL: URL?
    @Published private(set) var displayPath: String = "App 本地 Documents（默认）"

    private let bookmarkKey = "exportFolderBookmark"

    init() {
        resolveSavedBookmark()
    }

    func setFolder(_ url: URL) throws {
        _ = url.startAccessingSecurityScopedResource()
        let data = try url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(data, forKey: bookmarkKey)
        folderURL = url
        displayPath = prettyPath(for: url)
    }

    func clear() {
        folderURL?.stopAccessingSecurityScopedResource()
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        folderURL = nil
        displayPath = "App 本地 Documents（默认）"
    }

    private func resolveSavedBookmark() {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return }
        var stale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            if url.startAccessingSecurityScopedResource() {
                folderURL = url
                displayPath = prettyPath(for: url)
                if stale {
                    try? setFolder(url)
                }
            }
        } catch {
            // Saved bookmark is broken; clear so user picks again.
            UserDefaults.standard.removeObject(forKey: bookmarkKey)
        }
    }

    private func prettyPath(for url: URL) -> String {
        let path = url.path
        // iCloud Drive: /private/var/.../Mobile Documents/iCloud~xxx/...
        if let range = path.range(of: "Mobile Documents/") {
            let after = path[range.upperBound...]
            let parts = after.split(separator: "/").map(String.init)
            if let first = parts.first, first.hasPrefix("iCloud~") {
                let rest = parts.dropFirst().joined(separator: "/")
                return rest.isEmpty ? "iCloud Drive" : "iCloud Drive/\(rest)"
            }
            return String(after)
        }
        // Local/other provider: show last two path components
        let parts = path.split(separator: "/").map(String.init)
        let tail = parts.suffix(2).joined(separator: "/")
        return tail
    }
}
