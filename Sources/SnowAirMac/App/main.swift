import AppKit

// SPM 可执行入口：main.swift 内不能再用 @main（会与顶层代码冲突）。
// 菜单栏应用无 Dock 图标，由 Info.plist 的 LSUIElement 控制。
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
