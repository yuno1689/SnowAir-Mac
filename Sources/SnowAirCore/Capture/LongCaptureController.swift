import CoreGraphics
import Foundation

/// P1-02 长截图抓帧控制器（核心逻辑，可单测）。
/// 定时抓帧 + 触发滚动；App 层负责把滚动事件投递给目标窗口，本类不直接依赖 AppKit 事件 Tap。
/// 停止后由调用方把 frames 交给 LongCaptureStitcher 拼接。
@MainActor
public final class LongCaptureController {

    public enum State: Equatable {
        case idle, capturing, stopped
    }

    public private(set) var state: State = .idle
    public private(set) var frames: [CGImage] = []

    private var onFrame: (() async -> CGImage?)?
    private var onScroll: (() -> Void)?
    private var task: Task<Void, Never>?
    private let interval: TimeInterval
    private let overlapPixels: Int
    private let maxFrames: Int

    /// - Parameters:
    ///   - interval: 抓帧间隔（秒）
    ///   - overlapPixels: 相邻帧重叠像素，传给拼接器
    ///   - maxFrames: 安全上限，防止无限滚动
    public init(interval: TimeInterval = 0.35, overlapPixels: Int = 120, maxFrames: Int = 60) {
        self.interval = interval
        self.overlapPixels = overlapPixels
        self.maxFrames = maxFrames
    }

    /// 开始抓帧循环。
    /// - Parameters:
    ///   - capture: 抓帧闭包（App 层用 ScreenCapturer）
    ///   - scroll: 滚动闭包（App 层用 CGEvent 投递）
    public func start(
        capture: @escaping () async -> CGImage?,
        scroll: @escaping () -> Void
    ) {
        guard state == .idle else { return }
        frames = []
        onFrame = capture
        onScroll = scroll
        state = .capturing
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled, self.state == .capturing, self.frames.count < self.maxFrames {
                if let image = await self.onFrame?() {
                    self.frames.append(image)
                }
                self.onScroll?()
                try? await Task.sleep(nanoseconds: UInt64(self.interval * 1_000_000_000))
            }
            if self.state == .capturing { self.state = .stopped }
        }
    }

    public func stop() {
        state = .stopped
        task?.cancel()
        task = nil
    }

    /// 停止并拼接为长图。
    public func finish() throws -> CGImage {
        stop()
        return try LongCaptureStitcher.stitch(frames: frames, overlapPixels: overlapPixels)
    }
}
