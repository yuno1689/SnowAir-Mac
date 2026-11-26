import CoreGraphics
import Foundation

/// P1-02 长截图拼接核心：固定重叠像素法。
/// 相邻两帧滚动后，上一帧底部 overlapPixels 行与下一帧顶部重复，拼下一帧时裁掉其顶部重复区。
/// 该算法稳定、可单测；自动滚动/抓帧由 App 层驱动，对不支持自动滚动的窗口提供手动抓帧兜底。
public struct LongCaptureStitcher {

    public enum StitchError: Error, LocalizedError {
        case noFrames
        case sizeMismatch
        case overlapTooLarge

        public var errorDescription: String? {
            switch self {
            case .noFrames:         return "没有可拼接的截图帧"
            case .sizeMismatch:     return "各帧宽度不一致，无法拼接"
            case .overlapTooLarge:  return "重叠像素数不得大于等于帧高度"
            }
        }
    }

    /// 拼接多帧为单张长图。
    /// - Parameters:
    ///   - frames: 按时间顺序的截图帧（等宽）
    ///   - overlapPixels: 相邻帧重复的顶部像素行数，默认 0（直接纵向拼接）
    public static func stitch(frames: [CGImage], overlapPixels: Int = 0) throws -> CGImage {
        guard let first = frames.first else { throw StitchError.noFrames }
        let width = first.width
        guard frames.allSatisfy({ $0.width == width }) else { throw StitchError.sizeMismatch }

        let heights = frames.map(\.height)
        if overlapPixels > 0, heights.contains(where: { overlapPixels >= $0 }) {
            throw StitchError.overlapTooLarge
        }

        let effectiveHeights = heights.enumerated().map { index, h -> Int in
            index == 0 ? h : h - overlapPixels
        }
        let totalHeight = effectiveHeights.reduce(0, +)

        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                data: nil, width: width, height: totalHeight,
                bitsPerComponent: 8, bytesPerRow: 0, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { throw StitchError.noFrames }

        // CGContext 左下原点：从底向上依次放置各帧，保证时间顺序自上而下
        var y = totalHeight
        for (index, frame) in frames.enumerated() {
            let drawHeight = effectiveHeights[index]
            y -= drawHeight
            if index == 0 {
                ctx.draw(frame, in: CGRect(x: 0, y: y, width: width, height: drawHeight))
            } else {
                // 跳过顶部 overlapPixels 行（左上原点坐标系下的裁剪）
                let cropRect = CGRect(x: 0, y: overlapPixels, width: width, height: drawHeight)
                guard let cropped = frame.cropping(to: cropRect) else { continue }
                ctx.draw(cropped, in: CGRect(x: 0, y: y, width: width, height: drawHeight))
            }
        }
        guard let result = ctx.makeImage() else { throw StitchError.noFrames }
        return result
    }
}
