import Foundation

// 로컬 Bun 백엔드 클라이언트. 글래스 도착 전이라 폰↔백엔드만.

enum BackendError: Error {
    case badURL
    case server(String)
}

struct Suggestion: Decodable, Sendable {
    let text: String
    let tone: String
}

struct SuggestResponse: Decodable, Sendable {
    let suggestions: [Suggestion]
    let provider: String
    let model: String
    let latencyMs: Int
}

struct TranslateResponse: Decodable, Sendable {
    let translation: String
    let provider: String
    let model: String
    let latencyMs: Int
}

private struct ErrorBody: Decodable {
    let error: String
    let detail: String?
}

enum Backend {
    static let baseURL = "http://localhost:3001"

    static func suggestions(text: String) async throws -> SuggestResponse {
        try await post("/api/suggest", ["text": text])
    }

    static func translation(text: String) async throws -> TranslateResponse {
        try await post("/api/translate", ["text": text])
    }

    private static func post<T: Decodable>(_ path: String, _ body: [String: String]) async throws -> T {
        guard let url = URL(string: baseURL + path) else { throw BackendError.badURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BackendError.server("no HTTP response")
        }
        guard http.statusCode == 200 else {
            let body = try? JSONDecoder().decode(ErrorBody.self, from: data)
            throw BackendError.server(body?.detail ?? body?.error ?? "HTTP \(http.statusCode)")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
