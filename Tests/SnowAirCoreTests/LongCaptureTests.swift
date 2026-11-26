import XCTest
import CoreGraphics
@testable import SnowAirCore

final class LongCaptureTests: XCTestCase {

    private func solidImage(width: Int, height: Int, r: CGFloat, g: CGFloat, b: CGFloat) -> CGImage {
        let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.setFillColor(CGColor(red: r, green: g, blue: b, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()!
    }

    func testStitchDirectConcat() throws {
        let a = solidImage(width: 10, height: 20, r: 1, g: 0, b: 0)
        let b = solidImage(width: 10, height: 20, r: 0, g: 1, b: 0)
        let result = try LongCaptureStitcher.stitch(frames: [a, b])
        XCTAssertEqual(result.width, 10)
        XCTAssertEqual(result.height, 40)
    }

    func testStitchWithOverlap() throws {
        let a = solidImage(width: 10, height: 30, r: 1, g: 0, b: 0)
        let b = solidImage(width: 10, height: 30, r: 0, g: 1, b: 0)
        let result = try LongCaptureStitcher.stitch(frames: [a, b], overlapPixels: 10)
        XCTAssertEqual(result.height, 50, "30 + (30-10) = 50")
    }

    func testStitchRejectsEmptyAndMismatch() {
        XCTAssertThrowsError(try LongCaptureStitcher.stitch(frames: []))
        let a = solidImage(width: 10, height: 20, r: 1, g: 0, b: 0)
        let b = solidImage(width: 12, height: 20, r: 0, g: 1, b: 0)
        XCTAssertThrowsError(try LongCaptureStitcher.stitch(frames: [a, b]))
        XCTAssertThrowsError(try LongCaptureStitcher.stitch(frames: [a], overlapPixels: 20))
    }
}
