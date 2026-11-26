import AppKit
import SnowAirCore
import SwiftUI

/// 标注阶段：无边框窗口承载 SwiftUI 画布 + 悬浮工具栏。
final class AnnotationWindowController: NSWindowController {
    // 用 private designated init(window:) + static make，避开与
    // required init?(coder:) 的重载歧义（Swift 6 下自定义 init 会被误判）。
    private init(annotationWindow panel: NSPanel) {
        super.init(window: panel)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) 未实现") }

    private static var active: AnnotationWindowController?

    static func make(result: CaptureResult, config: AppConfig, onFinish: @escaping () -> Void) -> AnnotationWindowController {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: NSSize(width: result.image.width, height: result.image.height)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = NSWindow.Level.screenSaver
        panel.collectionBehavior = [NSWindow.CollectionBehavior.canJoinAllSpaces, NSWindow.CollectionBehavior.fullScreenAuxiliary]
        panel.backgroundColor = NSColor.clear

        let c = AnnotationWindowController(annotationWindow: panel)
        let root = AnnotationView(result: result, config: config, onFinish: onFinish)
        panel.contentView = NSHostingView(rootView: root)
        panel.center()
        return c
    }

    static func show(result: CaptureResult, config: AppConfig) {
        var controller: AnnotationWindowController?
        let c = make(result: result, config: config, onFinish: { [weak controller] in
            controller?.close()
        })
        controller = c
        active = c
        c.showWindow(NSApp)
        NSApp.activate(ignoringOtherApps: true)
    }

    override func close() {
        super.close()
        Self.active = nil
    }
}
