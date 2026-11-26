import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum GIFError: Error, LocalizedError {
    case noFrames
    case destinationFailed
    case invalidVideo

    public var errorDescription: String? {
        switch self {
        case .noFrames:         return "没有可编码的帧"
        case .destinationFailed: return "GIF 编码器创建失败"
        case .invalidVideo:     return "视频文件无效或不含视频轨道"
        }
    }
}

/// GIF 编码（原生 ImageIO 方案）。
/// 规划阶段 R5 曾判断"无原生方案，先 MP4"，核实后 ImageIO 的 CGImageDestination 支持逐帧 GIF，
/// 故 P1 补齐 GIF 导出，与 MP4 并存。
public struct GIFEncoder {

    /// 把多帧位图编码为 GIF 数据。
    /// - Parameters:
    ///   - frames: 按时间顺序的帧
    ///   - frameInterval: 每帧停留秒数（GIF 时间精度为 1/100 秒）
    public static func encode(frames: [CGImage], frameInterval: Double = 0.1) throws -> Data {
        guard !frames.isEmpty else { throw GIFError.noFrames }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            data as CFMutableData, UTType.gif.identifier as CFString, frames.count, nil
        ) else { throw GIFError.destinationFailed }

        let interval = max(0.01, frameInterval)
        for frame in frames {
            let props: [CFString: Any] = [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFDelayTime: interval
                ]
            ]
            CGImageDestinationAddImage(dest, frame, props as CFDictionary)
        }
        guard CGImageDestinationFinalize(dest) else { throw GIFError.destinationFailed }
        return data as Data
    }

    /// 写入文件。
    @discardableResult
    public static func write(frames: [CGImage], frameInterval: Double = 0.1, to url: URL) throws -> URL {
        let data = try encode(frames: frames, frameInterval: frameInterval)
        try data.write(to: url, options: .atomic)
        return url
    }
}
