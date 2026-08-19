# Folder hub (앱 이름: TopDock)

macOS 노치 / 화면 상단 중앙에 마우스를 갖다 대면 지정한 폴더·앱 목록이 떠오르는
개인용 퀵 런처.
> **개명 이력 (2026-08-20)**: 원래 이름 NotchHub는 기존 앱(notchhub.pro)과 충돌하여 **TopDock**으로 변경.
> 내부 식별자(번들 ID `com.wonyoungchoi.NotchHub`, Xcode 타깃/폴더명)는 설정·권한 보존을 위해 유지.
 상용 앱 **Folder Hub**의 핵심 기능을 직접 구현하고,
**노치 없는 외장 디스플레이에서도 상단 중앙 hover로 동작**하도록 확장한다.

## 현재 상태

✅ **M0~M7 완료, 일상 사용 중** — Release가 `/Applications/TopDock.app`에 설치됨 (2026-08-20).
백업본: `dist/TopDock-0.1.0.zip`

## 문서

| 문서 | 내용 |
|---|---|
| [PLAN.md](PLAN.md) | **메인 문서** — 구현 가능성 결론, 범위, 아키텍처, 마일스톤 M0~M7, 리스크 |
| [RESEARCH.md](RESEARCH.md) | Folder Hub 원본 앱 분석, 유사 오픈소스, 노치 API 조사, 출처 |
| [TECH_NOTES.md](TECH_NOTES.md) | 핵심 API 코드 스케치와 함정 모음 |

## 한눈에 보는 결론

- **전부 공개 API로 구현 가능.** 사설 프레임워크 불필요.
- 노치 위치: `NSScreen.safeAreaInsets` / `auxiliaryTopLeftArea` / `auxiliaryTopRightArea`
- 노치 없는 화면(`safeAreaInsets.top == 0`) → **상단 중앙 가상 핫존**으로 폴백 → 요구사항 해결
- 마우스 hover 감지: `NSEvent` 글로벌+로컬 모니터 — **접근성 권한 불필요**
- 패널: borderless `NSPanel` + `.nonactivatingPanel` + `.screenSaver` 레벨 + `NSHostingView`

## 재설치 방법

**A. 백업 zip에서 (가장 빠름)** — `dist/TopDock-0.1.0.zip`을 풀어 `/Applications`에 넣기:
```
unzip -o "dist/TopDock-0.1.0.zip" -d /Applications/
open /Applications/TopDock.app
```

**B. 소스에서 재빌드** (이 폴더 = git 저장소 전체가 소스):
```
xcodebuild -project NotchHub.xcodeproj -scheme NotchHub -configuration Release build
rm -rf /Applications/TopDock.app
cp -R ~/Library/Developer/Xcode/DerivedData/NotchHub-*/Build/Products/Release/TopDock.app /Applications/
open /Applications/TopDock.app
```

참고:
- 등록 항목·설정은 `~/Library/Preferences/com.wonyoungchoi.NotchHub.plist`에 있어 앱을 지워도 유지된다
- adhoc 서명이라 **재빌드 후에는 Desktop/Downloads 접근 권한(TCC)을 다시 물을 수 있음** → Allow
- **다른 맥**으로 zip을 옮기면 Gatekeeper가 차단 → 우클릭 → 열기 1회 (또는 `xattr -d com.apple.quarantine`)

## ⚠️ 착수 전 필요한 작업

이 맥에는 Xcode가 없고 Command Line Tools만 있으며, 그마저도 매우 오래되었다
(SDK 11.3 / Swift 5.4, 현재 OS는 macOS 26.5.1).

1. Mac App Store에서 **Xcode 설치**
2. 툴체인 전환:
   ```
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   ```
3. 확인: `xcodebuild -version` → Xcode 15 이상, `swift --version` → Swift 5.9 이상
