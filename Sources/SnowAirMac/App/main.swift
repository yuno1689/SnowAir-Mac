import AppKit

// Swift 6 严格并发：NSApplicationDelegate 的初始化属 @MainActor，
// 而 main.swift 的顶层代码是非隔离上下文。main.swift 内不能用 @main
// （与顶层代码冲突），故显式进入主 actor 完成启动。
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
