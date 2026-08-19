import Foundation

/// 패널 내부 폴더 탐색 스택. 비어 있으면 루트(등록 항목 그리드).
final class PanelNavigation: ObservableObject {
    @Published private(set) var stack: [URL] = []

    var current: URL? { stack.last }

    func push(_ url: URL) { stack.append(url) }
    func pop() { _ = stack.popLast() }
    func reset() { stack.removeAll() }
}

/// 패널 검색어 (루트 그리드·폴더 탐색 공용 필터)
final class PanelSearch: ObservableObject {
    @Published var text = ""
    func reset() { text = "" }
}
