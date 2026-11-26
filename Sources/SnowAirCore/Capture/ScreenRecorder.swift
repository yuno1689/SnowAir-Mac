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

/// P1-04 录屏核心：ScreenCaptureKit SCStream + AVAssetWriter 输出 MP4（视频 + 系统音频）。
/// 音频采集失败时降级为纯视频，不影响录制主流程。
@MainActor
public final class ScreenRecorder: NSObject, SCStreamDelegate, SCStreamOutput {

    private var stream: SCStream?
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var queue: DispatchQueue?
    private var outputURL: URL?
    private var frameTime: CMTime = .zero
    private var audioStartTime: CMTime = .invalid
    private var startTime: CMTime = .invalid
    private var isRecording = false

    public private(set) var lastOutputURL: URL?
    public private(set) var isRecordingIndicator: Bool = false
    /// 是否成功采集到系统音频（供 UI 提示）
    public private(set) var audioCaptured = false

    /// 开始录制。
    /// - Parameters:
    ///   - rect: 显示器物理像素区域；nil 为全屏
    ///   - fps: 帧率
    ///   - includeAudio: 是否采集系统音频，默认 true
    public func start(
        display: SCDisplay? = nil,
        rect: CGRect? = nil,
        fps: Int = 30,
        includeAudio: Bool = true,
        outputURL: URL
    ) async throws {
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
        config.capturesAudio = includeAudio
        config.sampleRate = 48000
        config.channelCount = 2

        let newWriter: AVAssetWriter
        do {
            newWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        } catch {
            throw RecorderError.setupFailed(error.localizedDescription)
        }

        // 视频输入
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: config.width,
            AVVideoHeightKey: config.height
        ]
        let vInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        vInput.expectsMediaDataInRealTime = true
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: vInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: config.width,
                kCVPixelBufferHeightKey as String: config.height
            ]
        )
        guard newWriter.canAdd(vInput) else { throw RecorderError.setupFailed("无法添加视频输入") }
        newWriter.add(vInput)

        // 音频输入（AAC 编码）；创建失败则降级为纯视频
        var aInput: AVAssetWriterInput?
        if includeAudio {
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 48000,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 128000
            ]
            let candidate = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            candidate.expectsMediaDataInRealTime = true
            if newWriter.canAdd(candidate) {
                newWriter.add(candidate)
                aInput = candidate
            }
        }

        let q = DispatchQueue(label: "com.snowair.screenrecorder", qos: .userInitiated)
        let newStream = SCStream(filter: filter, configuration: config, delegate: self)
        do {
            try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: q)
            if aInput != nil {
                // 音频 output 添加失败不致命，降级为纯视频
                try? newStream.addStreamOutput(self, type: .audio, sampleHandlerQueue: q)
            }
            guard newWriter.startWriting() else { throw RecorderError.setupFailed("写入器启动失败") }
        } catch {
            throw RecorderError.setupFailed(error.localizedDescription)
        }

        self.stream = newStream
        self.writer = newWriter
        self.videoInput = vInput
        self.audioInput = aInput
        self.adaptor = adaptor
        self.queue = q
        self.outputURL = outputURL
        self.frameTime = .zero
        self.startTime = .invalid
        self.audioStartTime = .invalid
        self.audioCaptured = false
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
        guard isRecording, let stream, let writer, let vInput = videoInput else { return }
        isRecording = false
        try await stream.stopCapture()
        vInput.markAsFinished()
        audioInput?.markAsFinished()
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
        guard CMSampleBufferIsValid(sampleBuffer) else { return }
        switch type {
        case .screen:
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
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
        case .audio:
            let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            Task { @MainActor [weak self] in
                guard let self, self.isRecording,
                      let input = self.audioInput, input.isReadyForMoreMediaData,
                      let writer = self.writer, writer.status == .writing else { return }
                if self.audioStartTime == .invalid { self.audioStartTime = pts }
                let relative = CMTimeSubtract(pts, self.audioStartTime)
                if input.append(sampleBuffer) {
                    self.audioCaptured = true
                }
                _ = relative
            }
        @unknown default:
            break
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
        audioInput = nil
        adaptor = nil
        queue = nil
    }
}
