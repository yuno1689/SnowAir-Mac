import Foundation
import SnowAirCore

/// 配置持久化。遵循契约 03：默认 ~/Library/Application Support/SnowAir/config.json；
/// App 同目录存在空 config.json 时切便携模式。
enum ConfigStore {
    private static var defaultURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("SnowAir", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("config.json")
    }

    private static var portableURL: URL? {
        let bundleDir = Bundle.main.bundleURL.deletingLastPathComponent()
        let marker = bundleDir.appendingPathComponent("config.json")
        return FileManager.default.fileExists(atPath: marker.path) ? marker : nil
    }

    static var currentURL: URL { portableURL ?? defaultURL }

    static func load() -> AppConfig {
        guard let data = try? Data(contentsOf: currentURL) else { return AppConfig.default }
        let decoded = try? JSONDecoder().decode(AppConfig.self, from: data)
        return decoded ?? AppConfig.default
    }

    static func save(_ config: AppConfig) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        try? data.write(to: currentURL, options: Data.WritingOptions.atomic)
    }
}
