import SwiftUI
import AVFoundation

// Words(단어장) — Look에서 마주친 영어 단어가 쌓이는 곳. "Lens는 잊고, 우린 기억한다"의 첫 조각.
// 단어 탭 → 온디바이스 TTS로 발음 듣기(무료·오프라인). 최근 본 단어가 위로. 스와이프 삭제.
struct WordsView: View {
    @EnvironmentObject private var store: WordStore

    var body: some View {
        NavigationStack {
            Group {
                if store.words.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(store.words) { word in
                            WordRow(word: word)
                        }
                        .onDelete { store.remove(at: $0) }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Words · \(store.words.count)")
        }
        .tint(.green)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "book.closed")
                .font(.system(size: 40))
                .foregroundStyle(.green.opacity(0.6))
            Text("아직 단어가 없어요")
                .font(.headline)
            Text("Look 탭에서 사물을 찍으면\n여기에 영어 단어가 쌓여요.")
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

// 단어 한 줄 — 탭하면 발음. 여러 번 본 단어는 횟수 표시(자주 보는 게 더 익숙해짐).
private struct WordRow: View {
    let word: SavedWord

    var body: some View {
        Button {
            WordSpeaker.shared.speak(word.english)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(.green)
                Text(word.english)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                if word.seenCount > 1 {
                    Text("\(word.seenCount)×")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// 온디바이스 TTS(AVSpeechSynthesizer) — 영어 단어 발음. 무료·오프라인. 싱글톤(재생성 시 끊김 방지).
@MainActor
final class WordSpeaker {
    static let shared = WordSpeaker()
    private let synth = AVSpeechSynthesizer()

    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.45   // 학습용이라 약간 느리게
        synth.stopSpeaking(at: .immediate)
        synth.speak(utterance)
    }
}
