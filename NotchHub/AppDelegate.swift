import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var menuBarController: MenuBarController?
    private let hotZoneMonitor = HotZoneMonitor()
    private let debugOverlay = DebugOverlayController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController()
        menuBarController?.onToggleDebugOverlay = { [weak self] in
            self?.debugOverlay.toggle()
            return self?.debugOverlay.isVisible ?? false
        }

        hotZoneMonitor.onEnter = { [weak self] zone in
            self?.debugOverlay.setActive(true)
            // M3: 여기서 패널을 띄운다
        }
        hotZoneMonitor.onExit = { [weak self] in
            self?.debugOverlay.setActive(false)
            // M3: 여기서 패널을 숨긴다
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
