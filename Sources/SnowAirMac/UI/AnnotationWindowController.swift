import AppKit
import SnowAirCore
import SwiftUI

/// 标注阶段：无边框窗口承载 SwiftUI 画布 + 悬浮工具栏。
final class AnnotationWindowController: NSWindowController {
    private let result: CaptureResult
    private let config: AppConfig

    init(result: CaptureResult, config: AppConfig) {
        self.result = result
        self.config = config

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: NSSize(width: result.image.width, height: result.image.height)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear

        super.init(window: panel)

        let root = AnnotationView(result: result, config: config, onFinish: { [weak self] in
            self?.close()
        })
        panel.contentView = NSHostingView(rootView: root)
        panel.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) 未实现") }

    // 强引用保活：窗口关闭时置 nil，避免控制器被释放
    private static var active: AnnotationWindowController?

    static func show(result: CaptureResult, config: AppConfig) {
        let c = AnnotationWindowController(result: result, config: config)
        active = c
        c.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    override func close() {
        super.close()
        Self.active = nil
    }
}
