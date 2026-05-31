import SwiftUI
import PhotosUI
import UIKit

// Look — 핵심 기능: 사물을 보면 개별로 인식해서 영어 이름 + 한국어 뜻 (영어 단어 학습).
// 카메라/사진 → 다운스케일 → /api/label(Gemini 비전) → 라벨 카드.
struct ObjectView: View {
    @State private var pickedItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var previewImage: Image?
    @State private var objects: [LabeledObject] = []
    @State private var status: ScanStatus = .idle

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Look — name things in English")
                        .font(.system(size: 19, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)

                    sourceRow

                    if let previewImage {
                        previewImage
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    statusLine

                    ForEach(Array(objects.enumerated()), id: \.offset) { _, object in
                        ObjectCard(object: object)
                    }

                    Spacer(minLength: 0)
                }
                .padding(20)
            }
        }
        .onChange(of: pickedItem) { _, newItem in
            Task { await handlePick(newItem) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureView(
                onCapture: { data in
                    showCamera = false
                    Task { await process(data) }
                },
                onCancel: { showCamera = false },
            )
        }
    }

    private var sourceRow: some View {
        HStack(spacing: 10) {
            Button(action: { showCamera = true }) {
                SourceButtonLabel(title: "Camera", systemImage: "camera.fill")
            }
            PhotosPicker(selection: $pickedItem, matching: .images) {
                SourceButtonLabel(title: "Photo", systemImage: "photo.on.rectangle")
            }
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

    @MainActor
    private func handlePick(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        status = .loading("reading photo…")
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                reset()
                status = .failure("couldn't load the photo")
                return
            }
            await process(data)
        } catch {
            reset()
            status = .failure(error.localizedDescription)
        }
    }

    @MainActor
    private func process(_ data: Data) async {
        reset()
        if let uiImage = UIImage(data: data) {
            previewImage = Image(uiImage: uiImage)
        }
        status = .loading("looking…")
        do {
            let jpeg = downscaledJPEG(data)
            let response = try await Backend.labelObjects(jpegData: jpeg)
            objects = response.objects
            status = .success(meta: "\(response.objects.count) objects · \(response.provider) · \(response.latencyMs)ms")
        } catch let BackendError.server(message) {
            status = .failure(message)
        } catch {
            status = .failure(error.localizedDescription)
        }
    }

    private func reset() {
        previewImage = nil
        objects = []
    }
}

// 단어 카드: 영어(큼) + 한국어 뜻(작게).
struct ObjectCard: View {
    let object: LabeledObject

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(object.english)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                if !object.korean.isEmpty {
                    Text(object.korean)
                        .font(.system(size: 13))
                        .foregroundStyle(.green.opacity(0.8))
                }
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.25), lineWidth: 1))
        )
    }
}

// 업로드 전 다운스케일(긴 변 1024px, JPEG) — 업로드 속도 + 쿼터 절약.
// UIKit이라 @MainActor (한 장 리사이즈라 부담 적음).
@MainActor
private func downscaledJPEG(_ data: Data, maxDimension: CGFloat = 1024, quality: CGFloat = 0.7) -> Data {
    guard let image = UIImage(data: data) else { return data }
    let longest = max(image.size.width, image.size.height)
    let scale = longest > maxDimension ? maxDimension / longest : 1
    let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    let resized = UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
        image.draw(in: CGRect(origin: .zero, size: newSize))
    }
    return resized.jpegData(compressionQuality: quality) ?? data
}
