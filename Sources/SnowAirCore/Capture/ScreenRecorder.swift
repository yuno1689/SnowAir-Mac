import AVFoundation
import CoreMedia
import Foundation
import ScreenCaptureKit

public enum RecorderError: Error, LocalizedError {
    case noDisplay
    case setupFailed(String)
    case permissionDenied

    public var errorDescription: String? {
        switch self {
        case .noDisplay:            return "未找到可录制的显示器"
        case .setupFailed(let s):   return "录制初始化失败：\(s)"
        case .permissionDenied:     return "缺少屏幕录制权限，请在系统设置中授权后重启应用"
        }
    }
}

/// P1-04 录屏核心：ScreenCaptureKit SCStream + AVAssetWriter 输出 MP4。
/// 只录制屏幕视频流（不含音频，本期范围）；停止后由调用方拿到输出 URL。
@MainActor
public final class ScreenRecorder: NSObject, SCStreamDelegate, SCStreamOutput {

    private var stream: SCStream?
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var queue: DispatchQueue?
    private var outputURL: URL?
    private var frameTime: CMTime = .zero
    private var startTime: CMTime = .zero
    private var isRecording = false

    public private(set) var lastOutputURL: URL?
    /// 供 App 层显示菜单状态（开始后置 true，停止后置 false）
    public private(set) var isRecordingIndicator: Bool = false

    /// 开始录制指定显示器区域。
    /// - Parameters:
    ///   - rect: 以显示器物理像素为单位的区域；nil 表示全屏
    ///   - fps: 帧率，默认 30
    ///   - outputURL: 输出 MP4 路径
    public func start(display: SCDisplay? = nil, rect: CGRect? = nil, fps: Int = 30, outputURL: URL) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let target = display ?? content.displays.first else { throw RecorderError.noDisplay }

        let filter = SCContentFilter(display: target, excludingWindows: [])
        let config = SCStreamConfiguration()
        let captureRect = rect ?? CGRect(x: 0, y: 0, width: CGFloat(target.width), height: CGFloat(target.height))
        config.sourceRect = captureRect
        config.width = Int(captureRect.width)
        config.height = Int(captureRect.height)
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = true

        let newWriter: AVAssetWriter
        do {
            newWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        } catch {
            throw RecorderError.setupFailed(error.localizedDescription)
        }

        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: config.width,
            AVVideoHeightKey: config.height
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = true
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: config.width,
                kCVPixelBufferHeightKey as String: config.height
            ]
        )
        guard newWriter.canAdd(input) else { throw RecorderError.setupFailed("无法添加视频输入") }
        newWriter.add(input)

        let q = DispatchQueue(label: "com.snowair.screenrecorder", qos: .userInitiated)
        let newStream = SCStream(filter: filter, configuration: config, delegate: self)
        do {
            try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: q)
            guard newWriter.startWriting() else { throw RecorderError.setupFailed("写入器启动失败") }
        } catch {
            throw RecorderError.setupFailed(error.localizedDescription)
        }

        self.stream = newStream
        self.writer = newWriter
        self.videoInput = input
        self.adaptor = adaptor
        self.queue = q
        self.outputURL = outputURL
        self.frameTime = .zero
        self.startTime = .invalid
        self.isRecording = true
        self.isRecordingIndicator = true

        do {
            try await newStream.startCapture()
        } catch {
            cleanup()
            throw RecorderError.setupFailed(error.localizedDescription)
        }
    }

    public func stop() async throws {
        guard isRecording, let stream, let writer, let input = videoInput else { return }
        isRecording = false
        try await stream.stopCapture()
        input.markAsFinished()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            writer.finishWriting { continuation.resume() }
        }
        lastOutputURL = outputURL
        isRecordingIndicator = false
        cleanup()
    }

    // MARK: - SCStreamOutput

    nonisolated public func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .screen,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              CMSampleBufferIsValid(sampleBuffer) else { return }

        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        Task { @MainActor [weak self] in
            guard let self, self.isRecording,
                  let adaptor = self.adaptor, let input = self.videoInput,
                  let writer = self.writer, writer.status == .writing else { return }
            if self.startTime == .invalid { self.startTime = pts }
            let relative = CMTimeSubtract(pts, self.startTime)
            guard relative >= self.frameTime else { return }
            self.frameTime = relative
            adaptor.append(pixelBuffer, withPresentationTime: relative)
            _ = input
        }
    }

    // MARK: - SCStreamDelegate

    nonisolated public func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.isRecording = false
            self?.isRecordingIndicator = false
            self?.cleanup()
        }
    }

    private func cleanup() {
        stream = nil
        writer = nil
        videoInput = nil
        adaptor = nil
        queue = nil
    }
}
