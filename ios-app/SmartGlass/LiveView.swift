import SwiftUI
import AVFoundation

// Live — 실시간 온디바이스 객체 검출. 카메라에 보이는 사물에 영어 라벨 박스가 실시간으로 따라붙음.
// 시야 안 가리게 박스+작은 칩, 👁 토글로 끄고켜기.
struct LiveView: View {
    @StateObject private var detector = LiveDetector()
    @State private var showLabels = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch detector.state {
            case .running:
                ZStack {
                    CameraPreview(session: detector.session).ignoresSafeArea()
                    if showLabels {
                        GeometryReader { geo in
                            ForEach(detector.detections) { detection in
                                DetectionBoxView(detection: detection, canvas: geo.size)
                            }
                        }
                        .ignoresSafeArea()
                    }
                }
            case .noModel:
                message("On-device model not bundled yet.\nAdd yolo11n to the app and rebuild.", .orange)
            case .denied:
                message("Camera access denied.\nEnable it in Settings.", .red)
            case .failed(let detail):
                message(detail, .red)
            case .idle:
                ProgressView().tint(.white)
            }

            VStack {
                HStack(spacing: 8) {
                    Text("Live")
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                    if detector.state == .running {
                        Text("\(detector.detections.count)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.green.opacity(0.85))
                    }
                    Spacer()
                    Button { showLabels.toggle() } label: {
                        Image(systemName: showLabels ? "eye.fill" : "eye.slash.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.green)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(.black.opacity(0.35))
                Spacer()
            }
        }
        .task { await detector.start() }
        .onDisappear { detector.stop() }
    }

    private func message(_ text: String, _ color: Color) -> some View {
        Text(text)
            .multilineTextAlignment(.center)
            .font(.system(size: 14, design: .monospaced))
            .foregroundStyle(color)
            .padding()
    }
}

// 검출 박스 + 라벨 칩 (박스 위에 작게 얹힘).
struct DetectionBoxView: View {
    let detection: Detection
    let canvas: CGSize

    var body: some View {
        let w = detection.box.width * canvas.width
        let h = detection.box.height * canvas.height
        let x = detection.box.minX * canvas.width
        let y = detection.box.minY * canvas.height

        Rectangle()
            .stroke(Color.green, lineWidth: 2)
            .frame(width: w, height: h)
            .overlay(alignment: .topLeading) {
                // 영어 단어만 — 보고 있는 사물의 영어 이름을 아는 게 핵심. 사물 자체가 보이니 뜻(한국어)은 불필요.
                Text(detection.label)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.green))
                    .fixedSize()
                    .offset(y: -20)
            }
            .position(x: x + w / 2, y: y + h / 2)
    }
}
