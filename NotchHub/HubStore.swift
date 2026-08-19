import AppKit
import os

/// 등록 항목의 CRUD + UserDefaults(JSON) 영속화.
/// Combine sink 대신 각 변경 지점에서 명시적으로 save() — 시드 시점 누락 방지.
final class HubStore: ObservableObject {

    @Published private(set) var items: [HubItem] = []

    private static let defaultsKey = "hubItems"
    private let log = Logger(subsystem: "com.wonyoungchoi.NotchHub", category: "store")

    init() {
        load()
    }

    func add(urls: [URL]) {
        let existing = Set(items.map { $0.url.standardizedFileURL })
        let fresh = urls
            .map { $0.standardizedFileURL }
            .filter { !existing.contains($0) }
            .map { HubItem(url: $0) }
        guard !fresh.isEmpty else { return }
        items.append(contentsOf: fresh)
        save()
    }

    func remove(_ item: HubItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
              let decoded = try? JSONDecoder().decode([HubItem].self, from: data) else {
            seedDefaults()
            return
        }
        items = decoded
        log.notice("loaded \(self.items.count) items")
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }

    /// 첫 실행: 데스크탑·다운로드를 기본 등록
    private func seedDefaults() {
        let fm = FileManager.default
        var urls: [URL] = []
        if let d = fm.urls(for: .desktopDirectory, in: .userDomainMask).first { urls.append(d) }
        if let d = fm.urls(for: .downloadsDirectory, in: .userDomainMask).first { urls.append(d) }
        add(urls: urls)
        log.notice("seeded \(self.items.count) items")
    }
}
