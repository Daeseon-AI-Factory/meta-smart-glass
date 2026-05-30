import SwiftUI
import PhotosUI
import UIKit

enum ScanStatus: Equatable {
    case idle
    case loading(String)
    case success(meta: String)
    case failure(String)
}

// 스캔 → 번역: (mock글래스/폰)사진 → Vision OCR → /api/translate → HUD.
// 지금 소스는 PhotosPicker(시뮬에서도 됨). 등록 후 카메라/MWDAT 피드로 교체 예정.
struct ScanView: View {
    @State private var pickedItem: PhotosPickerItem?
    @State private var previewImage: Image?
    @State private var ocrText: String = ""
    @State private var translation: String = ""
    @State private var status: ScanStatus = .idle

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                Text("Scan & Translate")
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)

                PhotosPicker(selection: $pickedItem, matching: .images) {
                    Label("Pick a menu / sign photo", systemImage: "camera.viewfinder")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.green.opacity(0.12)))
                }

                if let previewImage {
                    previewImage
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                statusLine
                if !ocrText.isEmpty { ocrBlock }
                if !translation.isEmpty { translationCard }

                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .onChange(of: pickedItem) { _, newItem in
            Task { await handlePick(newItem) }
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        switch status {
        case .idle:
            EmptyView()
        case .loading(let label):
            HStack(spacing: 8) {
                ProgressView().tint(.green)
                Text(label)
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

    private var ocrBlock: some View {
        Text(ocrText)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(4)
    }

    private var translationCard: some View {
        Text(translation)
            .font(.system(size: 18, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green.opacity(0.3), lineWidth: 1))
            )
    }

    @MainActor
    private func handlePick(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        previewImage = nil
        ocrText = ""
        translation = ""
        status = .loading("reading photo…")
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                status = .failure("couldn't load the photo")
                return
            }
            if let uiImage = UIImage(data: data) {
                previewImage = Image(uiImage: uiImage)
            }

            status = .loading("reading text…")
            let text = try await recognizeText(in: data)
            ocrText = text
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                status = .failure("no text found in the image")
                return
            }

            status = .loading("translating…")
            let response = try await Backend.translation(text: text)
            translation = response.translation
            status = .success(meta: "\(response.provider) · \(response.model) · \(response.latencyMs)ms")
        } catch let BackendError.server(message) {
            status = .failure(message)
        } catch {
            status = .failure(error.localizedDescription)
        }
    }
}
