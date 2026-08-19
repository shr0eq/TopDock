import SwiftUI

@main
struct NotchHubApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // LSUIElement 메뉴바 앱 — 일반 윈도우 Scene은 두지 않는다.
        // 설정 창은 AppDelegate가 직접 관리한다.
        Settings {
            SettingsView()
        }
    }
}
