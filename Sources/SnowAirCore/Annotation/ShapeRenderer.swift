import CoreGraphics
import CoreText
import Foundation

/// 7 种标注图形的统一渲染器。
/// 坐标系：输入点均为图像像素坐标（左上原点），与契约 02 一致。
enum ShapeRenderer {

    /// - Parameter sourceImage: 原始位图，仅马赛克取样需要；画布预览可传 nil（此时跳过马赛克）
    static func render(_ shapes: [AnnotationShape], in context: CGContext, sourceImage: CGImage? = nil) {
        for shape in shapes where shape.isValid {
            switch shape.kind {
            case .rectangle: drawRectangle(shape, in: context)
            case .ellipse:   drawEllipse(shape, in: context)
            case .arrow:     drawArrow(shape, in: context)
            case .pen:       drawPen(shape, in: context)
            case .text:      drawText(shape, in: context)
            case .number:    drawNumber(shape, in: context)
            case .mosaic:    if let sourceImage { drawMosaic(shape, in: context, source: sourceImage) }
            }
        }
    }

    private static func drawRectangle(_ s: AnnotationShape, in ctx: CGContext) {
        let r = rect(from: s.points)
        ctx.setStrokeColor(s.style.color.cgColor)
        ctx.setLineWidth(s.style.width)
        ctx.stroke(r)
    }

    private static func drawEllipse(_ s: AnnotationShape, in ctx: CGContext) {
        let r = rect(from: s.points)
        ctx.setStrokeColor(s.style.color.cgColor)
        ctx.setLineWidth(s.style.width)
        ctx.strokeEllipse(in: r)
    }

    private static func drawArrow(_ s: AnnotationShape, in ctx: CGContext) {
        guard s.points.count == 2 else { return }
        let from = s.points[0], to = s.points[1]
        ctx.setStrokeColor(s.style.color.cgColor)
        ctx.setLineWidth(s.style.width)
        ctx.setLineCap(.round)

        ctx.move(to: from)
        ctx.addLine(to: to)
        ctx.strokePath()

        // 箭头三角形：沿方向反向偏转 ±26° 取两翼，长度随线宽缩放
        let dx = to.x - from.x, dy = to.y - from.y
        let angle = atan2(dy, dx)
        let head = max(12, s.style.width * 4)
        let spread: CGFloat = 26 * .pi / 180
        let wing1 = CGPoint(
            x: to.x - head * cos(angle - spread),
            y: to.y - head * sin(angle - spread)
        )
        let wing2 = CGPoint(
            x: to.x - head * cos(angle + spread),
            y: to.y - head * sin(angle + spread)
        )
        ctx.move(to: to)
        ctx.addLine(to: wing1)
        ctx.addLine(to: wing2)
        ctx.closePath()
        ctx.fillPath()
    }

    private static func drawPen(_ s: AnnotationShape, in ctx: CGContext) {
        guard s.points.count >= 2 else { return }
        ctx.setStrokeColor(s.style.color.cgColor)
        ctx.setLineWidth(s.style.width)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.move(to: s.points[0])
        for p in s.points.dropFirst() { ctx.addLine(to: p) }
        ctx.strokePath()
    }

    private static func drawText(_ s: AnnotationShape, in ctx: CGContext) {
        guard let point = s.points.first, let text = s.text, !text.isEmpty else { return }
        let size = s.fontSize ?? 18
        let font = CGFont("PingFangSC-Regular" as CFString) ?? CGFont("Helvetica" as CFString)
        ctx.setFont(font, size: size)
        ctx.setFillColor(s.style.color.cgColor)
        ctx.setAllowsAntialiasing(true)
        ctx.showText(at: point, string: text as CFString)
    }

    private static func drawNumber(_ s: AnnotationShape, in ctx: CGContext) {
        guard let center = s.points.first, let n = s.number else { return }
        let radius = max(11, s.style.width * 4)
        let circle = CGRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2
        )
        ctx.setFillColor(s.style.color.cgColor)
        ctx.fillEllipse(in: circle)

        let label = "\(n)" as CFString
        let fontSize = radius * 1.2
        ctx.setFont(CGFont("Helvetica-Bold" as CFString) ?? CGFont("Helvetica" as CFString), size: fontSize)
        ctx.setFillColor(RGBA.white.cgColor)

        // 用 CTLine 取实际宽度，令数字在圆内水平居中
        let attr: [CFAttributedStringKey: Any] = [
            kCTFontAttributeName: CTFontCreateWithName("Helvetica-Bold" as CFString, fontSize, nil)
        ]
        let attrStr = CFAttributedStringCreate(nil, label, attr as CFDictionary)!
        let line = CTLineCreateWithAttributedString(attrStr)
        let textW = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds).width
        ctx.showText(at: CGPoint(x: center.x - textW / 2, y: center.y - fontSize * 0.35), string: label)
    }

    /// 马赛克：从原始位图按区域取样 → 缩到极小 → 最近邻放大，真实像素化。
    /// 直接从 source 取样而非 ctx.makeImage()，避免上下文翻转/状态污染。
    /// region 为左上原点坐标（契约 02），CGImage 裁剪用同一坐标系。
    private static func drawMosaic(_ s: AnnotationShape, in ctx: CGContext, source: CGImage) {
        guard s.points.count == 2 else { return }
        let region = rect(from: s.points).integral
        guard region.width >= 4, region.height >= 4 else { return }
        guard let clipped = source.cropping(to: region) else { return }

        let block = max(4, s.style.width * 3)
        let smallW = max(1, Int(region.width / block))
        let smallH = max(1, Int(region.height / block))

        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let smallCtx = CGContext(
                data: nil, width: smallW, height: smallH,
                bitsPerComponent: 8, bytesPerRow: 0, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return }

        smallCtx.interpolationQuality = .medium
        smallCtx.draw(clipped, in: CGRect(x: 0, y: 0, width: smallW, height: smallH))
        guard let smallImage = smallCtx.makeImage() else { return }

        ctx.saveGState()
        ctx.interpolationQuality = .none
        ctx.draw(smallImage, in: region)
        ctx.restoreGState()
    }

    private static func rect(from points: [CGPoint]) -> CGRect {
        guard points.count >= 2 else { return .zero }
        let p1 = points[0], p2 = points[1]
        return CGRect(
            x: min(p1.x, p2.x), y: min(p1.y, p2.y),
            width: abs(p2.x - p1.x), height: abs(p2.y - p1.y)
        )
    }
}
