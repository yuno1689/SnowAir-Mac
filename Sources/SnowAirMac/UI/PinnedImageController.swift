import AppKit
import CoreGraphics

/// P1-03 贴图：无边框置顶浮窗承载截图，可拖拽、可缩放、点击关闭。
/// 用 NSPanel 而非 NSWindow，避免抢占焦点；level=.floating 跨桌面空间可见。
@MainActor
final class PinnedImageController: NSWindowController {
    private static var active: [PinnedImageController] = []
    private var scale: CGFloat = 1

    private init(panel: NSPanel) {
        super.init(window: panel)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) 未实现") }

    static func show(image: CGImage) {
        let w = CGFloat(image.width), h = CGFloat(image.height)
        let maxSide: CGFloat = 900
        let initialScale = min(1, maxSide / max(w, h))
        let size = NSSize(width: w * initialScale, height: h * initialScale)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.isOpaque = false
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.level = NSWindow.Level.floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.center()

        let c = PinnedImageController(panel: panel)
        let view = PinnedImageView(frame: NSRect(origin: .zero, size: size))
        view.image = NSImage(cgImage: image, size: size)
        view.imageScaling = .scaleProportionallyUpOrDown
        view.onScroll = { [weak c] delta in c?.zoom(factor: delta > 0 ? 1.1 : 0.9) }
        view.onClick = { [weak c] in c?.close() }
        panel.contentView = view

        c.scale = initialScale
        c.showWindow(nil)
        active.append(c)
    }

    private func zoom(factor: CGFloat) {
        guard let window else { return }
        let next = min(3, max(0.25, scale * factor))
        guard next != scale else { return }
        // 原始尺寸 = 当前显示尺寸 / 当前 scale；目标 = 原始尺寸 * 新 scale
        let base = NSSize(width: window.frame.width / scale, height: window.frame.height / scale)
        scale = next
        let target = NSSize(width: base.width * next, height: base.height * next)
        var frame = window.frame
        frame.size = target
        window.setFrame(frame, display: true, animate: true)
    }

    override func close() {
        super.close()
        Self.active.removeAll { $0 === self }
    }
}

/// 自定义图片视图：滚轮缩放、单击关闭，其余拖拽交给 window 的 isMovableByWindowBackground。
private final class PinnedImageView: NSImageView {
    var onScroll: ((CGFloat) -> Void)?
    var onClick: (() -> Void)?

    override func scrollWheel(with event: NSEvent) {
        onScroll?(event.scrollingDeltaY)
    }

    override func mouseUp(with event: NSEvent) {
        // 只有未发生拖拽时才视为点击关闭
        if event.clickCount == 1 { onClick?() }
    }
}
