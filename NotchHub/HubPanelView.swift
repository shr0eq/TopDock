import SwiftUI

struct HubPanelView: View {
    @EnvironmentObject private var state: PanelController.State
    @EnvironmentObject private var nav: PanelNavigation
    @EnvironmentObject private var store: HubStore
    @EnvironmentObject private var search: PanelSearch
    @AppStorage("browserShowHidden") private var showHidden = false
    @AppStorage("browserSortKey") private var sortKey = DirectoryBrowserView.SortKey.name.rawValue

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

            Divider()

            if let current = nav.current {
                DirectoryBrowserView(url: current)
            } else {
                ItemGridView()
            }
        }
        .frame(width: 520, height: 260)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 8) {
            if let current = nav.current {
                // ── 탐색 모드: 뒤로 + 폴더명 + 도구 ──
                Button { nav.pop() } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                .help(L10n.back)

                Image(nsImage: IconCache.icon(forPath: current.path, size: 18))
                    .resizable()
                    .frame(width: 18, height: 18)
                Text(current.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                searchField

                Menu {
                    Picker(L10n.sortLabel, selection: $sortKey) {
                        ForEach(DirectoryBrowserView.SortKey.allCases, id: \.rawValue) { key in
                            Text(key.localized).tag(key.rawValue)
                        }
                    }
                    Toggle(L10n.showHiddenFiles, isOn: $showHidden)
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help(L10n.sortAndHidden)

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([current])
                    NotificationCenter.default.post(name: .hubItemActivated, object: nil)
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                }
                .buttonStyle(.plain)
                .help(L10n.revealInFinder)
            } else {
                // ── 루트: 워크스페이스 메뉴 ──
                Image(systemName: "rectangle.topthird.inset.filled")
                    .foregroundStyle(.secondary)

                Menu {
                    ForEach(store.workspaces) { ws in
                        Button {
                            store.select(ws.id)
                        } label: {
                            if ws.id == store.current?.id {
                                Label(ws.name, systemImage: "checkmark")
                            } else {
                                Text(ws.name)
                            }
                        }
                    }
                } label: {
                    Text(store.current?.name ?? "NotchHub")
                        .font(.headline)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Spacer()

                searchField
            }

            Button {
                state.isPinned.toggle()
            } label: {
                Image(systemName: state.isPinned ? "pin.fill" : "pin")
                    .foregroundStyle(state.isPinned ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help(state.isPinned ? L10n.unpin : L10n.pin)
        }
    }

    private var searchField: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(L10n.search, text: $search.text)
                .textFieldStyle(.plain)
                .font(.callout)
                .frame(width: 90)
            if !search.text.isEmpty {
                Button { search.reset() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.primary.opacity(0.06), in: Capsule())
    }
}
