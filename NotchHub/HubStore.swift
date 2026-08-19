import AppKit
import os

/// 항목 묶음 (프로필). 예: "기본", "논문 작업", "개발"
struct Workspace: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var items: [HubItem]

    init(name: String, items: [HubItem] = []) {
        self.id = UUID()
        self.name = name
        self.items = items
    }
}

/// Workspace CRUD + 현재 워크스페이스의 항목 CRUD + UserDefaults(JSON) 영속화.
final class HubStore: ObservableObject {

    @Published private(set) var workspaces: [Workspace] = []
    @Published private(set) var currentID: UUID?

    private static let workspacesKey = "workspaces.v2"
    private static let currentKey = "currentWorkspaceID"
    private static let legacyItemsKey = "hubItems"
    private let log = Logger(subsystem: "com.wonyoungchoi.NotchHub", category: "store")

    init() {
        load()
    }

    // MARK: - 현재 워크스페이스 항목 (기존 뷰 호환 API)

    var current: Workspace? {
        workspaces.first { $0.id == currentID } ?? workspaces.first
    }

    var items: [HubItem] { current?.items ?? [] }

    func add(urls: [URL]) {
        mutateCurrent { ws in
            let existing = Set(ws.items.map { $0.url.standardizedFileURL })
            let fresh = urls
                .map { $0.standardizedFileURL }
                .filter { !existing.contains($0) }
                .map { HubItem(url: $0) }
            ws.items.append(contentsOf: fresh)
        }
    }

    func remove(_ item: HubItem) {
        mutateCurrent { $0.items.removeAll { $0.id == item.id } }
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        mutateCurrent { $0.items.move(fromOffsets: source, toOffset: destination) }
    }

    // MARK: - Workspace CRUD

    func select(_ id: UUID) {
        guard workspaces.contains(where: { $0.id == id }) else { return }
        currentID = id
        save()
    }

    func addWorkspace(name: String) {
        let ws = Workspace(name: name)
        workspaces.append(ws)
        currentID = ws.id
        save()
    }

    func renameCurrent(to name: String) {
        mutateCurrent { $0.name = name }
    }

    func removeCurrentWorkspace() {
        guard workspaces.count > 1, let cur = current else { return }
        workspaces.removeAll { $0.id == cur.id }
        currentID = workspaces.first?.id
        save()
    }

    private func mutateCurrent(_ body: (inout Workspace) -> Void) {
        guard let cur = current,
              let idx = workspaces.firstIndex(where: { $0.id == cur.id }) else { return }
        body(&workspaces[idx])
        save()
    }

    // MARK: - Persistence

    private func load() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Self.workspacesKey),
           let decoded = try? JSONDecoder().decode([Workspace].self, from: data),
           !decoded.isEmpty {
            workspaces = decoded
            if let s = defaults.string(forKey: Self.currentKey), let id = UUID(uuidString: s),
               decoded.contains(where: { $0.id == id }) {
                currentID = id
            } else {
                currentID = decoded.first?.id
            }
            log.notice("loaded \(self.workspaces.count) workspaces")
            return
        }
        // v1 마이그레이션: 단일 항목 배열 → "기본" 워크스페이스
        if let data = defaults.data(forKey: Self.legacyItemsKey),
           let items = try? JSONDecoder().decode([HubItem].self, from: data) {
            let ws = Workspace(name: L10n.isKorean ? "기본" : "Default", items: items)
            workspaces = [ws]
            currentID = ws.id
            save()
            defaults.removeObject(forKey: Self.legacyItemsKey)
            log.notice("migrated \(items.count) legacy items")
            return
        }
        seedDefaults()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(workspaces) else { return }
        let defaults = UserDefaults.standard
        defaults.set(data, forKey: Self.workspacesKey)
        if let currentID { defaults.set(currentID.uuidString, forKey: Self.currentKey) }
    }

    /// 첫 실행: 데스크탑·다운로드를 기본 등록
    private func seedDefaults() {
        let fm = FileManager.default
        var items: [HubItem] = []
        if let d = fm.urls(for: .desktopDirectory, in: .userDomainMask).first { items.append(HubItem(url: d)) }
        if let d = fm.urls(for: .downloadsDirectory, in: .userDomainMask).first { items.append(HubItem(url: d)) }
        let ws = Workspace(name: L10n.isKorean ? "기본" : "Default", items: items)
        workspaces = [ws]
        currentID = ws.id
        save()
        log.notice("seeded workspace with \(items.count) items")
    }
}
