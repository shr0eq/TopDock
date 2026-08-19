import AppKit
import SwiftUI

/// borderless 패널은 기본적으로 key window가 될 수 없다.
/// 나중에 검색 필드 등 키 입력을 받으려면 이 서브클래스가 필요하다.
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// 핫존 트리거로 뜨는 메인 패널의 생성/배치/표시/숨김을 관리한다.
final class PanelController {

    /// 핀 고정 등 패널 상태 (SwiftUI와 공유)
    final class State: ObservableObject {
        @Published var isPinned = false
    }

    let state = State()
    let navigation = PanelNavigation()
    let search = PanelSearch()
    private let store: HubStore

    init(store: HubStore) {
        self.store = store
    }

    private var panel: KeyablePanel?
    private let panelSize = NSSize(width: 520, height: 260)

    private(set) var isVisible = false

    /// 현재 패널 프레임 (전역 좌표). 숨김 상태면 nil.
    var visibleFrame: NSRect? {
        guard isVisible, let panel else { return nil }
        return panel.frame
    }

    func show(at zone: ScreenGeometry.HotZone) {
        let screenFrame = zone.screen.frame
        // 노치(또는 상단 가장자리) 바로 아래, 핫존 수평 중앙에 배치
        let topInset = max(zone.screen.safeAreaInsets.top, 2)
        var origin = NSPoint(x: zone.rect.midX - panelSize.width / 2,
                             y: screenFrame.maxY - topInset - panelSize.height)
        // 화면 밖으로 나가지 않게 클램프
        origin.x = max(screenFrame.minX + 8,
                       min(origin.x, screenFrame.maxX - panelSize.width - 8))

        let p = panel ?? makePanel()
        p.setFrame(NSRect(origin: origin, size: panelSize), display: true)

        guard !isVisible else { return }
        isVisible = true
        p.alphaValue = 0
        p.orderFrontRegardless()                 // 앱을 활성화하지 않고 앞으로
        NSAnimationContext.runAnimationGroup {
            $0.duration = 0.18
            p.animator().alphaValue = 1
        }
    }

    func hide() {
        guard isVisible, let p = panel else { return }
        if state.isPinned { return }
        isVisible = false
        NSAnimationContext.runAnimationGroup({
            $0.duration = 0.14
            p.animator().alphaValue = 0
        }, completionHandler: {
            if !self.isVisible {
                p.orderOut(nil)
                self.navigation.reset()      // 다음 표시는 루트에서 시작
                self.search.reset()
            }
        })
    }

    private func makePanel() -> KeyablePanel {
        let p = KeyablePanel(contentRect: NSRect(origin: .zero, size: panelSize),
                             styleMask: [.borderless, .nonactivatingPanel],
                             backing: .buffered, defer: false)
        p.level = .screenSaver                    // 메뉴바/노치 위
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.isMovable = false
        p.hidesOnDeactivate = false
        p.becomesKeyOnlyIfNeeded = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        p.contentView = NSHostingView(rootView: HubPanelView().environmentObject(state).environmentObject(store).environmentObject(navigation).environmentObject(search))
        panel = p
        return p
    }
}
