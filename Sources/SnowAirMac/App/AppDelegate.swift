import AppKit
import Combine
import SnowAirCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var hotkey: HotkeyManager?
    private var config: AppConfig = ConfigStore.load()
    private var permissionGranted = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 纯菜单栏应用：不显示 Dock 图标、不弹主窗口
        NSApp.setActivationPolicy(.accessory)

        // 自动化 UI 截图模式：self-hosted runner 设 SNOWAIR_UI_DEMO=annotation 后启动，
        // 直接打开带示例标注的标注窗口，跳过权限检查（合成图不需要屏幕录制权限）。
        if ProcessInfo.processInfo.environment["SNOWAIR_UI_DEMO"] == "annotation" {
            buildMenuBar()
            showDemoAnnotation()
            return
        }

        Task { @MainActor in
            permissionGranted = await PermissionChecker.hasScreenRecordingPermission()
            if !permissionGranted { PermissionChecker.openScreenRecordingSettings() }
        }

        buildMenuBar()
        installHotkey()
        HotkeyManager.setActive(hotkey)
    }

    private func showDemoAnnotation() {
        guard let result = DemoSupport.demoResult() else { return }
        AnnotationWindowController.show(
            result: result,
            config: config,
            initialShapes: DemoSupport.demoShapes()
        )
    }

    private func buildMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "scissors", accessibilityDescription: "SnowAir")
        item.button?.target = self
        item.button?.action = #selector(onTrayClick)

        let menu = NSMenu()
        menu.addItem(withTitle: "截图", action: #selector(startCapture), keyEquivalent: "").target = self
        menu.addItem(withTitle: "截取全屏", action: #selector(captureFullScreen), keyEquivalent: "").target = self
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "设置…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "退出", action: #selector(quit), keyEquivalent: "q").target = self
        item.menu = menu
        statusItem = item
    }

    private func installHotkey() {
        hotkey = HotkeyManager { [weak self] in
            Task { @MainActor in self?.startCapture() }
        }
        _ = hotkey?.register(
            keyCode: config.hotkey.keyCode,
            modifiers: config.hotkey.modifiers
        )
    }

    @objc private func onTrayClick() {
        switch config.trayClickAction {
        case .capture:      startCapture()
        case .openSettings: openSettings()
        case .none:         break
        }
    }

    @objc func startCapture() {
        guard permissionGranted else {
            PermissionChecker.openScreenRecordingSettings()
            return
        }
        Task { @MainActor in
            do {
                let full = try await ScreenCapturer.captureDisplay()
                RegionSelectorWindow.show(fullImage: full) { [weak self] rect in
                    guard let rect else { return }
                    self?.openAnnotation(full: full, rect: rect)
                }
            } catch {
                Self.showError(error.localizedDescription)
            }
        }
    }

    @objc private func captureFullScreen() {
        guard permissionGranted else { return }
        Task { @MainActor in
            do {
                let full = try await ScreenCapturer.captureDisplay()
                let result = CaptureResult(
                    image: full,
                    rect: .zero,
                    scaleFactor: 1,
                    source: .fullScreen,
                    createdAt: Date()
                )
                CaptureCoordinator.export(result, shapes: [])
            } catch {
                Self.showError(error.localizedDescription)
            }
        }
    }

    private func openAnnotation(full: CGImage, rect: CGRect) {
        let scale = NSScreen.main?.backingScaleFactor ?? 1
        guard let cropped = ScreenCapturer.crop(full: full, rect: rect, scale: scale) else { return }
        let result = CaptureResult(
            image: cropped, rect: rect, scaleFactor: scale,
            source: CaptureSource.region, createdAt: Date()
        )
        AnnotationWindowController.show(result: result, config: config)
    }

    @objc private func openSettings() {
        SettingsWindowController.show(config: config)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    static func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "SnowAir"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
