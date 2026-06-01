import SwiftUI

@main
struct SmartGlassApp: App {
    // 본 단어 저장소 — 앱 전역 1개. 하위 뷰(Look 저장, Words 표시)가 환경으로 공유.
    @StateObject private var wordStore = WordStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(wordStore)
        }
    }
}
