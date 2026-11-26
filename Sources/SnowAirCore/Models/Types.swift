import Foundation
import CoreGraphics

// MARK: - 契约 01 · CaptureResult

enum CaptureSource: String, Codable, Sendable {
    case region, fullScreen, longShot, recording
}

struct CaptureResult {
    var image: CGImage
    var rect: CGRect
    var scaleFactor: CGFloat
    var source: CaptureSource
    var createdAt: Date
}

// MARK: - 契约 02 · AnnotationShape

enum ShapeKind: String, Codable, Sendable, CaseIterable {
    case rectangle, ellipse, arrow, pen, text, number, mosaic

    var displayName: String {
        switch self {
        case .rectangle: return "矩形"
        case .ellipse:   return "椭圆"
        case .arrow:     return "箭头"
        case .pen:       return "画笔"
        case .text:      return "文字"
        case .number:    return "序号"
        case .mosaic:    return "马赛克"
        }
    }
}

struct RGBA: Codable, Sendable, Equatable {
    var r: Double, g: Double, b: Double, a: Double

    static let red    = RGBA(r: 1, g: 0.23, b: 0.23, a: 1)
    static let yellow = RGBA(r: 1, g: 0.82, b: 0.20, a: 1)
    static let green  = RGBA(r: 0.20, g: 0.78, b: 0.36, a: 1)
    static let blue   = RGBA(r: 0.20, g: 0.52, b: 0.98, a: 1)
    static let white  = RGBA(r: 1, g: 1, b: 1, a: 1)

    var cgColor: CGColor {
        CGColor(red: r, green: g, blue: b, alpha: a)
    }
}

struct StrokeStyle: Codable {
    var color: RGBA
    var width: CGFloat

    static let `default` = StrokeStyle(color: .red, width: 3)
}

struct AnnotationShape: Identifiable, Codable {
    let id: UUID
    var kind: ShapeKind
    var points: [CGPoint]
    var style: StrokeStyle
    var text: String?
    var fontSize: CGFloat?
    var number: Int?

    init(
        id: UUID = UUID(),
        kind: ShapeKind,
        points: [CGPoint],
        style: StrokeStyle = .default,
        text: String? = nil,
        fontSize: CGFloat? = nil,
        number: Int? = nil
    ) {
        self.id = id
        self.kind = kind
        self.points = points
        self.style = style
        self.text = text
        self.fontSize = fontSize
        self.number = number
    }

    /// 契约 02 的不变量校验：渲染层遇到无效图形跳过
    var isValid: Bool {
        switch kind {
        case .rectangle, .ellipse, .arrow, .mosaic: return points.count == 2
        case .pen:                                   return points.count >= 2
        case .text, .number:                         return points.count == 1
        }
    }

    var boundingBox: CGRect? {
        guard !points.isEmpty else { return nil }
        let xs = points.map(\.x), ys = points.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

// MARK: - 契约 03 · AppConfig

enum TrayAction: String, Codable, Sendable {
    case capture, openSettings, none
}

struct HotkeyBinding: Codable {
    var keyCode: UInt32
    var modifiers: UInt32
    var display: String

    static let `default` = HotkeyBinding(keyCode: 1, modifiers: 0, display: "⌥S")
}

struct AppConfig: Codable {
    var schemaVersion: Int = 1
    var hotkey: HotkeyBinding = .default
    var trayClickAction: TrayAction = .capture
    var defaultTool: ShapeKind = .rectangle
    var strokeColor: RGBA = .red
    var strokeWidth: CGFloat = 3
    var outputDirectory: String? = nil
    var copyToClipboard: Bool = true
    var language: String = "zh-Hans"

    static let `default` = AppConfig()

    enum CodingKeys: String, CodingKey {
        case schemaVersion, hotkey, trayClickAction, defaultTool
        case strokeColor, strokeWidth, outputDirectory, copyToClipboard, language
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        hotkey = try c.decodeIfPresent(HotkeyBinding.self, forKey: .hotkey) ?? .default
        trayClickAction = try c.decodeIfPresent(TrayAction.self, forKey: .trayClickAction) ?? .capture
        defaultTool = try c.decodeIfPresent(ShapeKind.self, forKey: .defaultTool) ?? .rectangle
        strokeColor = try c.decodeIfPresent(RGBA.self, forKey: .strokeColor) ?? .red
        strokeWidth = try c.decodeIfPresent(CGFloat.self, forKey: .strokeWidth) ?? 3
        outputDirectory = try c.decodeIfPresent(String.self, forKey: .outputDirectory)
        copyToClipboard = try c.decodeIfPresent(Bool.self, forKey: .copyToClipboard) ?? true
        let lang = try c.decodeIfPresent(String.self, forKey: .language) ?? "zh-Hans"
        language = (lang == "en") ? "en" : "zh-Hans"
    }
}
