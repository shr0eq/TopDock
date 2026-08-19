import Foundation

/// 패널 내부 폴더 탐색 스택. 비어 있으면 루트(등록 항목 그리드).
final class PanelNavigation: ObservableObject {
    @Published private(set) var stack: [URL] = []

    var current: URL? { stack.last }

    func push(_ url: URL) { stack.append(url) }
    func pop() { _ = stack.popLast() }
    func reset() { stack.removeAll() }
}
