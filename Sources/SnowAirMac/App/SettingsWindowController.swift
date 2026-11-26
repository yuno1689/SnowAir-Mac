import AppKit
import SnowAirCore
import SwiftUI

final class SettingsWindowController: NSWindowController {
    // NSWindowController 的 designated initializer 是 init(window:)。
    // 自定义 init(config:) 与 required init?(coder:) 并存会触发 Swift 的
    // 初始化器重载歧义，故改用 private init(window:) + static make。
    private init(settingsWindow window: NSWindow) {
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) 未实现") }

    private static var active: SettingsWindowController?

    static func make(config: AppConfig) -> SettingsWindowController {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 480, height: 320)),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered, defer: false
        )
        window.title = "SnowAir 设置"
        window.center()
        let c = SettingsWindowController(settingsWindow: window)
        window.contentView = NSHostingView(rootView: SettingsView(config: config))
        return c
    }

    static func show(config: AppConfig) {
        let c = make(config: config)
        active = c
        c.showWindow(NSApp)
        NSApp.activate(ignoringOtherApps: true)
    }

    override func close() {
        super.close()
        Self.active = nil
    }
}

struct SettingsView: View {
    @State private var config: AppConfig
    @State private var saved = false
    @StateObject private var capture = HotkeyCapture()

    init(config: AppConfig) { _config = State(initialValue: config) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("功能设置").font(.headline)

            Picker("托盘单击", selection: $config.trayClickAction) {
                Text("截图").tag(TrayAction.capture)
                Text("打开设置").tag(TrayAction.openSettings)
                Text("无操作").tag(TrayAction.none)
            }

            Toggle("截图后复制到剪贴板", isOn: $config.copyToClipboard)

            Picker("默认工具", selection: $config.defaultTool) {
                ForEach(ShapeKind.allCases, id: \.self) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }

            HStack {
                Text("截图热键：\(config.hotkey.display)")
                Spacer()
                Button(capture.isRecording ? "请按键…" : "录制热键") {
                    if capture.isRecording { capture.stop() } else { capture.start() }
                }
                .buttonStyle(.bordered)
            }
            if !capture.conflictMessage.isEmpty {
                Text(capture.conflictMessage).font(.caption).foregroundStyle(.red)
            }

            Divider()
            Text("版权所有 © CM-idea · Apache-2.0").font(.caption).foregroundStyle(.secondary)

            HStack {
                Spacer()
                if saved { Text("已保存").font(.caption).foregroundStyle(.green) }
                Button("保存") {
                    ConfigStore.save(config)
                    saved = true
                }
            }
        }
        .padding(20)
        .frame(width: 460, height: 360)
        .onReceive(capture.$captured.compactMap { $0 }) { binding in
            config.hotkey = binding
            ConfigStore.save(config)
            NotificationCenter.default.post(name: .snowairHotkeyChanged, object: binding)
            saved = true
        }
    }
}

extension Notification.Name {
    static let snowairHotkeyChanged = Notification.Name("snowair.hotkey.changed")
}
