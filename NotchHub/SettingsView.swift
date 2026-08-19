import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var store: HubStore
    @State private var selection: UUID?

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(store.items) { item in
                    HStack(spacing: 8) {
                        Image(nsImage: IconCache.icon(forPath: item.url.path, size: 20))
                            .resizable()
                            .frame(width: 20, height: 20)
                        Text(item.displayName)
                        Spacer()
                        Text(item.url.deletingLastPathComponent().path)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .tag(item.id)
                }
                .onMove { store.move(fromOffsets: $0, toOffset: $1) }
            }

            Divider()

            HStack(spacing: 12) {
                Button {
                    addItems()
                } label: {
                    Image(systemName: "plus")
                }
                .help("폴더·앱·파일 추가")

                Button {
                    if let sel = selection,
                       let item = store.items.first(where: { $0.id == sel }) {
                        store.remove(item)
                        selection = nil
                    }
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(selection == nil)
                .help("선택 항목 제거")

                Spacer()

                Text("드래그로 순서 변경 · Made by Won-Young Choi")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.borderless)
            .padding(10)
        }
        .frame(width: 480, height: 340)
    }

    private func addItems() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.treatsFilePackagesAsDirectories = false   // .app을 파일로 취급
        panel.prompt = "추가"
        panel.message = "패널에 등록할 폴더, 앱, 파일을 선택하세요"
        if panel.runModal() == .OK {
            store.add(urls: panel.urls)
        }
    }
}
