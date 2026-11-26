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
                ForEach(ShapeKind.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }

            HStack {
                Text("热键：\(config.hotkey.display)")
                Spacer()
                Text("默认 ⌥S，改键功能 P1 提供")
                    .font(.caption).foregroundStyle(.secondary)
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
        .frame(width: 460, height: 300)
    }
}
