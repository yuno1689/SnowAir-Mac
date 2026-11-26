import CoreGraphics
import Foundation
import Vision

public enum OCRError: Error, LocalizedError {
    case noText
    case recognitionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noText:                       return "未在图片中识别到文字"
        case .recognitionFailed(let s):     return "文字识别失败：\(s)"
        }
    }
}

public struct OCRLine: Equatable, Sendable {
    public var text: String
    public var confidence: Float

    public init(text: String, confidence: Float) {
        self.text = text
        self.confidence = confidence
    }
}

/// 基于 Vision 的中英混排文字识别（P1-01）。
/// 核心逻辑放在 SnowAirCore，便于 XCTest 覆盖；不依赖 App 生命周期。
public struct OCRService {

    /// 对图片执行准确级文字识别，逐行返回结果。
    /// - Parameters:
    ///   - image: 输入位图
    ///   - languages: 识别语言，默认中英双语；Vision 使用 BCP-47 标签（zh-Hans / en-US）
    public static func recognize(
        image: CGImage,
        languages: [String] = ["zh-Hans", "en-US"]
    ) async throws -> [OCRLine] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = languages
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
                }
            }
        }

        let lines = (request.results ?? []).compactMap { observation -> OCRLine? in
            guard let candidate = observation.topCandidate(1).first else { return nil }
            return OCRLine(text: candidate.string, confidence: candidate.confidence)
        }
        guard !lines.isEmpty else { throw OCRError.noText }
        return lines
    }

    /// 把逐行结果拼成可复制的纯文本，保留换行与段落顺序。
    public static func joinedText(_ lines: [OCRLine]) -> String {
        lines.map(\.text).joined(separator: "\n")
    }
}
