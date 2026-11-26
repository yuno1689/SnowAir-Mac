import XCTest
import CoreGraphics
@testable import SnowAirCore

final class ContractTests: XCTestCase {

    func testShapeValidity() {
        let two = AnnotationShape(kind: .rectangle, points: [.zero, CGPoint(x: 10, y: 10)])
        XCTAssertTrue(two.isValid)

        let one = AnnotationShape(kind: .rectangle, points: [.zero])
        XCTAssertFalse(one.isValid, "矩形必须恰好 2 点")

        let pen = AnnotationShape(kind: .pen, points: [.zero, CGPoint(x: 1, y: 1)])
        XCTAssertTrue(pen.isValid)
        XCTAssertFalse(AnnotationShape(kind: .pen, points: [.zero]).isValid)
    }

    func testAllSevenKindsDecode() {
        let kinds = ["rectangle", "ellipse", "arrow", "pen", "text", "number", "mosaic"]
        for k in kinds {
            XCTAssertNotNil(ShapeKind(rawValue: k), "\(k) 应能解码")
        }
        XCTAssertEqual(ShapeKind.allCases.count, 7)
    }

    func testBoundingBox() {
        let s = AnnotationShape(
            kind: .arrow,
            points: [CGPoint(x: 20, y: 30), CGPoint(x: 5, y: 10)]
        )
        XCTAssertEqual(s.boundingBox, CGRect(x: 5, y: 10, width: 15, height: 20))
    }

    func testConfigDefaultsAndMigration() {
        let c = AppConfig.default
        XCTAssertEqual(c.schemaVersion, 1)
        XCTAssertEqual(c.hotkey.display, "⌥S")
        XCTAssertEqual(c.language, "zh-Hans")

        let json = #"{"schemaVersion":1,"language":"fr"}"#
        let decoded = try! JSONDecoder().decode(AppConfig.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(decoded.language, "zh-Hans", "非法语言应回落")
        XCTAssertEqual(decoded.defaultTool, .rectangle)
    }

    func testUndoStack() {
        var stack = UndoStack<[Int]>(limit: 3)
        stack.reset([])
        stack.record([1])
        stack.record([1, 2])
        XCTAssertTrue(stack.canUndo)
        XCTAssertEqual(stack.undo(), [1])
        XCTAssertEqual(stack.undo(), [])
        XCTAssertNil(stack.undo(), "栈底不应再撤销")
    }

    func testRenderAllShapesDoesNotCrash() {
        let w = 100, h = 100
        guard let ctx = CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return XCTFail("无法创建测试上下文") }

        let shapes: [AnnotationShape] = [
            .init(kind: .rectangle, points: [.zero, CGPoint(x: 50, y: 50)]),
            .init(kind: .ellipse, points: [.zero, CGPoint(x: 40, y: 40)]),
            .init(kind: .arrow, points: [.zero, CGPoint(x: 60, y: 60)]),
            .init(kind: .pen, points: [.zero, CGPoint(x: 5, y: 5), CGPoint(x: 10, y: 2)]),
            .init(kind: .text, points: [CGPoint(x: 5, y: 20)], text: "测试", fontSize: 14),
            .init(kind: .number, points: [CGPoint(x: 20, y: 20)], number: 1),
            .init(kind: .mosaic, points: [CGPoint(x: 60, y: 60), CGPoint(x: 90, y: 90)])
        ]
        ShapeRenderer.render(shapes, in: ctx)
        XCTAssertNotNil(ctx.makeImage())
    }
}
