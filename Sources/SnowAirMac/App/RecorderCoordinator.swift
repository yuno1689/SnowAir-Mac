import AppKit
import Foundation
import SnowAirCore

/// P1-04 录屏协调：负责输出路径、菜单栏状态指示、错误提示。
@MainActor
enum RecorderCoordinator {
    private static let recorder = ScreenRecorder()
    private static var statusItem: NSMenuItem?

    static var isRecording: Bool { recorder.lastOutputURL != nil }

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
