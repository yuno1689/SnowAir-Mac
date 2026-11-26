import XCTest
import CoreGraphics
import ImageIO
@testable import SnowAirCore

final class GIFTests: XCTestCase {

    private func solid(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGImage {
        let ctx = CGContext(
            data: nil, width: 20, height: 20, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.setFillColor(CGColor(red: r, green: g, blue: b, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        return ctx.makeImage()!
    }

    func testEncodeProducesValidGIF() throws {
        let data = try GIFEncoder.encode(frames: [solid(1,0,0), solid(0,1,0), solid(0,0,1)])
        XCTAssertGreaterThan(data.count, 20)
        let header = String(data: data.prefix(6), encoding: .ascii)
        XCTAssertTrue(header == "GIF89a" || header == "GIF87a", "GIF 文件头应为 GIF89a/87a，实际 \(header ?? "nil")")
    }

    func testEncodeRejectsEmptyFrames() {
        XCTAssertThrowsError(try GIFEncoder.encode(frames: []))
    }
}
