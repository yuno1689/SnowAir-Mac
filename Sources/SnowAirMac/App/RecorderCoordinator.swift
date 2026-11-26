import AppKit
import Foundation
import SnowAirCore

/// P1-04 录屏协调：负责输出路径、菜单栏状态指示、错误提示。
@MainActor
enum RecorderCoordinator {
    private static let recorder = ScreenRecorder()
    private static var statusItem: NSMenuItem?

    static var isRecording: Bool { recorder.isRecordingIndicator }
    static var lastMovieURL: URL? { recorder.lastOutputURL }

    /// P1 GIF 导出：把最近一次录制的 MP4 抽帧转 GIF，写入同目录。
    static func exportLastAsGIF() {
        guard let movie = lastMovieURL else {
            AppDelegate.showError("请先完成一次录屏，再导出 GIF")
            return
        }
        Task { @MainActor in
            do {
                let data = try await VideoToGIFConverter.convert(videoURL: movie)
                let gifURL = movie.deletingPathExtension().appendingPathExtension("gif")
                try data.write(to: gifURL, options: .atomic)
                // 在 Finder 中选中导出的 GIF，用户可立即看到结果
                NSWorkspace.shared.activateFileViewerSelecting([gifURL])
            } catch {
                AppDelegate.showError(error.localizedDescription)
            }
        }
    }

    static func toggle(statusItem: NSMenuItem?) {
        Self.statusItem = statusItem
        if recorder.isRecordingIndicator {
            Task { @MainActor in
                do {
                    try await recorder.stop()
                    updateStatus(false)
                } catch {
                    AppDelegate.showError(error.localizedDescription)
                    updateStatus(false)
                }
            }
        } else {
            Task { @MainActor in
                do {
                    let url = defaultOutputURL()
                    try await recorder.start(outputURL: url)
                    updateStatus(true)
                } catch {
                    AppDelegate.showError(error.localizedDescription)
                    updateStatus(false)
                }
            }
        }
    }

    private static func updateStatus(_ recording: Bool) {
        statusItem?.title = recording ? "停止录屏" : "录屏"
    }

    private static func defaultOutputURL() -> URL {
        let dir: URL
        if let custom = ConfigStore.load().outputDirectory {
            dir = URL(fileURLWithPath: custom, isDirectory: true)
        } else {
            dir = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("SnowAir", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return dir.appendingPathComponent("SnowAir_\(formatter.string(from: Date())).mp4")
    }
}
