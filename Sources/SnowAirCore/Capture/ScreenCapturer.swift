import CoreGraphics
import Foundation
import ScreenCaptureKit

public enum CaptureError: Error, LocalizedError {
    case noDisplay
    case permissionDenied
    case captureFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noDisplay:            return "未找到可截图的显示器"
        case .permissionDenied:     return "缺少屏幕录制权限，请在系统设置中授权后重启应用"
        case .captureFailed(let s): return "截图失败：\(s)"
        }
    }
}

/// 屏幕截图封装。基于 ScreenCaptureKit 的 SCScreenshotManager（macOS 14.0+）。
/// 注意：captureImage 使用 SCStreamConfiguration 参数——SCScreenshotConfiguration 是 macOS 26+ 才有的，
/// 目标 macOS 14 不能用。这是核实 Apple 文档后的选型，不要改成 26+ 的新 API。
public struct ScreenCapturer {

    /// 截取指定显示器，返回物理像素 CGImage。
    public static func captureDisplay(_ display: SCDisplay? = nil) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let target = display ?? content.displays.first else { throw CaptureError.noDisplay }

        let filter = SCContentFilter(display: target, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = target.width
        config.height = target.height

        return try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) { image, error in
                if let error {
                    continuation.resume(throwing: CaptureError.captureFailed(error.localizedDescription))
                } else if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: CaptureError.captureFailed("返回空图像"))
                }
            }
        }
    }

    /// 从整屏图中按点坐标裁剪出选区。
    /// - Parameters:
    ///   - full: 整屏物理像素图
    ///   - rect: Cocoa 点坐标选区（左下原点）
    ///   - scale: 像素/点比例
    public static func crop(full: CGImage, rect: CGRect, scale: CGFloat) -> CGImage? {
        // CGImage 坐标系左上原点，Cocoa 点坐标左下原点，需翻转 Y
        let h = CGFloat(full.height)
        let px = CGRect(
            x: rect.minX * scale,
            y: h - rect.maxY * scale,
            width: rect.width * scale,
            height: rect.height * scale
        ).integral
        guard px.width > 0, px.height > 0 else { return nil }
        return full.cropping(to: px)
    }
}
