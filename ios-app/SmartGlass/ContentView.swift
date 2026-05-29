import SwiftUI

struct ContentView: View {
    @State private var status: String = "—"
    @State private var detail: String = "fetching..."
    @State private var isOnline: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GlassDisplayView(
                status: status,
                detail: detail,
                isOnline: isOnline
            )
            .frame(width: 280, height: 280)
            .offset(x: 50, y: -120)
        }
        .task {
            await fetchHealth()
        }
    }

    func fetchHealth() async {
        do {
            let url = URL(string: "http://localhost:3001/health")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(HealthResponse.self, from: data)
            status = response.status.uppercased()
            detail = response.timestamp
            isOnline = true
        } catch {
            status = "OFFLINE"
            detail = error.localizedDescription
            isOnline = false
        }
    }
}

struct HealthResponse: Decodable {
    let status: String
    let service: String
    let timestamp: String
}

struct GlassDisplayView: View {
    let status: String
    let detail: String
    let isOnline: Bool

    var body: some View {
        let color: Color = isOnline ? .green : .red

        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(color.opacity(0.35), lineWidth: 1)
                )

            VStack(spacing: 10) {
                Image(systemName: isOnline ? "wifi" : "wifi.slash")
                    .font(.system(size: 28))
                    .foregroundStyle(color)
                Text(status)
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundStyle(color)
                Text(detail)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(color.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 8)
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
