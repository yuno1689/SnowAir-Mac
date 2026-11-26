import AppKit
import CoreGraphics
import Foundation
import SnowAirCore

/// P1-02 长截图 App 层协调：抓帧用 ScreenCapturer，滚动用 CGEvent 投递。
/// 由于目标窗口由用户在前台决定，滚动事件发往当前事件源；真机需确认辅助功能权限。
@MainActor
enum LongCaptureCoordinator {
    private static var controller: LongCaptureController?

    static func start() {
        guard controller == nil else { return }
        let c = LongCaptureController(interval: 0.35, overlapPixels: 120, maxFrames: 60)
        controller = c
        c.start(
            capture: { try? await ScreenCapturer.captureDisplay() },
            scroll: { postScrollDown() }
        )
    }

    static func stopAndOpenAnnotation(config: AppConfig) {
        guard let c = controller else { return }
        do {
            let longImage = try c.finish()
            controller = nil
            let result = CaptureResult(
                image: longImage, rect: .zero, scaleFactor: 1,
                source: .longShot, createdAt: Date()
            )
            AnnotationWindowController.show(result: result, config: config)
        } catch {
            controller = nil
            AppDelegate.showError(error.localizedDescription)
        }
    }

    static var isCapturing: Bool { controller?.state == .capturing }

    /// 投递一次向下滚动事件。需要辅助功能权限；无权限时静默失败（手动兜底）。
    private static func postScrollDown() {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 1,
            wheel1: -120,
            wheel2: 0,
            wheel3: 0
        ) else { return }
        event.post(tap: .cghidEventTap)
    }
}
