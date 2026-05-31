import SwiftUI

// 두 Phase 1 코어 기능을 탭으로: English Coach(영어 답변 제안) + Scan(OCR→번역).
struct ContentView: View {
    var body: some View {
        TabView {
            ObjectView()
                .tabItem { Label("Look", systemImage: "eye.fill") }
            ScanView()
                .tabItem { Label("Scan", systemImage: "camera.viewfinder") }
            CoachView()
                .tabItem { Label("Coach", systemImage: "bubble.left.and.text.bubble.right.fill") }
        }
        .tint(.green)
    }
}

#Preview {
    ContentView()
}
