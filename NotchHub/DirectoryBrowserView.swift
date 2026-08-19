import SwiftUI

/// 폴더 내부 파일/하위폴더를 그리드로 표시. 나열은 백그라운드 큐에서.
struct DirectoryBrowserView: View {
    let url: URL

    @EnvironmentObject private var nav: PanelNavigation
    @AppStorage("browserShowHidden") private var showHidden = false
    @AppStorage("browserSortKey") private var sortKey = SortKey.name.rawValue

    @State private var entries: [Entry] = []
    @State private var isLoading = true
    @State private var loadError: String?

    enum SortKey: String, CaseIterable {
        case name, date, size
        var localized: String {
            switch self {
            case .name: return L10n.sortName
            case .date: return L10n.sortDate
            case .size: return L10n.sortSize
            }
        }
    }

    struct Entry: Identifiable, Equatable {
        var id: URL { url }
        let url: URL
        let isDirectory: Bool
        let modified: Date
        let size: Int
        var name: String { url.lastPathComponent }
    }

    private let columns = [GridItem(.adaptive(minimum: 76), spacing: 8)]

    var body: some View {
        Group {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let loadError {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                    Text(loadError).font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if entries.isEmpty {
                Text(L10n.emptyFolder)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(entries) { entry in
                            EntryCell(entry: entry)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .task(id: taskKey) { await load() }
    }

    private var taskKey: String { "\(url.path)|\(showHidden)|\(sortKey)" }

    private func load() async {
        isLoading = true
        loadError = nil
        let target = url
        let hidden = showHidden
        let key = SortKey(rawValue: sortKey) ?? .name

        let result: Result<[Entry], Error> = await Task.detached(priority: .userInitiated) {
            do {
                let keys: [URLResourceKey] = [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey]
                let urls = try FileManager.default.contentsOfDirectory(
                    at: target,
                    includingPropertiesForKeys: keys,
                    options: hidden ? [] : [.skipsHiddenFiles])
                var list = urls.map { u -> Entry in
                    let rv = try? u.resourceValues(forKeys: Set(keys))
                    return Entry(url: u,
                                 isDirectory: rv?.isDirectory ?? false,
                                 modified: rv?.contentModificationDate ?? .distantPast,
                                 size: rv?.fileSize ?? 0)
                }
                switch key {
                case .name:
                    list.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                case .date:
                    list.sort { $0.modified > $1.modified }
                case .size:
                    list.sort { $0.size > $1.size }
                }
                // 폴더 우선
                list.sort { $0.isDirectory && !$1.isDirectory }
                return .success(list)
            } catch {
                return .failure(error)
            }
        }.value

        guard taskKey == "\(target.path)|\(hidden)|\(key.rawValue)" else { return }  // 뒤늦은 결과 무시
        switch result {
        case .success(let list): entries = list
        case .failure(let error): loadError = error.localizedDescription
        }
        isLoading = false
    }
}

struct EntryCell: View {
    let entry: DirectoryBrowserView.Entry
    @EnvironmentObject private var nav: PanelNavigation
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: IconCache.icon(forPath: entry.url.path))
                .resizable()
                .frame(width: 48, height: 48)
            Text(entry.name)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(width: 76, height: 74)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHovering ? Color.primary.opacity(0.08) : .clear)
        )
        .onHover { isHovering = $0 }
        .onTapGesture { activate() }
        .contextMenu {
            Button(L10n.open) {
                NSWorkspace.shared.open(entry.url)
                NotificationCenter.default.post(name: .hubItemActivated, object: nil)
            }
            Button(L10n.revealInFinder) {
                NSWorkspace.shared.activateFileViewerSelecting([entry.url])
                NotificationCenter.default.post(name: .hubItemActivated, object: nil)
            }
        }
        .help(entry.url.path)
    }

    private func activate() {
        if NSEvent.modifierFlags.contains(.command) {
            NSWorkspace.shared.activateFileViewerSelecting([entry.url])
            NotificationCenter.default.post(name: .hubItemActivated, object: nil)
        } else if entry.isDirectory && entry.url.pathExtension != "app" {
            nav.push(entry.url)
        } else {
            NSWorkspace.shared.open(entry.url)
            NotificationCenter.default.post(name: .hubItemActivated, object: nil)
        }
    }
}
