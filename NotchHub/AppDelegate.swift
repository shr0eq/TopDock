import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    static private(set) var shared: AppDelegate!

    let store = HubStore()

    private var menuBarController: MenuBarController?
    private let hotZoneMonitor = HotZoneMonitor()
    private var panelController: PanelController!
    private let debugOverlay = DebugOverlayController()
    private var observers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        panelController = PanelController(store: store)

        menuBarController = MenuBarController(store: store)
        menuBarController?.onToggleDebugOverlay = { [weak self] in
            self?.debugOverlay.toggle()
            return self?.debugOverlay.isVisible ?? false
        }

        hotZoneMonitor.panelFrameProvider = { [weak self] in
            self?.panelController.visibleFrame
        }
        hotZoneMonitor.isExitSuppressed = { [weak self] in
            self?.panelController.state.isPinned ?? false
        }
        hotZoneMonitor.onEnter = { [weak self] zone in
            self?.debugOverlay.setActive(true)
            self?.panelController.show(at: zone)
        }
        hotZoneMonitor.onExit = { [weak self] in
            self?.debugOverlay.setActive(false)
            self?.panelController.hide()
        }
        hotZoneMonitor.start()

        // 항목 실행 → 패널 닫기 (핀 시 유지)
        observers.append(NotificationCenter.default.addObserver(
            forName: .hubItemActivated, object: nil, queue: .main) { [weak self] _ in
            self?.panelController.hide()
        })
        // 패널 빈 화면의 "설정에서 추가" → 설정 창
        observers.append(NotificationCenter.default.addObserver(
            forName: .openSettingsRequested, object: nil, queue: .main) { [weak self] _ in
            self?.menuBarController?.showSettings()
        })
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotZoneMonitor.stop()
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false   // 메뉴바 상주 앱 — 창이 닫혀도 종료하지 않는다
    }
}
