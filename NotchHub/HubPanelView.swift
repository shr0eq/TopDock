import SwiftUI

struct HubPanelView: View {
    @EnvironmentObject private var state: PanelController.State
    @EnvironmentObject private var nav: PanelNavigation
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
                .help("뒤로")

                Image(nsImage: IconCache.icon(forPath: current.path, size: 18))
                    .resizable()
                    .frame(width: 18, height: 18)
                Text(current.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Menu {
                    Picker("정렬", selection: $sortKey) {
                        ForEach(DirectoryBrowserView.SortKey.allCases, id: \.rawValue) { key in
                            Text(key.label).tag(key.rawValue)
                        }
                    }
                    Toggle("숨김 파일 표시", isOn: $showHidden)
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("정렬·숨김 파일")

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([current])
                    NotificationCenter.default.post(name: .hubItemActivated, object: nil)
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                }
                .buttonStyle(.plain)
                .help("Finder에서 열기")
            } else {
                // ── 루트: 타이틀 ──
                Image(systemName: "rectangle.topthird.inset.filled")
                    .foregroundStyle(.secondary)
                Text("NotchHub")
                    .font(.headline)
                Spacer()
            }

            Button {
                state.isPinned.toggle()
            } label: {
                Image(systemName: state.isPinned ? "pin.fill" : "pin")
                    .foregroundStyle(state.isPinned ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help(state.isPinned ? "핀 해제" : "핀 고정")
        }
    }
}
