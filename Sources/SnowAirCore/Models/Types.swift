import Foundation
import CoreGraphics

// MARK: - 契约 01 · CaptureResult

public enum CaptureSource: String, Codable, Sendable {
    case region, fullScreen, longShot, recording
}

public struct CaptureResult {
    public var image: CGImage
    public var rect: CGRect
    public var scaleFactor: CGFloat
    public var source: CaptureSource
    public var createdAt: Date

    public init(image: CGImage, rect: CGRect, scaleFactor: CGFloat, source: CaptureSource, createdAt: Date) {
        self.image = image
        self.rect = rect
        self.scaleFactor = scaleFactor
        self.source = source
        self.createdAt = createdAt
    }
}

// MARK: - 契约 02 · AnnotationShape

public enum ShapeKind: String, Codable, Sendable, CaseIterable {
    case rectangle, ellipse, arrow, pen, text, number, mosaic

    public var displayName: String {
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

public struct RGBA: Codable, Sendable, Equatable {
    public var r: Double, g: Double, b: Double, a: Double

    public static let red    = RGBA(r: 1, g: 0.23, b: 0.23, a: 1)
    public static let yellow = RGBA(r: 1, g: 0.82, b: 0.20, a: 1)
    public static let green  = RGBA(r: 0.20, g: 0.78, b: 0.36, a: 1)
    public static let blue   = RGBA(r: 0.20, g: 0.52, b: 0.98, a: 1)
    public static let white  = RGBA(r: 1, g: 1, b: 1, a: 1)

    public init(r: Double, g: Double, b: Double, a: Double) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    public var cgColor: CGColor {
        CGColor(red: r, green: g, blue: b, alpha: a)
    }
}

public struct StrokeStyle: Codable, Sendable {
    public var color: RGBA
    public var width: CGFloat

    public static let `default` = StrokeStyle(color: .red, width: 3)

    public init(color: RGBA, width: CGFloat) {
        self.color = color
        self.width = width
    }
}

public struct AnnotationShape: Identifiable, Codable, Sendable {
    public let id: UUID
    public var kind: ShapeKind
    public var points: [CGPoint]
    public var style: StrokeStyle
    public var text: String?
    public var fontSize: CGFloat?
    public var number: Int?

    public init(
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
    public var isValid: Bool {
        switch kind {
        case .rectangle, .ellipse, .arrow, .mosaic: return points.count == 2
        case .pen:                                   return points.count >= 2
        case .text, .number:                         return points.count == 1
        }
    }

    public var boundingBox: CGRect? {
        guard !points.isEmpty else { return nil }
        let xs = points.map(\.x), ys = points.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

// MARK: - 契约 03 · AppConfig

public enum TrayAction: String, Codable, Sendable {
    case capture, openSettings, none
}

public struct HotkeyBinding: Codable, Sendable {
    public var keyCode: UInt32
    public var modifiers: UInt32
    public var display: String

    public static let `default` = HotkeyBinding(keyCode: 1, modifiers: 0, display: "⌥S")

    public init(keyCode: UInt32, modifiers: UInt32, display: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.display = display
    }
}

public struct AppConfig: Codable, Sendable {
    public var schemaVersion: Int = 1
    public var hotkey: HotkeyBinding = .default
    public var trayClickAction: TrayAction = .capture
    public var defaultTool: ShapeKind = .rectangle
    public var strokeColor: RGBA = .red
    public var strokeWidth: CGFloat = 3
    public var outputDirectory: String? = nil
    public var copyToClipboard: Bool = true
    public var language: String = "zh-Hans"

    public static let `default` = AppConfig()

    public init() {}

    public init(from decoder: Decoder) throws {
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

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, hotkey, trayClickAction, defaultTool
        case strokeColor, strokeWidth, outputDirectory, copyToClipboard, language
    }
}
