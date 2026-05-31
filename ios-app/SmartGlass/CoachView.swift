import SwiftUI

enum RequestStatus: Equatable {
    case idle
    case loading
    case success(meta: String)
    case failure(String)
}

// 영어 답변 제안: 상대 발언 입력 → /api/suggest → tone별 카드.
struct CoachView: View {
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
            let response = try await Backend.suggestions(text: text)
            suggestions = response.suggestions
            status = .success(meta: "\(response.provider) · \(response.model) · \(response.latencyMs)ms")
        } catch let BackendError.server(message) {
            status = .failure(message)
        } catch {
            status = .failure(error.localizedDescription)
        }
    }
}

struct SuggestionCard: View {
    let suggestion: Suggestion

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(suggestion.tone.uppercased())
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
}
