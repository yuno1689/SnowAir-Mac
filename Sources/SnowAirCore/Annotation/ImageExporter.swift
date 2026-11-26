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

        // 位图上下文中 draw 整图按左上原点对齐；契约 02 的点坐标同为左上原点，
        // 因此标注层无需翻转，与底图共用同一坐标系。
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))

        ShapeRenderer.render(shapes, in: ctx, sourceImage: image)
        return ctx.makeImage()
    }

    static func pngData(_ image: CGImage) -> Data? {
        let bitmap = NSBitmapImageRep(cgImage: image)
        return bitmap.representation(using: .png, properties: [:])
    }
}
