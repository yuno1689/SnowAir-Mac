import AppKit
import CoreGraphics

/// 全屏无边框 overlay，用于拖拽框选区域。
/// 底图为静态整屏截图（物理像素），选区以 Cocoa 点坐标返回。
final class RegionSelectorWindow: NSWindow {
    private var backdrop: CGImage
    private var startPoint: NSPoint?
    private var currentRect: NSRect?
    private var onComplete: ((NSRect?) -> Void)?

    init(fullImage: CGImage, completion: @escaping (NSRect?) -> Void) {
        self.backdrop = fullImage
        self.onComplete = completion
        super.init(
            contentRect: NSScreen.main?.frame ?? .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        hasShadow = false
        level = .screenSaver
        backgroundColor = .clear
        ignoresMouseEvents = false
        contentView = RegionSelectorView(owner: self)
    }

    func pointDidDown(_ p: NSPoint) { startPoint = p; currentRect = nil }

    func pointDidDrag(_ p: NSPoint) {
        guard let s = startPoint else { return }
        currentRect = NSRect(
            x: min(s.x, p.x), y: min(s.y, p.y),
            width: abs(p.x - s.x), height: abs(p.y - s.y)
        )
        contentView?.needsDisplay = true
    }

    func pointDidUp(_ p: NSPoint) {
        defer { close() }
        guard let s = startPoint else { onComplete?(nil); return }
        let r = NSRect(x: min(s.x, p.x), y: min(s.y, p.y),
                       width: abs(p.x - s.x), height: abs(p.y - s.y))
        onComplete?(r.width > 4 && r.height > 4 ? r : nil)
    }

    func cancel() { onComplete?(nil); close() }

    func drawContent(_ ctx: CGContext, in view: NSView) {
        let bounds = view.bounds
        ctx.draw(backdrop, in: bounds)

        // 选区外压暗
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.45).cgColor)
        if let sel = currentRect {
            ctx.fill(bounds)
            ctx.clear(sel)
            ctx.draw(backdrop, in: bounds)
            // 重新压暗选区外（清晰展示选区内）
            ctx.setFillColor(NSColor.black.withAlphaComponent(0.45).cgColor)
            let outer = [
                NSRect(x: 0, y: 0, width: bounds.width, height: sel.minY),
                NSRect(x: 0, y: sel.maxY, width: bounds.width, height: bounds.height - sel.maxY),
                NSRect(x: 0, y: sel.minY, width: sel.minX, height: sel.height),
                NSRect(x: sel.maxX, y: sel.minY, width: bounds.width - sel.maxX, height: sel.height)
            ]
            ctx.fill(outer)
            ctx.setStrokeColor(NSColor.white.cgColor)
            ctx.setLineWidth(1)
            ctx.stroke(sel)
        } else {
            ctx.fill(bounds)
        }
    }

    static func show(fullImage: CGImage, completion: @escaping (NSRect?) -> Void) {
        let window = RegionSelectorWindow(fullImage: fullImage, completion: completion)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(window.contentView)
    }
}

private final class RegionSelectorView: NSView {
    private weak var owner: RegionSelectorWindow?

    init(owner: RegionSelectorWindow) {
        self.owner = owner
        super.init(frame: owner.frame)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) 未实现") }

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        owner?.drawContent(ctx, in: self)
    }

    override func mouseDown(with event: NSEvent) {
        owner?.pointDidDown(convert(event.locationInWindow, from: nil))
    }

    override func mouseDragged(with event: NSEvent) {
        owner?.pointDidDrag(convert(event.locationInWindow, from: nil))
    }

    override func mouseUp(with event: NSEvent) {
        owner?.pointDidUp(convert(event.locationInWindow, from: nil))
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { owner?.cancel() } // Esc
    }
}
