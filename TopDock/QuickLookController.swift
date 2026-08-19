import AppKit
import Quartz

/// 컨텍스트 메뉴의 "미리보기" — QLPreviewPanel 호스팅.
final class QuickLookController: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {

    static let shared = QuickLookController()
    private var url: URL?

    func show(_ url: URL) {
        self.url = url
        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.delegate = self
        NSApp.activate(ignoringOtherApps: true)     // QL 패널이 키를 받을 수 있게
        panel.makeKeyAndOrderFront(nil)
        panel.reloadData()
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { url == nil ? 0 : 1 }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        url as QLPreviewItem?
    }
}
