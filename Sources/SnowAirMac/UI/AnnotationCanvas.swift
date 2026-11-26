import AppKit
import CoreGraphics
import SnowAirCore
import SwiftUI

/// 承载位图与标注绘制的 NSView 桥接。鼠标坐标转为图像像素坐标（左上原点）。
struct AnnotationCanvas: NSViewRepresentable {
    let image: CGImage
    let shapes: [AnnotationShape]
    let draft: AnnotationShape?
    let tool: ShapeKind
    let onStart: (CGPoint) -> Void
    let onMove: (CGPoint) -> Void
    let onEnd: (CGPoint) -> Void

    func makeNSView(context: Context) -> CanvasNSView {
        let v = CanvasNSView(image: image)
        v.onStart = onStart; v.onMove = onMove; v.onEnd = onEnd
        return v
    }

    func updateNSView(_ v: CanvasNSView, context: Context) {
        v.shapes = shapes
        v.draft = draft
        v.onStart = onStart; v.onMove = onMove; v.onEnd = onEnd
        v.needsDisplay = true
    }
}

final class CanvasNSView: NSView {
    let image: CGImage
    var shapes: [AnnotationShape] = []
    var draft: AnnotationShape?
    var onStart: ((CGPoint) -> Void)?
    var onMove: ((CGPoint) -> Void)?
    var onEnd: ((CGPoint) -> Void)?

    init(image: CGImage) {
        self.image = image
        super.init(frame: NSRect(origin: .zero, size: NSSize(width: image.width, height: image.height)))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) 未实现") }

    override var isFlipped: Bool { true } // 左上原点，匹配契约 02

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.draw(image, in: bounds)
        var all = shapes
        if let d = draft { all.append(d) }
        ShapeRenderer.render(all, in: ctx)
    }

    override func mouseDown(with event: NSEvent) { onStart?(point(event)) }
    override func mouseDragged(with event: NSEvent) { onMove?(point(event)) }
    override func mouseUp(with event: NSEvent) { onEnd?(point(event)) }

    private func point(_ e: NSEvent) -> CGPoint { convert(e.locationInWindow, from: nil) }
}
