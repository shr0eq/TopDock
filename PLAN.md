# NotchHub — 프로젝트 진행 계획

> macOS 노치 / 화면 상단 중앙 hover 로 폴더·앱에 즉시 접근하는 개인용 런처
> (Folder Hub 클론 + 외장 디스플레이 지원 확장)

- 작성일: 2026-08-19
- 프로젝트 코드명: **NotchHub** (변경 가능)
- 위치: `~/Desktop/Claude Code/Folder hub/`

---

## 0. 결론 먼저 — 구현 가능한가?

**가능하다. 전부 공개 API로 구현 가능하며, 사설(private) 프레임워크가 필요 없다.**

| 요구사항 | 가능 여부 | 근거 |
|---|---|---|
| 노치 위치·크기 알아내기 | ✅ | `NSScreen.safeAreaInsets` / `auxiliaryTopLeft(Right)Area` (공개 API) |
| 노치에 마우스 갖다 대면 반응 | ✅ | `NSEvent.addGlobal/LocalMonitorForEvents(.mouseMoved)` — **마우스는 접근성 권한 불필요** |
| 노치 위를 덮는 패널 띄우기 | ✅ | borderless `NSPanel` + 윈도우 레벨 `.screenSaver`(메뉴바보다 위) |
| **외장 모니터 상단 중앙 동일 동작** | ✅ | 노치 없는 스크린은 `safeAreaInsets.top == 0` → 상단 중앙 가상 핫존으로 폴백 |
| 지정한 폴더 목록 표시 | ✅ | `FileManager` + 보안 스코프 북마크(샌드박스 시) |
| 폴더/앱 실행·탐색 | ✅ | `NSWorkspace.open(_:)`, `NSWorkspace.icon(forFile:)` |
| Finder로 드래그 앤 드롭 | ✅ | `NSItemProvider` / `NSFilePromiseProvider` |
| 전역 단축키 트리거 | ✅ | `NSEvent` 글로벌 모니터 또는 Carbon `RegisterEventHotKey` |

### ⚠️ 단 하나의 실질적 블로커: **개발 환경**

현재 이 맥에는 **Xcode가 설치되어 있지 않다.**

```
xcode-select -p  →  /Library/Developer/CommandLineTools
macOS SDK        →  11.3        (매우 오래됨)
Swift            →  5.4         (2021년 버전)
현재 OS          →  macOS 26.5.1
```

`safeAreaInsets`(macOS 12+), 최신 SwiftUI, `MenuBarExtra`(macOS 13+) 등을 쓰려면
**최소 macOS 14 SDK 이상**이 필요하다. → **1단계는 Xcode 설치**다.

---

## 1. 목표와 범위

### 1.1 만들 것 (v1.0 범위)
1. 메뉴바에 상주하는 백그라운드 앱 (Dock 아이콘 없음, `LSUIElement`)
2. **트리거**
   - 노치가 있는 내장 디스플레이 → 노치 영역 hover
   - 노치가 없는 외장 디스플레이 → 화면 **상단 중앙** hover
   - 전역 단축키 (예: `⌥Space`) 로도 호출
3. **패널 UI**
   - 등록해 둔 폴더/앱 목록을 아이콘 그리드 또는 리스트로 표시 (Dock 유사)
   - 폴더 클릭 → 내부 파일 목록으로 **인플레이스 탐색** (뒤로 가기 지원)
   - 앱 클릭 → 앱 실행
   - 더블클릭 → Finder에서 열기 / 기본 앱으로 열기
4. 커서가 패널 밖으로 나가면 자동으로 숨김 + **핀(pin) 고정** 토글
5. 설정 창: 폴더/앱 추가·삭제·순서 변경, 트리거 감도, 단축키, 실행 시 자동 시작

### 1.2 v1 이후로 미룰 것
- 파일 드래그 앤 드롭 (송신/수신 양방향)
- Quick Look 미리보기
- Workspace(프로필) 다중 전환
- 파일 복사/붙여넣기/삭제 등 Finder 수준 파일 조작
- AirDrop / 공유 시트 연동
- 검색 필터

### 1.3 만들지 않을 것
- App Store 배포 / 유료화 (개인용). → **샌드박스 비활성**로 개발이 훨씬 단순해진다.

---

## 2. 기술 스택 결정

| 항목 | 선택 | 이유 |
|---|---|---|
| 언어 | Swift 5.9+ | 표준 |
| UI | SwiftUI + AppKit 브릿지 | 뷰는 SwiftUI, 창 제어는 AppKit(NSPanel)이 필수 |
| 최소 지원 | **macOS 14.0** | 현재 OS가 26.x이므로 하위 호환 부담 없음. API 선택지 최대화 |
| 앱 타입 | `LSUIElement = YES` 메뉴바 앱 | Dock 미표시 |
| 샌드박스 | **비활성** (개인 빌드) | 임의 폴더 접근 자유. MAS 배포 시에만 보안 스코프 북마크 도입 |
| 상태 저장 | `UserDefaults` + JSON (`Codable`) | 항목 수가 적음 |
| 의존성 | 없음 (순수 Apple 프레임워크) | 유지보수 최소화 |
| 빌드 | Xcode 프로젝트 | 앱 번들·코드사인 필요 → SwiftPM 단독은 부적합 |

---

## 3. 아키텍처

```
NotchHubApp (@main, NSApplicationDelegateAdaptor)
│
├── AppDelegate
│   ├── MenuBarController        · NSStatusItem, 종료/설정 메뉴
│   ├── HotZoneMonitor           ★ 핵심 1 — 마우스 감시 + 핫존 판정
│   ├── PanelController          ★ 핵심 2 — NSPanel 생성/표시/숨김/애니메이션
│   └── HotKeyManager            · 전역 단축키
│
├── Model
│   ├── HubItem                  · {id, url, displayName, kind(.folder/.app/.file), iconCache}
│   ├── HubStore (ObservableObject) · 항목 CRUD, 순서, 영속화
│   └── ScreenGeometry           ★ 핵심 3 — 스크린별 노치/상단중앙 핫존 계산
│
└── View (SwiftUI)
    ├── HubPanelView             · 루트. 브레드크럼 + 그리드
    ├── ItemGridView             · 아이콘 그리드
    ├── DirectoryBrowserView     · 폴더 진입 시 파일 목록
    └── SettingsView             · 환경설정
```

### 핵심 1 — HotZoneMonitor (마우스 감시)

```swift
// 글로벌 + 로컬 모니터를 반드시 쌍으로 설치한다.
// (글로벌 모니터는 자기 앱이 활성일 때 발화하지 않음)
globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { _ in
    self.evaluate(NSEvent.mouseLocation)
}
localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { e in
    self.evaluate(NSEvent.mouseLocation); return e
}
```

판정 로직:
1. `NSEvent.mouseLocation` (전역 좌표, 원점 좌하단) 획득
2. 그 점을 포함하는 `NSScreen`을 `NSScreen.screens`에서 찾음
3. 해당 스크린의 **핫존 사각형**과 교차하는지 검사
4. 교차 시작 → `dwellDelay`(기본 0.25s) 타이머 시작. 그 동안 계속 머무르면 패널 표시
   (스쳐 지나갈 때 오작동 방지 — 필수)
5. 이탈 → `hideDelay`(기본 0.4s) 후 숨김. 단 패널 위에 있으면 취소

**성능 주의**: `.mouseMoved`는 초당 수십~수백 회 발화한다.
→ 판정을 O(1)로 유지하고, 마지막 hover 상태와 동일하면 즉시 return 하는 가드를 둔다.

### 핵심 2 — 핫존 계산 (요구사항 4번의 핵심)

```swift
func hotZone(for screen: NSScreen) -> NSRect {
    let f = screen.frame
    let notchH = screen.safeAreaInsets.top

    if notchH > 0,
       let l = screen.auxiliaryTopLeftArea,
       let r = screen.auxiliaryTopRightArea {
        // ── 노치 있는 내장 디스플레이 ──
        let notchW = f.width - l.width - r.width
        return NSRect(x: f.minX + l.width,
                      y: f.maxY - notchH,
                      width: notchW,
                      height: notchH)
    } else {
        // ── 노치 없는 외장 디스플레이 → 상단 중앙 가상 핫존 ──
        let w: CGFloat = 180      // 설정에서 조절 가능
        let h: CGFloat = 4        // 화면 최상단 몇 px
        return NSRect(x: f.midX - w/2,
                      y: f.maxY - h,
                      width: w,
                      height: h)
    }
}
```

주의점:
- 스크린 구성이 바뀌면 다시 계산해야 한다 → `NSApplication.didChangeScreenParametersNotification` 구독
- 좌표계: `NSScreen.frame`은 전역 좌표(원점 = 주 화면 좌하단). 외장 모니터는 좌표가 음수일 수 있다
- 외장 모니터 핫존은 **높이 4px**로 얇게. 화면 맨 위 끝은 커서가 "걸리는" 지점이라 조준이 쉽다

### 핵심 3 — PanelController (패널)

```swift
let panel = NSPanel(contentRect: rect,
                    styleMask: [.borderless, .nonactivatingPanel],
                    backing: .buffered, defer: false)
panel.level = .screenSaver              // 메뉴바보다 위 → 노치 위를 덮을 수 있음
panel.isOpaque = false
panel.backgroundColor = .clear
panel.hasShadow = true
panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
panel.contentView = NSHostingView(rootView: HubPanelView().environmentObject(store))
```

- `.nonactivatingPanel` → 패널을 클릭해도 **앞의 앱이 포커스를 잃지 않는다** (중요)
- `.canJoinAllSpaces` + `.fullScreenAuxiliary` → 전체화면 앱 위에서도 뜬다
- 패널은 트리거된 **그 스크린의 핫존 바로 아래 중앙**에 배치
- 표시 애니메이션: 위에서 아래로 슬라이드 + 페이드 (`NSAnimationContext`, 0.18s)
- 패널 안에 커서가 있는 동안 숨기지 않도록 `NSTrackingArea` (`.mouseEnteredAndExited`, `.activeAlways`)

---

## 4. 개발 로드맵

각 마일스톤은 **독립적으로 실행 가능한 상태**로 끝난다.

### M0 — 환경 준비 (사용자 작업 필요)
- [x] Mac App Store에서 **Xcode 설치** — Xcode 26.6 / Swift 6.3.3 / SDK 26.5 확인 (2026-08-19)
- [x] `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`
- [x] `xcodebuild -version` / `swift --version` 으로 확인
- [ ] Xcode에서 개인 Apple ID 등록 (무료 개발자 계정으로 로컬 서명 가능)

> ⛔ 이 단계 전에는 컴파일 자체가 불가능하다.

### M1 — 뼈대 (반나절)
- [x] Xcode 프로젝트 생성: macOS App / SwiftUI / 최소 배포 14.0
- [x] `Info.plist`에 `LSUIElement = YES` (GENERATE_INFOPLIST_FILE + INFOPLIST_KEY 방식)
- [x] 메뉴바 `NSStatusItem` + "설정 / 종료" 메뉴
- [x] **검증**: 빌드 성공, /Applications 설치, background-only(true), 메뉴바 아이콘 스크린샷 확인 (2026-08-19)

### M2 — 핫존 감지 ★ 가장 위험한 단계, 먼저 검증
- [x] `ScreenGeometry.hotZone(for:)` 구현
- [x] `HotZoneMonitor` 구현 (글로벌+로컬 모니터, dwell/hide 타이머)
- [x] 디버그용: 핫존을 반투명 빨간 사각형으로 그려주는 오버레이 토글 (메뉴 "디버그: 핫존 표시")
- [x] **검증**: 노치 ENTER/EXIT 합성 이동으로 2사이클 확인, 빠른 스침 시 미발화 확인. ⏳ 외장 모니터는 연결 시 검증
- [x] **검증**: 마우스 난사 중 CPU 0.3%

### M3 — 패널 표시
- [x] `PanelController` — NSPanel 생성, 위치 계산, show/hide 애니메이션
- [x] 패널 자체 hover 추적 — 패널 프레임을 HotZoneMonitor의 확장 존으로 통합 (TrackingArea 불필요)
- [x] 핀 고정 토글
- [x] **검증**: 표시/유지/숨김/핀 합성 이벤트로 확인, 클릭·표시 중 frontmost 불변 확인. ⏳ 전체화면 앱 위 표시는 사용자 육안 확인 권장
- [x] **검증**: 글로벌 모니터는 읽기 전용 — 이벤트 소비 불가 구조로 보장

### M4 — 항목 관리 + 실행
- [x] `HubItem` / `HubStore` (Codable 영속화, 명시적 save — Combine sink는 시드 누락 버그로 폐기)
- [x] 아이콘 로딩 `NSWorkspace.shared.icon(forFile:)` + NSCache
- [x] `ItemGridView` — 아이콘 그리드 (LazyVGrid, hover 하이라이트, 빈 상태 UI)
- [x] 클릭 동작: 열기 + ⌘클릭 → Finder 표시 + 실행 후 패널 닫힘 (폴더 인패널 진입은 M5)
- [x] `SettingsView` — 폴더/앱 추가(`NSOpenPanel`), 삭제, 드래그 순서 변경
- [x] **검증**: seed→defaults 저장→재시작 loaded 로그 확인. Downloads 클릭→Finder 열림→패널 닫힘 확인. TCC(Downloads) 허용됨

### M5 — 폴더 탐색
- [x] `DirectoryBrowserView` — 하위 파일 목록, 브레드크럼 헤더, 뒤로/상위
- [x] `⌘+클릭` → Finder에서 표시 + 헤더의 "Finder에서 열기" 버튼
- [x] 숨김 파일 토글, 정렬(이름/수정일/크기, 폴더 우선) — @AppStorage 유지
- [x] **검증**: 2단계 심층 진입·뒤로 가기 확인. 나열은 백그라운드 Task + LazyVGrid (대용량 실사용 검증은 사용 중 관찰)

### M6 — 마감
- [ ] 전역 단축키 (`HotKeyManager`)
- [ ] 로그인 시 자동 실행 (`SMAppService.mainApp`)
- [ ] 다크/라이트 모드, 재질(`NSVisualEffectView` blur)
- [ ] 앱 아이콘
- [ ] 로컬 코드사인 + 배포용 `.app` 빌드
- [ ] **한/영 UI 토글** (선호 사항)
- [ ] "Made by Won-Young Choi" 크레딧 표기

### M7 — 이후 (선택)
드래그 앤 드롭 · Quick Look · Workspace 다중 프로필 · 검색

---

## 5. 리스크와 대응

| # | 리스크 | 영향 | 대응 |
|---|---|---|---|
| R1 | **Xcode 미설치 / 구형 툴체인** | 🔴 착수 불가 | M0에서 Xcode 설치. 가장 먼저 처리 |
| R2 | 마우스 스쳐 지날 때 패널이 튀어나옴 | 🟠 사용성 치명 | dwell delay(0.2~0.4s) 필수. 설정에서 조절 가능하게 |
| R3 | `.mouseMoved` 고빈도 발화로 CPU 낭비 | 🟠 | 판정 O(1) + 상태 변화 없으면 즉시 return. M2에서 계측 |
| R4 | 메뉴바 클릭 등 시스템 UI 방해 | 🟠 | 글로벌 모니터는 **읽기 전용**이라 이벤트를 막지 않음. 패널은 트리거 전엔 아예 없음 |
| R5 | 멀티 디스플레이 좌표 계산 오류 (음수 좌표, 서로 다른 배율) | 🟠 | 전역 좌표만 사용. `didChangeScreenParameters` 구독. 디버그 오버레이로 눈으로 검증 |
| R6 | 전체화면 앱 위에서 안 뜸 | 🟡 | `.canJoinAllSpaces` + `.fullScreenAuxiliary` + `.screenSaver` 레벨 |
| R7 | 노치 있는 화면에서 패널이 노치에 잘림 | 🟡 | 패널은 `safeAreaInsets.top` **아래**에 배치. 노치를 덮는 건 트리거 영역 시각화 뿐 |
| R8 | 나중에 App Store 배포를 원하게 됨 | 🟡 | 샌드박스 + 보안 스코프 북마크로 전환 필요. `HubStore`에 URL 저장 시 **북마크 데이터 필드를 미리 넣어 두면** 전환 비용이 작다 |
| R9 | 외장 모니터 상단 중앙이 Dock/다른 앱과 충돌 | 🟢 | 핫존 폭·높이·활성 여부를 스크린별로 설정에서 on/off |

---

## 6. 결정이 필요한 사항 (사용자 확인)

1. **앱 이름** — `NotchHub` / `TopDock` / 다른 이름?
2. **패널 UI 형태** — Dock 같은 가로 아이콘 줄 vs 세로 리스트 vs 격자 그리드?
3. **폴더 클릭 시 기본 동작** — 패널 안에서 탐색(권장) vs 바로 Finder로 열기?
4. **외장 모니터 핫존 위치** — 상단 중앙 고정 vs 스크린마다 위치 지정 가능?
5. **배포 계획** — 개인용만(샌드박스 off, 권장) vs 나중에 App Store 고려?

> 답이 없어도 위 권장값(굵게/권장 표기)으로 M1~M3까지는 그대로 진행 가능하다.

---

## 7. 다음 액션

| 순서 | 주체 | 할 일 |
|---|---|---|
| 1 | **사용자** | Mac App Store에서 Xcode 설치 → `xcode-select` 전환 |
| 2 | Claude | M1 프로젝트 뼈대 생성 |
| 3 | Claude | M2 핫존 감지 + 디버그 오버레이 (가장 위험한 부분 조기 검증) |
| 4 | 사용자 | 노치 + 외장 모니터에서 실제 hover 테스트 |
| 5 | Claude | M3 이후 진행 |

---

## 문서

- [`RESEARCH.md`](RESEARCH.md) — Folder Hub 원본 앱 분석, 유사 오픈소스, 출처
- [`TECH_NOTES.md`](TECH_NOTES.md) — 핵심 API 코드 스케치와 함정 모음
