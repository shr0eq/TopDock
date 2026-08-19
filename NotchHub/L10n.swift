import Foundation

/// 초경량 한/영 토글. 문자열이 적어 String Catalog 대신 직접 관리.
enum L10n {
    static let languageKey = "appLanguage"       // "ko" | "en"

    static var isKorean: Bool {
        UserDefaults.standard.string(forKey: languageKey) ?? "ko" == "ko"
    }

    static func set(korean: Bool) {
        UserDefaults.standard.set(korean ? "ko" : "en", forKey: languageKey)
        NotificationCenter.default.post(name: .languageChanged, object: nil)
    }

    // 메뉴
    static var showPanel: String { isKorean ? "패널 열기" : "Show Panel" }
    static var settings: String { isKorean ? "설정…" : "Settings…" }
    static var debugHotZones: String { isKorean ? "디버그: 핫존 표시" : "Debug: Show Hot Zones" }
    static var about: String { isKorean ? "NotchHub 정보" : "About NotchHub" }
    static var quit: String { isKorean ? "종료" : "Quit" }

    // 패널
    static var pin: String { isKorean ? "핀 고정" : "Pin" }
    static var unpin: String { isKorean ? "핀 해제" : "Unpin" }
    static var back: String { isKorean ? "뒤로" : "Back" }
    static var emptyFolder: String { isKorean ? "비어 있음" : "Empty" }
    static var noItems: String { isKorean ? "등록된 항목이 없습니다" : "No items yet" }
    static var addInSettings: String { isKorean ? "설정에서 추가…" : "Add in Settings…" }
    static var sortAndHidden: String { isKorean ? "정렬·숨김 파일" : "Sort & hidden files" }
    static var sortLabel: String { isKorean ? "정렬" : "Sort" }
    static var sortName: String { isKorean ? "이름" : "Name" }
    static var sortDate: String { isKorean ? "수정일" : "Date Modified" }
    static var sortSize: String { isKorean ? "크기" : "Size" }
    static var showHiddenFiles: String { isKorean ? "숨김 파일 표시" : "Show Hidden Files" }
    static var open: String { isKorean ? "열기" : "Open" }
    static var revealInFinder: String { isKorean ? "Finder에서 열기" : "Reveal in Finder" }

    static var preview: String { isKorean ? "미리보기" : "Quick Look" }
    static var search: String { isKorean ? "검색" : "Search" }
    static var workspace: String { isKorean ? "워크스페이스" : "Workspace" }
    static var newWorkspace: String { isKorean ? "새 워크스페이스" : "New Workspace" }
    static var renameWorkspace: String { isKorean ? "이름 변경" : "Rename" }
    static var deleteWorkspace: String { isKorean ? "워크스페이스 삭제" : "Delete Workspace" }
    static var workspaceName: String { isKorean ? "워크스페이스 이름" : "Workspace name" }

    // 설정
    static var addHelp: String { isKorean ? "폴더·앱·파일 추가" : "Add folders, apps, files" }
    static var removeHelp: String { isKorean ? "선택 항목 제거" : "Remove selected" }
    static var addPrompt: String { isKorean ? "추가" : "Add" }
    static var addMessage: String { isKorean ? "패널에 등록할 폴더, 앱, 파일을 선택하세요" : "Choose folders, apps, or files to add" }
    static var dragToReorder: String { isKorean ? "드래그로 순서 변경" : "Drag to reorder" }
    static var launchAtLogin: String { isKorean ? "로그인 시 자동 실행" : "Launch at Login" }
    static var language: String { isKorean ? "언어" : "Language" }
    static var settingsTitle: String { isKorean ? "NotchHub 설정" : "NotchHub Settings" }
    static var hotKeyHint: String { isKorean ? "전역 단축키: ⌥Space" : "Global hotkey: ⌥Space" }
    static var externalZoneWidth: String { isKorean ? "외장 화면 핫존 너비" : "External display hot zone width" }
}

extension Notification.Name {
    static let languageChanged = Notification.Name("NotchHub.languageChanged")
}
