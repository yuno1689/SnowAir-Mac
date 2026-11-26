import AVFoundation
import CoreImage
import Foundation

/// 把 MP4 视频按采样间隔抽帧转 GIF（P1 GIF 导出桥梁）。
/// 降采样到 maxWidth 以内，避免 GIF 体积过大。
public struct VideoToGIFConverter {

    public static func convert(videoURL: URL, frameInterval: Double = 0.2, maxWidth: Int = 480) async throws -> Data {
        let asset = AVAsset(url: videoURL)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw GIFError.invalidVideo
        }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw GIFError.invalidVideo }
        reader.add(output)
        guard reader.startReading() else { throw GIFError.invalidVideo }

        let ciContext = CIContext(options: nil)
        var frames: [CGImage] = []
        var lastPTS: CMTime = .invalid

        while let sample = output.copyNextSampleBuffer() {
            let pts = CMSampleBufferGetPresentationTimeStamp(sample)
            if lastPTS != .invalid {
                let delta = CMTimeSubtract(pts, lastPTS)
                guard CMTimeGetSeconds(delta) >= frameInterval else { continue }
            }
            guard let buffer = CMSampleBufferGetImageBuffer(sample) else { continue }
            lastPTS = pts

            let ciImage = CIImage(cvPixelBuffer: buffer)
            let scale = min(1, CGFloat(maxWidth) / ciImage.extent.width)
            let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            guard let cg = ciContext.createCGImage(scaled, from: scaled.extent) else { continue }
            frames.append(cg)
        }
        guard !frames.isEmpty else { throw GIFError.noFrames }
        return try GIFEncoder.encode(frames: frames, frameInterval: frameInterval)
    }
}
