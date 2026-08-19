import AppKit

/// M2 검증용: 각 핫존 위치에 반투명 오버레이를 그린다.
/// 빨강 = 대기, 초록 = 커서 진입 상태. 클릭은 그대로 통과.
final class DebugOverlayController {

    private var panels: [NSPanel] = []
    private var observer: NSObjectProtocol?
    private(set) var isVisible = false

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: .hotZonesDidChange, object: nil, queue: .main) { [weak self] _ in
            guard let self, self.isVisible else { return }
            self.hide(); self.show()
        }
    }

    func toggle() { isVisible ? hide() : show() }

    func show() {
        hide()
        for zone in ScreenGeometry.allHotZones() {
            // 핫존이 너무 얇으면(외장 4px) 눈에 안 보이므로 시각화는 최소 12px로 부풀린다
            var r = zone.rect
            if r.height < 12 {
                r.origin.y -= (12 - r.height)
                r.size.height = 12
            }
            let panel = NSPanel(contentRect: r,
                                styleMask: [.borderless, .nonactivatingPanel],
                                backing: .buffered, defer: false)
            panel.level = .screenSaver
            panel.isOpaque = false
            panel.hasShadow = false
            panel.ignoresMouseEvents = true          // 클릭 통과
            panel.backgroundColor = NSColor.systemRed.withAlphaComponent(0.35)
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.orderFrontRegardless()
            panels.append(panel)
        }
        isVisible = true
    }

    func hide() {
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
        isVisible = false
    }

    /// 진입/이탈 상태 시각화
    func setActive(_ active: Bool) {
        let color = active ? NSColor.systemGreen.withAlphaComponent(0.5)
                           : NSColor.systemRed.withAlphaComponent(0.35)
        panels.forEach { $0.backgroundColor = color }
    }
}
