import SwiftUI

extension Notification.Name {
    /// 항목 실행 후 패널을 닫으라는 신호
    static let hubItemActivated = Notification.Name("NotchHub.hubItemActivated")
    /// 설정 창을 열라는 신호
    static let openSettingsRequested = Notification.Name("NotchHub.openSettingsRequested")
}

struct ItemGridView: View {
    @EnvironmentObject private var store: HubStore

    private let columns = [GridItem(.adaptive(minimum: 76), spacing: 8)]

    var body: some View {
        if store.items.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(store.items) { item in
                        ItemCell(item: item)
                    }
                }
                .padding(12)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("등록된 항목이 없습니다")
                .foregroundStyle(.secondary)
            Button("설정에서 추가…") {
                NotificationCenter.default.post(name: .openSettingsRequested, object: nil)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ItemCell: View {
    let item: HubItem
    @State private var isHovering = false

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
                .fill(isHovering ? Color.primary.opacity(0.08) : .clear)
        )
        .onHover { isHovering = $0 }
        .onTapGesture { activate() }
        .help(item.url.path)
    }

    private func activate() {
        let modifiers = NSEvent.modifierFlags
        if modifiers.contains(.command) {
            // ⌘+클릭 → Finder에서 표시
            NSWorkspace.shared.activateFileViewerSelecting([item.url])
        } else {
            // M5에서 폴더는 인패널 탐색으로 전환 예정. M4에서는 모두 열기.
            NSWorkspace.shared.open(item.url)
        }
        NotificationCenter.default.post(name: .hubItemActivated, object: nil)
    }
}
