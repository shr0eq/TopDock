import AppKit
import os

/// 전역 마우스 이동을 감시해 핫존 진입/이탈을 판정한다.
/// - 글로벌 모니터는 자기 앱 활성 시 발화하지 않으므로 로컬 모니터와 쌍으로 설치.
/// - .mouseMoved 는 고빈도 발화 → 상태 무변화 시 즉시 반환하는 가드 필수.
/// - 패널이 떠 있는 동안 패널 프레임을 "확장 존"으로 취급해,
///   핫존→패널로 커서가 이동해도 이탈로 판정하지 않는다.
final class HotZoneMonitor {

    var onEnter: ((ScreenGeometry.HotZone) -> Void)?
    var onExit: (() -> Void)?

    /// 패널이 표시 중이면 그 프레임(전역 좌표)을 반환. 아니면 nil.
    var panelFrameProvider: (() -> NSRect?)?
    /// true면 이탈해도 onExit를 부르지 않는다 (핀 고정)
    var isExitSuppressed: (() -> Bool)?

    /// 스쳐 지나갈 때 오작동 방지: 이 시간 이상 머물러야 진입으로 판정
    var dwellDelay: TimeInterval = 0.25
    /// 이탈 후 이 시간이 지나야 나간 것으로 판정 (핫존→패널 이동 여유).
    /// Dock처럼 즉각 사라지는 느낌 — 노치 스트립→패널 이동(~30pt)만 버티면 됨.
    var hideDelay: TimeInterval = 0.15

    private let log = Logger(subsystem: "com.wonyoungchoi.NotchHub", category: "hotzone")

    private enum Location: Equatable {
        case outside
        case zone(Int)
        case panel
    }

    private(set) var zones: [ScreenGeometry.HotZone] = []
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var location: Location = .outside     // 상태 가드
    private var hasEntered = false                 // onEnter 전달 여부 (스침 시 EXIT 방지)
    private var pendingWork: DispatchWorkItem?
    private var screenObserver: NSObjectProtocol?

    func start() {
        rebuildZones()

        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: events) { [weak self] _ in
            self?.evaluate(NSEvent.mouseLocation)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: events) { [weak self] event in
            self?.evaluate(NSEvent.mouseLocation)
            return event
        }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in
            self?.rebuildZones()
        }
        log.notice("HotZoneMonitor started, zones=\(self.zones.count)")
    }

    func stop() {
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        if let o = screenObserver { NotificationCenter.default.removeObserver(o); screenObserver = nil }
        pendingWork?.cancel()
    }

    /// 패널을 hover 없이(메뉴/단축키) 표시했을 때 호출 — 이후 이탈 시 자동 숨김이 동작하게 함
    func markEntered() { hasEntered = true }

    func rebuildZones() {
        let fresh = ScreenGeometry.allHotZones()

        // 메뉴바 표시/숨김 등으로 didChangeScreenParameters가 연발되어도
        // 기하가 같으면 상태를 유지한다 — 리셋하면 dwell 중인 ENTER가 무효화된다.
        let unchanged = fresh.count == zones.count
            && zip(fresh, zones).allSatisfy { $0.rect == $1.rect && $0.hasNotch == $1.hasNotch }
        zones = fresh                      // 스크린 참조는 항상 최신으로 교체
        guard !unchanged else { return }

        location = .outside
        hasEntered = false
        pendingWork?.cancel()
        for (i, z) in zones.enumerated() {
            log.notice("zone[\(i)] rect=\(String(describing: z.rect), privacy: .public) notch=\(z.hasNotch) screen=\(z.screen.localizedName, privacy: .public)")
        }
        NotificationCenter.default.post(name: .hotZonesDidChange, object: nil)
    }

    /// 화면 최상단에서는 커서 y가 frame.maxY에 고정되는데 NSRect.contains는
    /// 상단 경계를 배타 취급하므로, 경계 포함으로 직접 판정한다.
    private func zoneContains(_ rect: NSRect, _ p: NSPoint) -> Bool {
        p.x >= rect.minX && p.x <= rect.maxX &&
        p.y >= rect.minY && p.y <= rect.maxY
    }

    private func currentLocation(of point: NSPoint) -> Location {
        if let idx = zones.firstIndex(where: { zoneContains($0.rect, point) }) {
            return .zone(idx)
        }
        if let frame = panelFrameProvider?(), frame.contains(point) {
            return .panel
        }
        return .outside
    }

    private func evaluate(_ point: NSPoint) {
        let now = currentLocation(of: point)

        // ★ 성능 가드: 초당 수백 회 호출됨. 상태 변화 없으면 즉시 반환.
        guard now != location else { return }
        let before = location
        location = now

        pendingWork?.cancel()

        switch (before, now) {
        case (_, .zone(let idx)):
            // 핫존 진입 (패널→핫존 재진입 포함): dwell 후 onEnter
            let zone = zones[idx]
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.location == .zone(idx) else { return }
                self.hasEntered = true
                self.log.notice("ENTER zone[\(idx)] notch=\(zone.hasNotch)")
                self.onEnter?(zone)
            }
            pendingWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + dwellDelay, execute: work)

        case (.outside, .panel), (.zone, .panel), (.panel, .panel):
            break   // 패널 위에 있는 동안은 아무것도 하지 않는다

        case (_, .outside) where before != .outside:
            guard hasEntered else { break }          // 진입 확정 전 스침은 무시
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.location == .outside else { return }
                if self.isExitSuppressed?() == true { return }
                self.hasEntered = false
                self.log.notice("EXIT")
                self.onExit?()
            }
            pendingWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + hideDelay, execute: work)

        default:
            break
        }
    }
}

extension Notification.Name {
    static let hotZonesDidChange = Notification.Name("TopDock.hotZonesDidChange")
}
