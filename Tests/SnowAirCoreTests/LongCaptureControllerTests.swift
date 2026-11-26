import XCTest
import CoreGraphics
@testable import SnowAirCore

@MainActor
final class LongCaptureControllerTests: XCTestCase {

    private func solid() -> CGImage {
        let ctx = CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        return ctx.makeImage()!
    }

    func testStartStopAndFinish() async throws {
        let controller = LongCaptureController(interval: 0.01, overlapPixels: 0, maxFrames: 3)
        XCTAssertEqual(controller.state, .idle)
        var scrollCount = 0
        controller.start(capture: { self.solid() }, scroll: { scrollCount += 1 })
        try await Task.sleep(nanoseconds: 120_000_000)
        let result = try controller.finish()
        XCTAssertEqual(controller.state, .stopped)
        XCTAssertGreaterThanOrEqual(controller.frames.count, 1)
        XCTAssertGreaterThanOrEqual(scrollCount, 1)
        XCTAssertGreaterThan(result.height, 0)
    }
}
