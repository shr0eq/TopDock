import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    static private(set) var shared: AppDelegate!

    let store = HubStore()

    private var menuBarController: MenuBarController?
    private let hotZoneMonitor = HotZoneMonitor()
    private var panelController: PanelController!
    private let debugOverlay = DebugOverlayController()
    private let hotKeyManager = HotKeyManager()
    private var observers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        panelController = PanelController(store: store)

        menuBarController = MenuBarController(store: store)
        menuBarController?.onToggleDebugOverlay = { [weak self] in
            self?.debugOverlay.toggle()
            return self?.debugOverlay.isVisible ?? false
        }
        menuBarController?.onShowPanel = { [weak self] in
            guard let self, let screen = NSScreen.main ?? NSScreen.screens.first else { return }
            self.panelController.show(at: ScreenGeometry.hotZone(for: screen))
            self.hotZoneMonitor.markEntered()   // 이탈 시 자동 숨김 활성화
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

        // 전역 단축키 ⌥Space → 패널 토글
        hotKeyManager.onHotKey = { [weak self] in
            guard let self else { return }
            if self.panelController.isVisible {
                self.panelController.state.isPinned = false
                self.panelController.hide()
            } else if let screen = NSScreen.main ?? NSScreen.screens.first {
                self.panelController.show(at: ScreenGeometry.hotZone(for: screen))
                self.hotZoneMonitor.markEntered()
            }
        }
        hotKeyManager.register()

        // 설정에서 외장 핫존 너비 변경 시 존 재계산
        observers.append(NotificationCenter.default.addObserver(
            forName: .externalZoneWidthChanged, object: nil, queue: .main) { [weak self] _ in
            self?.hotZoneMonitor.rebuildZones()
        })

        #if DEBUG
        // 테스트 자동화용: 셸에서 패널 열기 트리거
        //   notifyutil 대신: distributed notification
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("NotchHub.test.showPanel"),
            object: nil, queue: .main) { [weak self] _ in
            guard let self, let screen = NSScreen.main ?? NSScreen.screens.first else { return }
            self.panelController.show(at: ScreenGeometry.hotZone(for: screen))
            self.hotZoneMonitor.markEntered()
        }
        #endif

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
        hotKeyManager.unregister()
        hotZoneMonitor.stop()
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false   // 메뉴바 상주 앱 — 창이 닫혀도 종료하지 않는다
    }
}
