import AppKit
import Foundation
import SnowAirCore

/// 导出：剪贴板 + 文件写入。遵循契约 01 —— 写入的是合成后位图，不含标注元数据。
enum CaptureCoordinator {
    static func export(_ result: CaptureResult, shapes: [AnnotationShape], compositedImage: CGImage? = nil) {
        let image = compositedImage ?? ImageExporter.composite(image: result.image, shapes: shapes)
        guard let image, let data = ImageExporter.pngData(image) else { return }

        let config = AppConfig.load()
        if config.copyToClipboard {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setData(data, forType: .png)
        }
        writeToFile(data, config: config)
    }

    private static func writeToFile(_ data: Data, config: AppConfig) {
        let dir: URL
        if let custom = config.outputDirectory {
            dir = URL(fileURLWithPath: custom, isDirectory: true)
        } else {
            let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0]
            dir = pictures.appendingPathComponent("SnowAir", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let name = "SnowAir_\(formatter.string(from: Date())).png"
        try? data.write(to: dir.appendingPathComponent(name), options: .atomic)
    }
}
