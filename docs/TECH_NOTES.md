# 기술 노트 — 핵심 API 스케치와 함정

구현 시 바로 꺼내 쓸 수 있는 조각들. 모두 **공개 API**만 사용한다.

---

## 1. 스크린 기하 — 노치 유무 판별

```swift
import AppKit

enum ScreenGeometry {

    struct HotZone {
        let screen: NSScreen
        let rect: NSRect        // 전역 좌표
        let hasNotch: Bool
    }

    static func hotZone(for screen: NSScreen,
                        fallbackWidth: CGFloat = 180,
                        fallbackHeight: CGFloat = 4) -> HotZone {
        let f = screen.frame
        let notchH = screen.safeAreaInsets.top

        if notchH > 0,
           let left  = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            let notchW = f.width - left.width - right.width
            let rect = NSRect(x: f.minX + left.width,
                              y: f.maxY - notchH,
                              width: notchW,
                              height: notchH)
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
```

### 함정
- `safeAreaInsets`는 **macOS 12.0+**. `auxiliaryTopLeftArea`도 12.0+
- 앱이 **전체화면 스페이스**에 있으면 노치가 숨겨져 `safeAreaInsets.top == 0`이 될 수 있다.
  우리 앱은 전체화면 스페이스를 쓰지 않으므로 문제 없지만, 값이 0이라고 무조건
  "외장 모니터"로 단정하지 말 것 → `screen.localizedName` 또는 `NSScreen.main` 비교로 보조 판정
- 스크린 구성 변경 시 반드시 재계산:
  ```swift
  NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: nil, queue: .main) { _ in self.rebuildHotZones() }
  ```

---

## 2. 마우스 감시 — HotZoneMonitor

```swift
final class HotZoneMonitor {

    var onEnter: ((ScreenGeometry.HotZone) -> Void)?
    var onExit:  (() -> Void)?

    var dwellDelay: TimeInterval = 0.25
    var hideDelay:  TimeInterval = 0.40

    private var zones: [ScreenGeometry.HotZone] = []
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var currentZoneID: ObjectIdentifier?     // 마지막 상태 가드
    private var dwellWork: DispatchWorkItem?

    func start() {
        rebuildHotZones()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            self?.evaluate(NSEvent.mouseLocation)
        }
        // 글로벌 모니터는 자기 앱이 활성일 때 발화하지 않으므로 로컬도 필요
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] e in
            self?.evaluate(NSEvent.mouseLocation); return e
        }
    }

    func rebuildHotZones() { zones = ScreenGeometry.allHotZones() }

    private func evaluate(_ p: NSPoint) {
        let hit = zones.first { $0.rect.contains(p) }
        let hitID = hit.map { ObjectIdentifier($0.screen) }

        // ★ 성능 가드: 상태 변화가 없으면 즉시 반환 (초당 수백 회 호출됨)
        guard hitID != currentZoneID else { return }
        currentZoneID = hitID

        dwellWork?.cancel()
        guard let zone = hit else {
            let w = DispatchWorkItem { [weak self] in self?.onExit?() }
            dwellWork = w
            DispatchQueue.main.asyncAfter(deadline: .now() + hideDelay, execute: w)
            return
        }
        let w = DispatchWorkItem { [weak self] in self?.onEnter?(zone) }
        dwellWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + dwellDelay, execute: w)
    }

    func stop() {
        [globalMonitor, localMonitor].compactMap { $0 }.forEach(NSEvent.removeMonitor)
        globalMonitor = nil; localMonitor = nil
    }
}
```

### 함정
- **접근성 권한**: `.mouseMoved` 감시는 권한이 필요 없다. `.keyDown` 계열만 필요하다.
  → 전역 단축키를 `NSEvent` 글로벌 모니터로 구현하면 **접근성 권한이 생긴다.**
  권한을 피하려면 Carbon `RegisterEventHotKey` 를 쓸 것 (권한 불필요).
- 글로벌 모니터는 이벤트를 **소비하거나 수정할 수 없다** → 메뉴바 클릭을 막을 위험 자체가 없다
- `.mouseMoved` 외에 `.leftMouseDragged`, `.rightMouseDragged` 도 함께 매칭해야
  드래그 중 hover가 끊기지 않는다: `[.mouseMoved, .leftMouseDragged, .rightMouseDragged]`
- 커서가 화면 최상단에 "붙어" 있으면 이벤트가 더 이상 안 올 수 있다 → 진입 시점만 잡으면 되므로 무해

---

## 3. 패널 — NSPanel + SwiftUI

```swift
final class PanelController {
    private var panel: NSPanel?

    func show(at zone: ScreenGeometry.HotZone, store: HubStore) {
        let size = NSSize(width: 520, height: 260)
        let origin = NSPoint(x: zone.rect.midX - size.width / 2,
                             y: zone.screen.frame.maxY
                                - zone.screen.safeAreaInsets.top
                                - size.height)

        let p = panel ?? makePanel(store: store)
        p.setFrame(NSRect(origin: origin, size: size), display: false)
        p.alphaValue = 0
        p.orderFrontRegardless()                 // 앱을 활성화하지 않고 앞으로
        NSAnimationContext.runAnimationGroup {
            $0.duration = 0.18
            p.animator().alphaValue = 1
        }
        panel = p
    }

    private func makePanel(store: HubStore) -> NSPanel {
        let p = NSPanel(contentRect: .zero,
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.level = .screenSaver                    // 메뉴바/노치 위
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.isMovable = false
        p.hidesOnDeactivate = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        p.contentView = NSHostingView(rootView: HubPanelView().environmentObject(store))
        return p
    }

    func hide() {
        guard let p = panel else { return }
        NSAnimationContext.runAnimationGroup({
            $0.duration = 0.14
            p.animator().alphaValue = 0
        }, completionHandler: { p.orderOut(nil) })
    }
}
```

### 함정
- `.nonactivatingPanel` 없이는 패널을 클릭하는 순간 **앞 앱이 포커스를 잃는다**. 반드시 넣을 것
- `orderFront(nil)`이 아니라 **`orderFrontRegardless()`** — 앱이 비활성 상태여도 앞으로 나온다
- `NSPanel`에서 SwiftUI의 `TextField` 등 키 입력을 받으려면 `canBecomeKey`를 override 한
  서브클래스가 필요하다 (borderless 패널은 기본적으로 key window가 될 수 없다):
  ```swift
  final class KeyablePanel: NSPanel {
      override var canBecomeKey: Bool { true }
  }
  ```
- 배경 블러는 `NSVisualEffectView(material: .hudWindow, blendingMode: .behindWindow)`를
  `NSViewRepresentable`로 감싸 SwiftUI 배경에 깐다

---

## 4. 패널 hover 유지 (숨김 취소)

SwiftUI `.onHover`는 패널이 비활성 상태이면 신뢰하기 어렵다. AppKit 트래킹을 쓴다.

```swift
final class TrackingHostView: NSView {
    var onHoverChange: ((Bool) -> Void)?
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self))
    }
    override func mouseEntered(with e: NSEvent) { onHoverChange?(true) }
    override func mouseExited(with e: NSEvent)  { onHoverChange?(false) }
}
```

`.activeAlways`가 핵심 — 앱이 비활성이어도 트래킹이 동작한다.

---

## 5. 항목 실행 / 아이콘

```swift
// 앱 또는 폴더/파일 열기
NSWorkspace.shared.open(url)

// 특정 앱으로 열기
NSWorkspace.shared.open([fileURL],
                        withApplicationAt: appURL,
                        configuration: .init())

// Finder에서 선택된 상태로 표시 (⌘+클릭)
NSWorkspace.shared.activateFileViewerSelecting([url])

// 아이콘 (반드시 캐시할 것 — 매 렌더마다 호출하면 느려진다)
let icon = NSWorkspace.shared.icon(forFile: url.path)
icon.size = NSSize(width: 48, height: 48)
```

디렉터리 나열:
```swift
let items = try FileManager.default.contentsOfDirectory(
    at: dirURL,
    includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey],
    options: showHidden ? [] : [.skipsHiddenFiles])
```
> 대용량 폴더는 백그라운드 큐에서 나열하고 `LazyVGrid`로 렌더한다.

---

## 6. 로그인 시 자동 실행 (macOS 13+)

```swift
import ServiceManagement
try SMAppService.mainApp.register()      // 등록
try SMAppService.mainApp.unregister()    // 해제
SMAppService.mainApp.status              // .enabled / .notRegistered / ...
```

---

## 7. 전역 단축키 — 권한 없는 방식 (Carbon)

```swift
import Carbon.HIToolbox

var hotKeyRef: EventHotKeyRef?
let id = EventHotKeyID(signature: OSType(0x4E484842), id: 1)   // 'NHHB'
RegisterEventHotKey(UInt32(kVK_Space),
                    UInt32(optionKey),
                    id, GetApplicationEventTarget(), 0, &hotKeyRef)
```
`InstallEventHandler`로 `kEventHotKeyPressed`를 받는다.
`NSEvent` 글로벌 키 모니터와 달리 **접근성 권한이 필요 없다.**

---

## 8. Info.plist

| 키 | 값 | 이유 |
|---|---|---|
| `LSUIElement` | `YES` | Dock 아이콘 숨김, 메뉴바 전용 앱 |
| `LSMinimumSystemVersion` | `14.0` | API 선택지 확보 |
| `NSHumanReadableCopyright` | (크레딧) | — |

샌드박스를 켤 경우에만 추가로 필요:
- Entitlement `com.apple.security.files.user-selected.read-write`
- Entitlement `com.apple.security.files.bookmarks.app-scope`
- `NSOpenPanel`로 선택 → `url.bookmarkData(options: .withSecurityScope)` 저장 →
  사용 시 `startAccessingSecurityScopedResource()` / `stop...()` 쌍으로 감쌀 것

---

## 9. 디버그 오버레이 (M2 검증용)

핫존이 눈에 보이지 않으면 멀티 디스플레이 좌표 버그를 잡기 어렵다.
각 핫존 위치에 반투명 빨간 borderless 패널(`ignoresMouseEvents = true`)을 띄우는
토글을 만들어 두면 M2 검증이 몇 분 만에 끝난다. **강력 권장.**

```swift
overlay.ignoresMouseEvents = true      // 클릭이 그대로 통과
overlay.level = .screenSaver
overlay.backgroundColor = NSColor.systemRed.withAlphaComponent(0.3)
```
