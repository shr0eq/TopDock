import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var menuBarController: MenuBarController?
    private let hotZoneMonitor = HotZoneMonitor()
    private let panelController = PanelController()
    private let debugOverlay = DebugOverlayController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController()
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
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotZoneMonitor.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false   // 메뉴바 상주 앱 — 창이 닫혀도 종료하지 않는다
    }
}
