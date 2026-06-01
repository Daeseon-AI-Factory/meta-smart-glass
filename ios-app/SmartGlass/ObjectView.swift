import SwiftUI
import PhotosUI
import UIKit

// Look — 핵심 기능: 사물을 보면 개별로 인식해서 그 위치에 영어 단어를 박는다 (AR식 라벨).
// 시야 안 가리게 작은 칩 + 토글(eye)로 끄고켜기. 카메라/사진 → 다운스케일 → /api/label.
struct ObjectView: View {
    @State private var pickedItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var objects: [LabeledObject] = []
    @State private var status: ScanStatus = .idle
    @State private var showLabels = true
    // 라벨링된 단어를 단어장에 자동 누적 — "Lens는 잊고, 우린 기억한다".
    @EnvironmentObject private var wordStore: WordStore

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    sourceRow

                    if let capturedImage {
                        LabeledImageView(image: capturedImage, objects: objects, showLabels: showLabels)
                    }

                    statusLine
                    if !objects.isEmpty { wordList }

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

    private var header: some View {
        HStack {
            Text("Look")
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
            Spacer()
            // 단어 표시 켜고끄기 — 시야 비교용.
            Button { showLabels.toggle() } label: {
                Image(systemName: showLabels ? "eye.fill" : "eye.slash.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(objects.isEmpty ? .gray : .green)
            }
            .disabled(objects.isEmpty)
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
                Text(label).font(.system(size: 11, design: .monospaced)).foregroundStyle(.green.opacity(0.7))
            }
        case .success(let meta):
            Text(meta).font(.system(size: 10, design: .monospaced)).foregroundStyle(.green.opacity(0.6))
        case .failure(let message):
            Text(message).font(.system(size: 11, design: .monospaced)).foregroundStyle(.red.opacity(0.85)).lineLimit(3)
        }
    }

    // 사진 아래 단어 요약 (전체 단어 읽기용).
    private var wordList: some View {
        VStack(spacing: 6) {
            ForEach(Array(objects.enumerated()), id: \.offset) { _, object in
                HStack(spacing: 10) {
                    Text(object.english)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                }
            }
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
        capturedImage = UIImage(data: data)
        status = .loading("looking…")
        do {
            let jpeg = downscaledJPEG(data)
            let response = try await Backend.labelObjects(jpegData: jpeg)
            objects = response.objects
            wordStore.addAll(response.objects)   // 본 단어 단어장에 자동 저장
            status = .success(meta: "\(response.objects.count) objects · \(response.provider) · \(response.latencyMs)ms")
        } catch let BackendError.server(message) {
            status = .failure(message)
        } catch {
            status = .failure(error.localizedDescription)
        }
    }

    private func reset() {
        capturedImage = nil
        objects = []
    }
}

// 사진 + 각 물체 위치에 단어 칩. aspectRatio로 컨테이너를 이미지에 맞춰 박스 좌표를 직접 매핑.
struct LabeledImageView: View {
    let image: UIImage
    let objects: [LabeledObject]
    let showLabels: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)

                if showLabels {
                    ForEach(Array(objects.enumerated()), id: \.offset) { _, object in
                        if let box = object.box {
                            LabelChip(text: object.english)
                                .position(
                                    x: min(geo.size.width - 30, max(30, (box.x + box.width / 2) * geo.size.width)),
                                    y: max(12, box.y * geo.size.height),
                                )
                        }
                    }
                }
            }
        }
        .aspectRatio(image.size.width / max(image.size.height, 1), contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: 380)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// 시야 안 가리는 작은 단어 칩 (물체 위에 얹힘).
struct LabelChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.black)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.green.opacity(0.92)))
            .fixedSize()
    }
}

// 업로드 전 다운스케일(긴 변 1024px, JPEG) — 업로드 속도 + 쿼터 절약.
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
