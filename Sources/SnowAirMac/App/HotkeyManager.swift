import Carbon.HIToolbox
import Foundation

/// Carbon 全局热键封装。⌥S 对应 keyCode=1（ANSI S）、modifiers=optionKey。
final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let onTrigger: () -> Void

    init(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
    }

    deinit {
        unregister()
    }

    func register(keyCode: UInt32 = UInt32(kVK_ANSI_S), modifiers: UInt32 = UInt32(optionKey)) -> Bool {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x534E5752) // 'SNWR'
        hotKeyID.id = 1

        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, _ in
                // 回调在 C 函数指针中，通过 userData 拿不到 self；用全局转发解决
                HotkeyManager.dispatch()
                return noErr
            },
            1, &eventType, nil, &eventHandler
        )
        guard status == noErr else { return false }

        let registerStatus = RegisterEventHotKey(
            keyCode, modifiers, hotKeyID,
            GetApplicationEventTarget(), 0, &hotKeyRef
        )
        return registerStatus == noErr
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    /// 全局回调转发表——Carbon C 回调无法捕获 self，用弱引用单例桥接。
    private static weak var active: HotkeyManager?

    static func setActive(_ manager: HotkeyManager?) { active = manager }

    fileprivate static func dispatch() {
        active?.onTrigger()
    }
}
