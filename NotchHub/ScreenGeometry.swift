import AppKit

/// 스크린별 핫존(트리거 영역) 계산.
/// 노치가 있으면 노치 영역 그대로, 없으면 상단 중앙의 가상 밴드.
enum ScreenGeometry {

    struct HotZone {
        let screen: NSScreen
        let rect: NSRect        // 전역 좌표 (원점: 주 화면 좌하단)
        let hasNotch: Bool
    }

    /// 노치 없는 화면용 가상 핫존 크기 (설정에서 조절)
    static var fallbackWidth: CGFloat = {
        let saved = UserDefaults.standard.double(forKey: "externalZoneWidth")
        return saved > 0 ? saved : 180
    }()
    static var fallbackHeight: CGFloat = 4

    static func hotZone(for screen: NSScreen) -> HotZone {
        let f = screen.frame
        let notchH = screen.safeAreaInsets.top

        if notchH > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            // 노치 전체가 아니라 "노치 안으로 커서를 끝까지 밀어 넣었을 때"만
            // 반응하도록 최상단의 얇은 스트립만 핫존으로 삼는다.
            // (경계 y == maxY 는 zoneContains가 포함 판정)
            let notchW = f.width - left.width - right.width
            let xInset: CGFloat = 8
            let edgeH: CGFloat = 2
            let rect = NSRect(x: f.minX + left.width + xInset,
                              y: f.maxY - edgeH,
                              width: notchW - xInset * 2,
                              height: edgeH)
            return HotZone(screen: screen, rect: rect, hasNotch: true)
        }

        let rect = NSRect(x: f.midX - fallbackWidth / 2,
                          y: f.maxY - fallbackHeight,
                          width: fallbackWidth,
                          height: fallbackHeight)
        return HotZone(screen: screen, rect: rect, hasNotch: false)
    }

    static func allHotZones() -> [HotZone] {
        NSScreen.screens.map { hotZone(for: $0) }
    }
}
