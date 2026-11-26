import AppKit
import SwiftUI

@main
struct SnowAirMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 菜单栏应用无需窗口 Scene；Settings 由 NSWindowController 自行管理
        Settings { EmptyView() }
    }
}
