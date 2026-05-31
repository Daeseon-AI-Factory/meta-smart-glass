import SwiftUI
import AVFoundation
import UIKit

enum CameraError: Error, Sendable {
    case denied
    case unavailable
    case captureFailed(String)
}

// AVCaptureSession은 non-Sendable이지만 start/stopRunning은 스레드 세이프.
// off-main 실행을 위해 @unchecked Sendable 박스로 경계만 넘긴다. (Camera/Live 공유)
struct SessionBox: @unchecked Sendable {
    let session: AVCaptureSession
}

// 라이브 카메라 캡처. 캡처 결과는 Data(Sendable)로 넘겨 기존 OCR→번역 파이프라인 재사용.
// 글래스 도착 시 이 소스를 MWDAT 카메라 피드로 교체 (Vision→번역은 동일).
@MainActor
final class CameraModel: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var captureContinuation: CheckedContinuation<Data, Error>?

    enum State: Equatable {
        case idle
        case ready
        case denied
        case failed(String)
    }
    @Published private(set) var state: State = .idle

    func start() async {
        guard await ensureAuthorized() else { state = .denied; return }
        guard configureSession() else { state = .failed("camera unavailable"); return }
        await setRunning(true)
        state = .ready
    }

    func stop() {
        Task { await setRunning(false) }
    }

    func capturePhoto() async throws -> Data {
        guard state == .ready else { throw CameraError.unavailable }
        return try await withCheckedThrowingContinuation { continuation in
            captureContinuation = continuation
            output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }

    private func ensureAuthorized() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }

    private func configureSession() -> Bool {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input), session.canAddOutput(output)
        else { return false }
        session.addInput(input)
        session.addOutput(output)
        return true
    }

    // startRunning/stopRunning은 블로킹 → off-main 실행. 박스로 세션을 경계 너머로 전달.
    private func setRunning(_ running: Bool) async {
        let box = SessionBox(session: session)
        await Task.detached {
            if running { box.session.startRunning() } else { box.session.stopRunning() }
        }.value
    }

    private func deliver(_ result: Result<Data, CameraError>) {
        captureContinuation?.resume(with: result.mapError { $0 as Error })
        captureContinuation = nil
    }
}

extension CameraModel: AVCapturePhotoCaptureDelegate {
    // 임의 큐에서 호출(nonisolated). Sendable(Data/CameraError)만 MainActor로 넘긴다.
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?,
    ) {
        let result: Result<Data, CameraError>
        if let data = photo.fileDataRepresentation() {
            result = .success(data)
        } else {
            result = .failure(.captureFailed(error?.localizedDescription ?? "no photo data"))
        }
        Task { @MainActor in self.deliver(result) }
    }
}

// MARK: - SwiftUI preview layer

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            // layerClass를 고정했으므로 안전.
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}

// MARK: - Full-screen capture UI

struct CameraCaptureView: View {
    @StateObject private var model = CameraModel()
    let onCapture: (Data) -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch model.state {
            case .ready:
                CameraPreview(session: model.session).ignoresSafeArea()
            case .denied:
                message("Camera access denied.\nEnable it in Settings.", color: .red)
            case .failed(let detail):
                message(detail, color: .red)
            case .idle:
                ProgressView().tint(.white)
            }

            VStack {
                HStack {
                    Button("Cancel", action: onCancel)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.black.opacity(0.4), in: Capsule())
                    Spacer()
                }
                Spacer()
                Button(action: { Task { await capture() } }) {
                    Circle()
                        .fill(.white)
                        .frame(width: 72, height: 72)
                        .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 4).padding(-6))
                }
                .disabled(model.state != .ready)
                .padding(.bottom, 24)
            }
            .padding()
        }
        .task { await model.start() }
        .onDisappear { model.stop() }
    }

    private func message(_ text: String, color: Color) -> some View {
        Text(text)
            .multilineTextAlignment(.center)
            .font(.system(size: 14, design: .monospaced))
            .foregroundStyle(color)
            .padding()
    }

    private func capture() async {
        do {
            let data = try await model.capturePhoto()
            onCapture(data)
        } catch {
            onCancel()
        }
    }
}
