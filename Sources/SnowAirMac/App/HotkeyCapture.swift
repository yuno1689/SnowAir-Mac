import AppKit
import Carbon.HIToolbox
import Combine
import Foundation
import SnowAirCore

/// 改键录制器：监听本地按键，把 NSEvent 转为 HotkeyBinding。
/// 要求至少一个修饰键，避免单键热键误触；检测到与系统常见快捷键冲突时给出提示。
@MainActor
final class HotkeyCapture: ObservableObject {
    @Published var isRecording = false
    @Published var captured: HotkeyBinding?
    @Published var conflictMessage = ""

    private var monitor: Any?

    func start() {
        stop()
        conflictMessage = ""
        captured = nil
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let mods = Self.carbonModifiers(from: flags)
            // 无修饰键的单键不作为全局热键（易误触）
            guard mods != 0 else {
                Task { @MainActor in self.conflictMessage = "请至少按住一个修饰键（⌥ / ⌘ / ⌃ / ⇧）" }
                return nil
            }
            let binding = HotkeyBinding(
                keyCode: UInt32(event.keyCode),
                modifiers: mods,
                display: Self.display(for: event, flags: flags)
            )
            Task { @MainActor in
                if Self.isKnownConflict(binding) {
                    self.conflictMessage = "该组合与常用系统快捷键冲突，请换一个"
                } else {
                    self.captured = binding
                    self.stop()
                }
            }
            return nil
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command)   { m |= UInt32(cmdKey) }
        if flags.contains(.option)    { m |= UInt32(optionKey) }
        if flags.contains(.control)   { m |= UInt32(controlKey) }
        if flags.contains(.shift)     { m |= UInt32(shiftKey) }
        return m
    }

    private static func display(for event: NSEvent, flags: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option)  { parts.append("⌥") }
        if flags.contains(.shift)   { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }
        let key = event.charactersIgnoringModifiers?.uppercased() ?? "键\(event.keyCode)"
        parts.append(key)
        return parts.joined()
    }

    /// 与系统高频快捷键冲突的组合（⌘Q 退出、⌘Space 聚焦等），仅做保守提示。
    private static func isKnownConflict(_ binding: HotkeyBinding) -> Bool {
        let cmd = UInt32(cmdKey)
        if binding.modifiers == cmd && binding.keyCode == UInt32(kVK_ANSI_Q) { return true }
        if binding.modifiers == cmd && binding.keyCode == UInt32(kVK_Space) { return true }
        return false
    }
}
