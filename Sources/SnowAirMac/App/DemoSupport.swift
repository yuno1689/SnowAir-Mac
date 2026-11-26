import AppKit
import CoreGraphics
import SnowAirCore

/// 仅供自动化 UI 截图使用（环境变量 SNOWAIR_UI_DEMO=annotation）。
/// 生成一张合成示例图与一组示例标注，让 self-hosted runner 无需人工操作、
/// 也无需屏幕录制权限，即可启动 App 并截到真实的标注界面。
enum DemoSupport {
    static func demoImage(width: Int = 1024, height: Int = 660) -> CGImage? {
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0, space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        let w = CGFloat(width), h = CGFloat(height)

        // 页面浅灰底
        ctx.setFillColor(CGColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

        // 顶部标题条
        ctx.setFillColor(CGColor(red: 0.11, green: 0.31, blue: 0.62, alpha: 1))
        ctx.fill(CGRect(x: 0, y: h - 76, width: w, height: 76))
        let dots: [(CGFloat, CGFloat, CGFloat)] = [(0.95, 0.35, 0.35), (0.95, 0.78, 0.28), (0.35, 0.78, 0.45)]
        for (i, c) in dots.enumerated() {
            ctx.setFillColor(CGColor(red: c.0, green: c.1, blue: c.2, alpha: 1))
            ctx.fillEllipse(in: CGRect(x: 28 + CGFloat(i) * 30, y: h - 40, width: 16, height: 16))
        }

        // 模拟文本行
        ctx.setFillColor(CGColor(red: 0.80, green: 0.84, blue: 0.90, alpha: 1))
        var y = h - 130
        for row in 0..<5 {
            let len = w * (row == 0 ? 0.62 : 0.40 + CGFloat(row) * 0.07)
            ctx.fill(CGRect(x: 60, y: y, width: len, height: 14))
            y -= 34
        }

        // 主图区
        ctx.setFillColor(CGColor(red: 0.86, green: 0.92, blue: 0.98, alpha: 1))
        ctx.fill(CGRect(x: 60, y: 250, width: 420, height: 180))
        ctx.setFillColor(CGColor(red: 0.98, green: 0.78, blue: 0.45, alpha: 1))
        ctx.fill(CGRect(x: 510, y: 250, width: 180, height: 180))
        ctx.setFillColor(CGColor(red: 0.45, green: 0.80, blue: 0.62, alpha: 1))
        ctx.fill(CGRect(x: 720, y: 250, width: 240, height: 180))

        // 底部按钮
        ctx.setFillColor(CGColor(red: 0.16, green: 0.48, blue: 0.92, alpha: 1))
        ctx.fill(CGRect(x: 60, y: 170, width: 160, height: 44))

        return ctx.makeImage()
    }

    static func demoResult() -> CaptureResult? {
        guard let image = demoImage() else { return nil }
        return CaptureResult(
            image: image,
            rect: .zero,
            scaleFactor: 1,
            source: .region,
            createdAt: Date()
        )
    }

    /// 预置 7 种图形，截图可直观看到渲染结果，而不只是工具栏。
    static func demoShapes() -> [AnnotationShape] {
        let red = StrokeStyle(color: .red, width: 3)
        let blue = StrokeStyle(color: .blue, width: 4)
        let green = StrokeStyle(color: .green, width: 3)
        let yellow = StrokeStyle(color: .yellow, width: 3)
        return [
            AnnotationShape(kind: .rectangle, points: [CGPoint(x: 52, y: 242), CGPoint(x: 488, y: 442)], style: red),
            AnnotationShape(kind: .ellipse, points: [CGPoint(x: 500, y: 242), CGPoint(x: 700, y: 442)], style: green),
            AnnotationShape(kind: .arrow, points: [CGPoint(x: 620, y: 120), CGPoint(x: 300, y: 200)], style: blue),
            AnnotationShape(kind: .pen, points: [CGPoint(x: 730, y: 470), CGPoint(x: 780, y: 500), CGPoint(x: 840, y: 470), CGPoint(x: 900, y: 505)], style: yellow),
            AnnotationShape(kind: .text, points: [CGPoint(x: 62, y: 470)], style: red, text: "SnowAir P0 标注", fontSize: 22),
            AnnotationShape(kind: .number, points: [CGPoint(x: 560, y: 300)], style: blue, number: 1),
            AnnotationShape(kind: .mosaic, points: [CGPoint(x: 725, y: 260), CGPoint(x: 950, y: 420)], style: .default),
        ]
    }
}
