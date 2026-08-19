import AppKit
import SwiftUI

/// 메뉴바 NSStatusItem과 그 메뉴를 관리한다.
final class MenuBarController: NSObject {

    /// 토글 후의 표시 상태를 반환하는 클로저
    var onToggleDebugOverlay: (() -> Bool)?
    /// 메뉴에서 패널 열기
    var onShowPanel: (() -> Void)?

    private let store: HubStore
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var debugItem: NSMenuItem!

    init(store: HubStore) {
        self.store = store
        super.init()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled",
                                   accessibilityDescription: "NotchHub")
        }
        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let showPanel = NSMenuItem(title: "패널 열기", action: #selector(showPanelAction), keyEquivalent: "o")
        showPanel.target = self
        menu.addItem(showPanel)

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "설정…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        debugItem = NSMenuItem(title: "디버그: 핫존 표시", action: #selector(toggleDebug), keyEquivalent: "d")
        debugItem.target = self
        menu.addItem(debugItem)

        menu.addItem(.separator())

        let about = NSMenuItem(title: "NotchHub 정보", action: #selector(openAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        return menu
    }

    @objc private func showPanelAction() {
        onShowPanel?()
    }

    @objc private func toggleDebug() {
        let visible = onToggleDebugOverlay?() ?? false
        debugItem.state = visible ? .on : .off
    }

    func showSettings() { openSettings() }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered, defer: false)
            window.title = "NotchHub 설정"
            window.contentView = NSHostingView(rootView: SettingsView().environmentObject(store))
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func openAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}
