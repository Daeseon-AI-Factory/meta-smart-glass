import Vision
import UIKit

enum OCRError: Error {
    case badImage
}

// 온디바이스 OCR (Apple Vision). 이미지는 글래스에 두고 텍스트만 백엔드로 — 프라이버시 우선.
// Data(Sendable)로 받아 nonisolated async로 main 밖에서 실행 (Swift 6 strict 안전).
func recognizeText(in imageData: Data) async throws -> String {
    guard let cgImage = UIImage(data: imageData)?.cgImage else {
        throw OCRError.badImage
    }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.recognitionLanguages = ["en-US"]

    try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])

    let lines = (request.results ?? [])
        .compactMap { $0.topCandidates(1).first?.string }
    return lines.joined(separator: "\n")
}
