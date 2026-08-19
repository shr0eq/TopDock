# 조사 결과 — Folder Hub 및 노치 앱 생태계

작성일: 2026-08-19

---

## 1. Folder Hub (원본 앱) 분석

- Mac App Store: `Folder Hub - File browser` (ID 6473019059), 개발자 志远 杨
- 요구 사양: **macOS 13.0 이상**, 앱 크기 약 14.7 MB
- 가격: 무료 기본 + 구독($0.99/월, $7.99/년) 또는 평생 구매($19.99, 할인가 $14.99)
- 지원 언어: 영어, 중국어 간체

### 핵심 동작
> "마우스를 화면 상단 가장자리(맥북의 경우 노치 영역)로 옮기면 패널이 떠오르고,
> 커서가 벗어나면 사라진다. 핀 고정 시 항상 표시."

한 줄 요약: **노치 아래에 숨어 있는 "떠 있는 Finder"(floating Finder)**.

### 기능 목록 (App Store 기재 기준)
| 분류 | 기능 |
|---|---|
| 트리거 | 상단 가장자리 hover / 노치 hover / 단축키(hotkey) |
| 작업 공간 | Workspace 개념 — 자주 쓰는 폴더 묶음을 등록·전환 (Desktop, Downloads, 프로젝트 폴더 등) |
| 파일 조작 | 드래그 앤 드롭, 더블클릭 열기, 우클릭 정렬, 복사/붙여넣기 |
| 탐색 | 폴더 진입·이동(jump), 미리보기(preview), 공유(share) |
| 통합 | Show in Finder, Open with 특정 앱, Cmd+클릭 → Finder, Control+클릭 → AirDrop |
| 창 | 다른 창 위에 부유(float), 핀 고정, 전체화면 모드에서 창 선택 |
| 디스플레이 | **멀티 모니터 지원** |

> 참고: 사용자 요구사항 4번(외장 디스플레이 상단 중앙 hover)은 원본 앱도
> "화면 상단 가장자리" 트리거 + 멀티 모니터 지원으로 이미 커버하는 영역이다.
> 즉 노치 전용이 아니라 **"각 스크린의 상단 밴드"를 핫존으로 잡는 설계**가 정석.

---

## 2. 참고할 만한 오픈소스 / 유사 앱

| 프로젝트 | 성격 | 참고 포인트 |
|---|---|---|
| **boring.notch (TheBoringNotch)** | 오픈소스, SwiftUI | 노치 확장 패널의 표준 구현. NSPanel + NSHostingView, `.screenSaver` 윈도우 레벨, hitTest 좌표 처리 |
| **NotchDrop** | 오픈소스 (MIT) | 노치 파일 셸프(file shelf). 드래그 앤 드롭 처리 방식 참고 |
| **mew-notch** | 오픈소스 | 노치 HUD 계열 |
| **notchify** | 오픈소스 SwiftUI | borderless floating NSPanel로 아일랜드 호스팅, 클립보드/파일 셸프 |
| **NotchNook** (상용) | — | UX 벤치마크 |

### 오픈소스에서 반복적으로 확인되는 구현 패턴
1. SwiftUI만으로는 저수준 윈도우 제어가 부족 → **`NSHostingView`를 `NSPanel`에 직접 담아** 수동 관리
2. 윈도우 레벨을 `.screenSaver` 등 **메뉴바보다 높은 레벨**로 올려 노치 위를 덮음
3. 패널의 "보이지 않는 영역"은 **hitTest에서 nil 반환**시켜 클릭이 아래로 통과하게 함

---

## 3. 노치/화면 상단 관련 공식 API

Apple이 노치 영역 판별용으로 제공하는 `NSScreen` API:

| API | 의미 |
|---|---|
| `screen.safeAreaInsets.top` | 노치에 가려지지 않는 안전 영역까지의 거리. **0이면 노치 없음** (또는 노치를 숨기는 전체화면 스페이스) |
| `screen.auxiliaryTopLeftArea` | 노치 왼쪽의 가려지지 않은 영역 (`NSRect?`) |
| `screen.auxiliaryTopRightArea` | 노치 오른쪽의 가려지지 않은 영역 (`NSRect?`) |

노치 폭 계산:
```
notchWidth = screen.frame.width - auxiliaryTopLeftArea.width - auxiliaryTopRightArea.width
notchHeight = screen.safeAreaInsets.top   // 16" 기준 약 38pt
```

세 값 모두 **노치 없는 외장 모니터에서는 0 / nil** → 이 경우 "화면 상단 중앙"으로 폴백하면
요구사항 4번이 자연스럽게 해결된다.

---

## 4. 마우스 hover 감지 관련 확인 사항

- `NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved])` 로 앱 외부의 마우스 이동을 감시 가능
- **중요**: 접근성(Accessibility) 권한은 **키 이벤트 감시에만** 요구된다.
  마우스 이동 감시는 샌드박스 앱에서도 별도 권한 없이 동작한다 → 권한 허들이 낮다
- 글로벌 모니터는 이벤트를 **수정하거나 전달을 막을 수 없다** (읽기 전용) → 메뉴바 클릭을 방해하지 않음
- 글로벌 모니터는 **자기 앱이 활성일 때는 발화하지 않음** → `addLocalMonitorForEvents`와 **쌍으로** 설치해야 함

---

## 출처

- [Folder Hub - File browser (Mac App Store)](https://apps.apple.com/us/app/folder-hub-file-browser/id6473019059?mt=12)
- [Folder Hub — BetaList](https://betalist.com/startups/folder-hub)
- [Folder Hub — Product Hunt](https://www.producthunt.com/products/folder-hub)
- [Folder Hub — 개발자 소개 (MacRumors Forums)](https://forums.macrumors.com/threads/folder-hub-i-made-a-file-access-tool-tailored-for-the-notch-on-your-mac.2414856/)
- [NSScreen.auxiliaryTopLeftArea — Apple Developer Documentation](https://developer.apple.com/documentation/appkit/nsscreen/auxiliarytopleftarea-uglc)
- [NSScreen.safeAreaInsets — Apple Developer Documentation](https://developer.apple.com/documentation/appkit/nsscreen/safeareainsets)
- [Avoiding the notch — ifnotnil.com](https://ifnotnil.com/t/avoiding-the-notch/2133)
- [Monitoring Events — Apple Developer Library](https://developer.apple.com/library/mac/documentation/cocoa/conceptual/eventoverview/MonitoringEvents/MonitoringEvents.html)
- [Why does NSEvent.addGlobalMonitorForEvents still work in a Sandboxed macOS app — Apple Developer Forums](https://developer.apple.com/forums/thread/811443)
- [Reclaiming the Notch: How I Built a Native macOS Utility in SwiftUI — Medium](https://medium.com/@srishtayal/reclaiming-the-notch-how-i-built-a-native-macos-utility-in-swiftui-04de80137e5f)
- [notchify — GitHub](https://github.com/fr0sty1122/notchify)
- [mew-notch — GitHub](https://github.com/monuk7735/mew-notch)
- [TheBoringNotch](https://theboring.name/)
