import AppKit

@main
@MainActor
struct SnowAirApp {
    static func main() async {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
