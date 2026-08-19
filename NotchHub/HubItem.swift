import AppKit

/// 패널에 등록되는 항목 하나 (폴더 / 앱 / 파일)
struct HubItem: Identifiable, Codable, Equatable {
    enum Kind: String, Codable {
        case folder, app, file
    }

    let id: UUID
    var url: URL
    var kind: Kind
    /// 샌드박스(App Store) 전환 대비 자리 (현재 미사용, PLAN R8)
    var bookmarkData: Data?

    var displayName: String {
        if kind == .app {
            return url.deletingPathExtension().lastPathComponent
        }
        return url.lastPathComponent
    }

    init(url: URL) {
        self.id = UUID()
        self.url = url
        if url.pathExtension == "app" {
            self.kind = .app
        } else if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            self.kind = .folder
        } else {
            self.kind = .file
        }
    }
}

/// NSWorkspace 아이콘은 호출 비용이 있으므로 캐시한다.
enum IconCache {
    private static let cache = NSCache<NSString, NSImage>()

    static func icon(forPath path: String, size: CGFloat = 48) -> NSImage {
        let key = "\(path)@\(size)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: size, height: size)
        cache.setObject(icon, forKey: key)
        return icon
    }
}
