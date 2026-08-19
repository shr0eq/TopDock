import SwiftUI
import AppKit
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject private var store: HubStore
    @State private var selection: UUID?
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @AppStorage(L10n.languageKey) private var language = "ko"
    @AppStorage("externalZoneWidth") private var externalZoneWidth = 180.0

    var body: some View {
        TabView {
            itemsTab
                .tabItem { Label(L10n.isKorean ? "항목" : "Items", systemImage: "square.grid.2x2") }
            generalTab
                .tabItem { Label(L10n.isKorean ? "일반" : "General", systemImage: "gearshape") }
        }
        .frame(width: 480, height: 380)
        .id(language)   // 언어 변경 시 UI 갱신
    }

    // MARK: 항목 탭

    private var itemsTab: some View {
        VStack(spacing: 0) {
            workspaceBar
            Divider()
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
                Button { addItems() } label: { Image(systemName: "plus") }
                    .help(L10n.addHelp)
                Button {
                    if let sel = selection,
                       let item = store.items.first(where: { $0.id == sel }) {
                        store.remove(item)
                        selection = nil
                    }
                } label: { Image(systemName: "minus") }
                    .disabled(selection == nil)
                    .help(L10n.removeHelp)
                Spacer()
                Text(L10n.dragToReorder)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.borderless)
            .padding(10)
        }
    }

    // MARK: 워크스페이스 바

    @State private var renameText = ""
    @State private var isRenaming = false

    private var workspaceBar: some View {
        HStack(spacing: 8) {
            Picker(L10n.workspace, selection: Binding(
                get: { store.current?.id ?? UUID() },
                set: { store.select($0) })) {
                ForEach(store.workspaces) { ws in
                    Text(ws.name).tag(ws.id)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 180)

            if isRenaming {
                TextField(L10n.workspaceName, text: $renameText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)
                    .onSubmit {
                        if !renameText.isEmpty { store.renameCurrent(to: renameText) }
                        isRenaming = false
                    }
            } else {
                Button {
                    renameText = store.current?.name ?? ""
                    isRenaming = true
                } label: { Image(systemName: "pencil") }
                    .buttonStyle(.borderless)
                    .help(L10n.renameWorkspace)
            }

            Button {
                store.addWorkspace(name: L10n.newWorkspace)
            } label: { Image(systemName: "plus.rectangle.on.rectangle") }
                .buttonStyle(.borderless)
                .help(L10n.newWorkspace)

            Button {
                store.removeCurrentWorkspace()
            } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless)
                .disabled(store.workspaces.count < 2)
                .help(L10n.deleteWorkspace)

            Spacer()
        }
        .padding(10)
    }

    // MARK: 일반 탭

    private var generalTab: some View {
        Form {
            Toggle(L10n.launchAtLogin, isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enable in
                    do {
                        if enable { try SMAppService.mainApp.register() }
                        else { try SMAppService.mainApp.unregister() }
                    } catch {
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }

            Picker(L10n.language, selection: $language) {
                Text("한국어").tag("ko")
                Text("English").tag("en")
            }
            .onChange(of: language) { _, new in
                L10n.set(korean: new == "ko")
            }

            VStack(alignment: .leading) {
                Slider(value: $externalZoneWidth, in: 80...400, step: 20) {
                    Text(L10n.externalZoneWidth)
                }
                Text("\(Int(externalZoneWidth)) pt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .onChange(of: externalZoneWidth) { _, new in
                ScreenGeometry.fallbackWidth = new
                NotificationCenter.default.post(name: .externalZoneWidthChanged, object: nil)
            }

            LabeledContent(L10n.hotKeyHint) { EmptyView() }

            Text("Made by Won-Young Choi")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .formStyle(.grouped)
    }

    private func addItems() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.treatsFilePackagesAsDirectories = false
        panel.prompt = L10n.addPrompt
        panel.message = L10n.addMessage
        if panel.runModal() == .OK {
            store.add(urls: panel.urls)
        }
    }
}

extension Notification.Name {
    static let externalZoneWidthChanged = Notification.Name("NotchHub.externalZoneWidthChanged")
}
