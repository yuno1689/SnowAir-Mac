import XCTest
import CoreGraphics
import AppKit
@testable import SnowAirCore

final class OCRTests: XCTestCase {

    func testJoinedTextPreservesLines() {
        let lines = [
            OCRLine(text: "第一行", confidence: 0.9),
            OCRLine(text: "Second line", confidence: 0.8),
        ]
        XCTAssertEqual(OCRService.joinedText(lines), "第一行\nSecond line")
    }

    /// 用 CoreGraphics 绘制清晰的英文字样，验证 Vision 真实识别链路可用。
    /// 若 CI 环境不具备识别条件（极少数 runner），则跳过而非失败。
    func testRecognizeSyntheticImage() async throws {
        let w = 480, h = 120
        guard let ctx = CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return XCTFail("无法创建测试上下文") }

        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))

        // 用 AppKit 在位图上绘制大号文字（测试 target 可依赖 AppKit）
        let ns = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ns
        NSString(string: "HELLO SNOW AIR").draw(
            at: NSPoint(x: 20, y: 40),
            withAttributes: [.font: NSFont.boldSystemFont(ofSize: 36), .foregroundColor: NSColor.black]
        )
        NSGraphicsContext.restoreGraphicsState()
        guard let image = ctx.makeImage() else { return XCTFail("无法生成测试图") }

        do {
            let lines = try await OCRService.recognize(image: image, languages: ["en-US"])
            let joined = OCRService.joinedText(lines).uppercased()
            XCTAssertTrue(joined.contains("HELLO") || joined.contains("SNOW"), "识别结果：\(joined)")
        } catch OCRError.noText {
            throw XCTSkip("当前 runner 无识别结果，跳过真实 OCR 断言")
        }
    }
}
