import Carbon.HIToolbox
import AppKit

/// 전역 단축키 (기본 ⌥Space). Carbon RegisterEventHotKey는
/// NSEvent 글로벌 키 모니터와 달리 접근성 권한이 필요 없다.
final class HotKeyManager {

    var onHotKey: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    func register() {
        let hotKeyID = EventHotKeyID(signature: OSType(0x4E48_4842), id: 1)   // 'NHHB'

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { manager.onHotKey?() }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)

        RegisterEventHotKey(UInt32(kVK_Space),
                            UInt32(optionKey),
                            hotKeyID,
                            GetApplicationEventTarget(),
                            0,
                            &hotKeyRef)
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef); self.hotKeyRef = nil }
        if let handlerRef { RemoveEventHandler(handlerRef); self.handlerRef = nil }
    }
}
