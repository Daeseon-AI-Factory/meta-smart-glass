import SwiftUI

// MARK: - Models (백엔드 /api/suggest 계약)

struct Suggestion: Decodable {
    let text: String
    let tone: String
}

struct SuggestResponse: Decodable {
    let suggestions: [Suggestion]
    let provider: String
    let model: String
    let latencyMs: Int
}

private struct SuggestErrorBody: Decodable {
    let error: String
    let detail: String?
}

enum BackendError: Error {
    case badURL
    case server(String)
}

// 백엔드는 로컬 Bun 서버. 글래스 도착 전 단계라 폰↔백엔드만 검증.
func fetchSuggestions(text: String) async throws -> SuggestResponse {
    guard let url = URL(string: "http://localhost:3001/api/suggest") else {
        throw BackendError.badURL
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(["text": text])

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse else {
        throw BackendError.server("no HTTP response")
    }
    guard http.statusCode == 200 else {
        let body = try? JSONDecoder().decode(SuggestErrorBody.self, from: data)
        throw BackendError.server(body?.detail ?? body?.error ?? "HTTP \(http.statusCode)")
    }
    return try JSONDecoder().decode(SuggestResponse.self, from: data)
}

// MARK: - View

enum RequestStatus: Equatable {
    case idle
    case loading
    case success(meta: String)
    case failure(String)
}

struct ContentView: View {
    @State private var inputText: String = ""
    @State private var suggestions: [Suggestion] = []
    @State private var status: RequestStatus = .idle

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                Text("English Coach")
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)

                inputRow
                statusLine
                resultsArea

                Spacer(minLength: 0)
            }
            .padding(20)
        }
    }

    private var inputRow: some View {
        HStack(spacing: 10) {
            TextField("What did they just say?", text: $inputText)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .tint(.green)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                .onSubmit { submit() }

            Button(action: submit) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(canSubmit ? .green : .gray)
            }
            .disabled(!canSubmit)
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        switch status {
        case .idle:
            EmptyView()
        case .loading:
            HStack(spacing: 8) {
                ProgressView().tint(.green)
                Text("thinking…")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.green.opacity(0.7))
            }
        case .success(let meta):
            Text(meta)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.green.opacity(0.6))
        case .failure(let message):
            Text(message)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.red.opacity(0.85))
                .lineLimit(3)
        }
    }

    private var resultsArea: some View {
        VStack(spacing: 12) {
            ForEach(Array(suggestions.enumerated()), id: \.offset) { _, suggestion in
                SuggestionCard(suggestion: suggestion)
            }
        }
    }

    private var canSubmit: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && status != .loading
    }

    private func submit() {
        guard canSubmit else { return }
        Task { await requestSuggestions() }
    }

    private func requestSuggestions() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        status = .loading
        suggestions = []
        do {
            let response = try await fetchSuggestions(text: text)
            suggestions = response.suggestions
            status = .success(meta: "\(response.provider) · \(response.model) · \(response.latencyMs)ms")
        } catch let BackendError.server(message) {
            status = .failure(message)
        } catch {
            status = .failure(error.localizedDescription)
        }
    }
}

// MARK: - Suggestion card (글래스 HUD 스타일)

struct SuggestionCard: View {
    let suggestion: Suggestion

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(toneLabel)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(toneColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 5).fill(toneColor.opacity(0.15)))

            Text(suggestion.text)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(toneColor.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private var toneColor: Color {
        switch suggestion.tone {
        case "professional": .cyan
        case "casual": .green
        case "safe": .orange
        default: .gray
        }
    }

    private var toneLabel: String { suggestion.tone.uppercased() }
}

#Preview {
    ContentView()
}
