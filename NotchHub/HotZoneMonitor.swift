import AppKit
import os

/// 전역 마우스 이동을 감시해 핫존 진입/이탈을 판정한다.
/// - 글로벌 모니터는 자기 앱 활성 시 발화하지 않으므로 로컬 모니터와 쌍으로 설치.
/// - .mouseMoved 는 고빈도 발화 → 상태 무변화 시 즉시 반환하는 가드 필수.
final class HotZoneMonitor {

    var onEnter: ((ScreenGeometry.HotZone) -> Void)?
    var onExit: (() -> Void)?

    /// 스쳐 지나갈 때 오작동 방지: 이 시간 이상 머물러야 진입으로 판정
    var dwellDelay: TimeInterval = 0.25
    /// 이탈 후 이 시간이 지나야 나간 것으로 판정 (패널로 이동할 여유)
    var hideDelay: TimeInterval = 0.40

    private let log = Logger(subsystem: "com.wonyoungchoi.NotchHub", category: "hotzone")

    private(set) var zones: [ScreenGeometry.HotZone] = []
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var insideZoneIndex: Int?          // 현재 커서가 있는 핫존 인덱스 (상태 가드)
    private var pendingWork: DispatchWorkItem?
    private var screenObserver: NSObjectProtocol?

    /// 패널 위에 커서가 있는 동안 이탈 판정을 보류하기 위한 외부 훅
    var isExitSuppressed: (() -> Bool)?

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

    func rebuildZones() {
        zones = ScreenGeometry.allHotZones()
        insideZoneIndex = nil
        for (i, z) in zones.enumerated() {
            log.notice("zone[\(i)] rect=\(String(describing: z.rect), privacy: .public) notch=\(z.hasNotch) screen=\(z.screen.localizedName, privacy: .public)")
        }
        NotificationCenter.default.post(name: .hotZonesDidChange, object: nil)
    }

    private func evaluate(_ point: NSPoint) {
        let hitIndex = zones.firstIndex { $0.rect.contains(point) }

        // ★ 성능 가드: 초당 수백 회 호출됨. 상태 변화 없으면 즉시 반환.
        guard hitIndex != insideZoneIndex else { return }
        let previous = insideZoneIndex
        insideZoneIndex = hitIndex

        pendingWork?.cancel()

        if let idx = hitIndex {
            let zone = zones[idx]
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.insideZoneIndex == idx else { return }
                self.log.notice("ENTER zone[\(idx)] notch=\(zone.hasNotch)")
                self.onEnter?(zone)
            }
            pendingWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + dwellDelay, execute: work)
        } else if previous != nil {
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.insideZoneIndex == nil else { return }
                if self.isExitSuppressed?() == true { return }
                self.log.notice("EXIT")
                self.onExit?()
            }
            pendingWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + hideDelay, execute: work)
        }
    }
}

extension Notification.Name {
    static let hotZonesDidChange = Notification.Name("NotchHub.hotZonesDidChange")
}
