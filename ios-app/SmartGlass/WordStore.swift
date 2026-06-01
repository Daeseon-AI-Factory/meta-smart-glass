import Foundation

// 사용자가 마주쳐서 저장된 영어 단어 1개. Look 라벨링에서 누적됨. Codable로 JSON 파일에 영속.
struct SavedWord: Identifiable, Codable, Hashable {
    let id: UUID
    let english: String
    var korean: String        // 힌트용(없으면 빈 문자열). live엔 안 쓰지만 복습 힌트로 보관.
    let firstSeenAt: Date
    var lastSeenAt: Date
    var seenCount: Int

    init(english: String, korean: String, at date: Date) {
        self.id = UUID()
        self.english = english
        self.korean = korean
        self.firstSeenAt = date
        self.lastSeenAt = date
        self.seenCount = 1
    }
}

// 본 단어 저장소 — Documents/seen-words.json에 Codable로 영속. 같은 단어는 dedup + 카운트 증가.
// "Lens는 한 번 알려주고 잊지만, 우린 기억한다"의 첫 조각. 앱 꺼도 단어가 남음.
// MainActor 격리: words를 UI가 직접 구독. 파일 쓰기는 Data(Sendable)만 백그라운드로 넘겨 메인 안 막음.
@MainActor
final class WordStore: ObservableObject {
    @Published private(set) var words: [SavedWord] = []

    private let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("seen-words.json")
    }()

    init() { load() }

    // 영어 기준 dedup(소문자 비교). 있으면 카운트+시각 갱신, 없으면 새로 추가(최근 본 게 위로).
    private func upsert(english: String, korean: String, now: Date) {
        let cleaned = english.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        let key = cleaned.lowercased()
        if let i = words.firstIndex(where: { $0.english.lowercased() == key }) {
            words[i].seenCount += 1
            words[i].lastSeenAt = now
            if words[i].korean.isEmpty && !korean.isEmpty { words[i].korean = korean }
        } else {
            words.insert(SavedWord(english: cleaned, korean: korean, at: now), at: 0)
        }
    }

    func add(english: String, korean: String = "", now: Date = Date()) {
        upsert(english: english, korean: korean, now: now)
        save()
    }

    // Look 라벨링 결과 통째로 누적. 여러 개여도 파일 쓰기는 1번만.
    func addAll(_ objects: [LabeledObject], now: Date = Date()) {
        for o in objects { upsert(english: o.english, korean: o.korean, now: now) }
        save()
    }

    func remove(at offsets: IndexSet) {
        words.remove(atOffsets: offsets)
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([SavedWord].self, from: data) else { return }
        words = decoded
    }

    // 인코딩은 MainActor(작음), 쓰기는 Data만 detached로 → 메인 블로킹 회피. Data·URL 모두 Sendable.
    private func save() {
        guard let data = try? JSONEncoder().encode(words) else { return }
        let url = fileURL
        Task.detached { try? data.write(to: url, options: .atomic) }
    }
}
