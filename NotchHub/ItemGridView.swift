import SwiftUI
import UniformTypeIdentifiers

extension Notification.Name {
    /// 항목 실행 후 패널을 닫으라는 신호
    static let hubItemActivated = Notification.Name("NotchHub.hubItemActivated")
    /// 설정 창을 열라는 신호
    static let openSettingsRequested = Notification.Name("NotchHub.openSettingsRequested")
}

/// Finder 드래그는 public.file-url을 제공하므로 NSItemProvider에서 직접 추출한다.
/// (.dropDestination(for: URL.self)은 public.url만 매칭해 Finder 드롭을 놓친다)
func loadDroppedURLs(from providers: [NSItemProvider], completion: @escaping ([URL]) -> Void) {
    var urls: [URL] = []
    let group = DispatchGroup()
    let lock = NSLock()
    for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
        group.enter()
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            defer { group.leave() }
            var url: URL?
            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else if let u = item as? URL {
                url = u
            }
            if let url { lock.lock(); urls.append(url); lock.unlock() }
        }
    }
    group.notify(queue: .main) { completion(urls) }
}

/// 드롭된 파일을 폴더로 복사 (이름 충돌 시 건너뜀, 원본 유지)
func copyDroppedFiles(_ urls: [URL], into folder: URL) {
    DispatchQueue.global(qos: .userInitiated).async {
        let fm = FileManager.default
        for src in urls {
            let dst = folder.appendingPathComponent(src.lastPathComponent)
            guard !fm.fileExists(atPath: dst.path),
                  src.deletingLastPathComponent() != folder else { continue }
            try? fm.copyItem(at: src, to: dst)
        }
    }
}

struct ItemGridView: View {
    @EnvironmentObject private var store: HubStore
    @EnvironmentObject private var search: PanelSearch
    @State private var isDropTargeted = false

    private let columns = [GridItem(.adaptive(minimum: 76), spacing: 8)]

    private var filtered: [HubItem] {
        guard !search.text.isEmpty else { return store.items }
        return store.items.filter {
            $0.displayName.localizedCaseInsensitiveContains(search.text)
        }
    }

    var body: some View {
        Group {
            if store.items.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(filtered) { item in
                            ItemCell(item: item)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 빈 영역에 파일을 떨어뜨리면 허브에 등록
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            guard providers.contains(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else { return false }
            loadDroppedURLs(from: providers) { store.add(urls: $0) }
            return true
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.accentColor, lineWidth: isDropTargeted ? 2 : 0)
                .padding(4)
                .allowsHitTesting(false)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text(L10n.noItems)
                .foregroundStyle(.secondary)
            Button(L10n.addInSettings) {
                NotificationCenter.default.post(name: .openSettingsRequested, object: nil)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ItemCell: View {
    let item: HubItem
    @EnvironmentObject private var nav: PanelNavigation
    @EnvironmentObject private var store: HubStore
    @State private var isHovering = false
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: IconCache.icon(forPath: item.url.path))
                .resizable()
                .frame(width: 48, height: 48)
            Text(item.displayName)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(width: 76, height: 74)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isDropTargeted ? Color.accentColor.opacity(0.25)
                      : isHovering ? Color.primary.opacity(0.08) : .clear)
        )
        .onHover { isHovering = $0 }
        .onTapGesture { activate() }
        .onDrag { NSItemProvider(object: item.url as NSURL) }
        .modifier(FolderDropTarget(folderURL: item.kind == .folder ? item.url : nil,
                                   isTargeted: $isDropTargeted))
        .contextMenu {
            Button(L10n.open) {
                NSWorkspace.shared.open(item.url)
                NotificationCenter.default.post(name: .hubItemActivated, object: nil)
            }
            Button(L10n.revealInFinder) {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
                NotificationCenter.default.post(name: .hubItemActivated, object: nil)
            }
            Button(L10n.preview) {
                QuickLookController.shared.show(item.url)
            }
        }
        .help(item.url.path)
    }

    private func activate() {
        if NSEvent.modifierFlags.contains(.command) {
            NSWorkspace.shared.activateFileViewerSelecting([item.url])
            NotificationCenter.default.post(name: .hubItemActivated, object: nil)
        } else if item.kind == .folder {
            nav.push(item.url)
        } else {
            NSWorkspace.shared.open(item.url)
            NotificationCenter.default.post(name: .hubItemActivated, object: nil)
        }
    }
}

/// 폴더 셀에만 드롭 타겟을 붙이는 모디파이어 (파일이면 no-op)
struct FolderDropTarget: ViewModifier {
    let folderURL: URL?
    @Binding var isTargeted: Bool

    func body(content: Content) -> some View {
        if let folderURL {
            content.onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                guard providers.contains(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else { return false }
                loadDroppedURLs(from: providers) { copyDroppedFiles($0, into: folderURL) }
                return true
            }
        } else {
            content
        }
    }
}
