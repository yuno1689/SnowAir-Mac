import AppKit
import CoreGraphics
import Foundation

enum ImageExporter {

    /// 将标注叠加到原始截图，输出最终 PNG 位图。
    static func composite(image: CGImage, shapes: [AnnotationShape]) -> CGImage? {
        let w = image.width, h = image.height
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                data: nil, width: w, height: h,
                bitsPerComponent: 8, bytesPerRow: 0, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }

        // bitmap 上下文原点在左下（Core Graphics 默认），契约 02 的点坐标为左上原点。
        // 先翻转 Y 轴，使 ShapeRenderer 的所有绘制与契约坐标系一致。
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))

        ShapeRenderer.render(shapes, in: ctx, sourceImage: image)
        return ctx.makeImage()
    }

    static func pngData(_ image: CGImage) -> Data? {
        let bitmap = NSBitmapImageRep(cgImage: image)
        return bitmap.representation(using: .png, properties: [:])
    }
}
