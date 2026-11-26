import CoreGraphics
import Foundation
import ScreenCaptureKit

enum PermissionChecker {
    /// 通过尝试捕获一帧判断是否已授权屏幕录制。
    /// 用户 Revocation 后需重启 App，系统不会动态刷新已缓存的授权状态。
    static func hasScreenRecordingPermission() async -> Bool {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            return !content.displays.isEmpty
        } catch {
            return false
        }
    }

    /// 引导用户到系统设置的具体页面。
    static func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }
}
