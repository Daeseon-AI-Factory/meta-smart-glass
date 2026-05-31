import Foundation
import AVFoundation
import Vision
import CoreML

// 실시간 검출 결과 1개 = 영어 라벨 + 한국어 + 정규화 박스(top-left 원점) + 신뢰도.
struct Detection: Identifiable, Sendable {
    let id: UUID
    let label: String
    let korean: String
    let box: CGRect
    let confidence: Float
}

// 안정화용 추적 객체 (프레임 넘어 같은 사물 유지 + 박스 스무딩). id가 안정적이라 깜빡임 ↓.
private struct TrackedObject {
    let id: UUID
    let label: String
    let korean: String
    var box: CGRect
    var confidence: Float
    var lastTick: Int
}

// COCO 80 클래스 → 한국어 (YOLO11 출력 라벨 = 이 영어 키들).
let cocoKorean: [String: String] = [
    "person": "사람", "bicycle": "자전거", "car": "자동차", "motorcycle": "오토바이",
    "airplane": "비행기", "bus": "버스", "train": "기차", "truck": "트럭", "boat": "보트",
    "traffic light": "신호등", "fire hydrant": "소화전", "stop sign": "정지 표지판",
    "parking meter": "주차 미터기", "bench": "벤치", "bird": "새", "cat": "고양이", "dog": "개",
    "horse": "말", "sheep": "양", "cow": "소", "elephant": "코끼리", "bear": "곰", "zebra": "얼룩말",
    "giraffe": "기린", "backpack": "백팩", "umbrella": "우산", "handbag": "핸드백", "tie": "넥타이",
    "suitcase": "여행 가방", "frisbee": "프리스비", "skis": "스키", "snowboard": "스노보드",
    "sports ball": "공", "kite": "연", "baseball bat": "야구 배트", "baseball glove": "야구 글러브",
    "skateboard": "스케이트보드", "surfboard": "서핑보드", "tennis racket": "테니스 라켓",
    "bottle": "병", "wine glass": "와인잔", "cup": "컵", "fork": "포크", "knife": "칼", "spoon": "숟가락",
    "bowl": "그릇", "banana": "바나나", "apple": "사과", "sandwich": "샌드위치", "orange": "오렌지",
    "broccoli": "브로콜리", "carrot": "당근", "hot dog": "핫도그", "pizza": "피자", "donut": "도넛",
    "cake": "케이크", "chair": "의자", "couch": "소파", "potted plant": "화분", "bed": "침대",
    "dining table": "식탁", "toilet": "변기", "tv": "TV", "laptop": "노트북", "mouse": "마우스",
    "remote": "리모컨", "keyboard": "키보드", "cell phone": "휴대폰", "microwave": "전자레인지",
    "oven": "오븐", "toaster": "토스터", "sink": "싱크대", "refrigerator": "냉장고", "book": "책",
    "clock": "시계", "vase": "꽃병", "scissors": "가위", "teddy bear": "곰 인형",
    "hair drier": "헤어드라이어", "toothbrush": "칫솔",
]

// 라이브 온디바이스 객체 검출기.
// 카메라 영상 프레임 → VNCoreMLRequest(YOLO11) → VNRecognizedObjectObservation → Detection[].
@MainActor
final class LiveDetector: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let videoQueue = DispatchQueue(label: "live.video")

    // 비전 모델은 nonisolated 델리게이트(영상 큐)에서 추론에 쓰임. 로드 1회 후 read-only.
    nonisolated(unsafe) private var vnModel: VNCoreMLModel?

    // 안정화 상태 — 직렬 videoQueue에서만 접근(직렬화돼 안전).
    nonisolated(unsafe) private var tracked: [TrackedObject] = []
    nonisolated(unsafe) private var frameTick = 0

    enum State: Equatable {
        case idle
        case running
        case denied
        case noModel
        case failed(String)
    }
    @Published private(set) var state: State = .idle
    @Published private(set) var detections: [Detection] = []

    func start() async {
        guard await ensureAuthorized() else { state = .denied; return }
        guard loadModel() else { state = .noModel; return }
        guard configureSession() else { state = .failed("camera unavailable"); return }
        await setRunning(true)
        state = .running
    }

    func stop() {
        Task { await setRunning(false) }
    }

    // yolo11n.mlpackage를 Xcode에 추가하면 yolo11n.mlmodelc로 컴파일됨. 이름으로 런타임 로드(없으면 .noModel).
    private func loadModel() -> Bool {
        guard let url = Bundle.main.url(forResource: "yolo11n", withExtension: "mlmodelc") else {
            return false
        }
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            vnModel = try VNCoreMLModel(for: MLModel(contentsOf: url, configuration: config))
            return true
        } catch {
            return false
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
        session.sessionPreset = .high
        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else { return false }
        session.addInput(input)

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        guard session.canAddOutput(videoOutput) else { return false }
        session.addOutput(videoOutput)
        return true
    }

    private func setRunning(_ running: Bool) async {
        let box = SessionBox(session: session)
        await Task.detached {
            if running { box.session.startRunning() } else { box.session.stopRunning() }
        }.value
    }
}

extension LiveDetector: AVCaptureVideoDataOutputSampleBufferDelegate {
    // 영상 큐에서 매 프레임 호출(nonisolated). 추론 → 안정화 → Sendable 결과만 MainActor로.
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection,
    ) {
        guard let model = vnModel else { return }
        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .scaleFill
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .right, options: [:])
        guard (try? handler.perform([request])) != nil else { return }

        let observations = (request.results as? [VNRecognizedObjectObservation]) ?? []
        let raw: [Detection] = observations.compactMap { observation in
            guard let top = observation.labels.first, top.confidence > 0.5 else { return nil }
            // Vision 박스는 bottom-left 원점 → SwiftUI top-left로 변환.
            let b = observation.boundingBox
            let rect = CGRect(x: b.minX, y: 1 - b.maxY, width: b.width, height: b.height)
            return Detection(
                id: UUID(),
                label: top.identifier,
                korean: cocoKorean[top.identifier] ?? "",
                box: rect,
                confidence: top.confidence,
            )
        }

        let stable = stabilize(raw)
        Task { @MainActor [weak self] in self?.detections = stable }
    }

    // 깜빡임 완화: 같은 라벨+위치(IoU) 매칭해 박스를 EMA 스무딩, 잠깐(6틱) 유지. videoQueue 직렬이라 안전.
    private nonisolated func stabilize(_ raw: [Detection]) -> [Detection] {
        frameTick &+= 1
        for det in raw {
            if let i = tracked.firstIndex(where: { $0.label == det.label && iou($0.box, det.box) > 0.3 }) {
                tracked[i].box = lerpRect(tracked[i].box, det.box, 0.4)
                tracked[i].confidence = det.confidence
                tracked[i].lastTick = frameTick
            } else {
                tracked.append(TrackedObject(
                    id: UUID(),
                    label: det.label,
                    korean: det.korean,
                    box: det.box,
                    confidence: det.confidence,
                    lastTick: frameTick,
                ))
            }
        }
        tracked.removeAll { frameTick - $0.lastTick > 6 }
        return tracked.map {
            Detection(id: $0.id, label: $0.label, korean: $0.korean, box: $0.box, confidence: $0.confidence)
        }
    }

    private nonisolated func iou(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let inter = a.intersection(b)
        if inter.isNull { return 0 }
        let interArea = inter.width * inter.height
        let union = a.width * a.height + b.width * b.height - interArea
        return union <= 0 ? 0 : interArea / union
    }

    private nonisolated func lerpRect(_ a: CGRect, _ b: CGRect, _ t: CGFloat) -> CGRect {
        CGRect(
            x: a.minX + (b.minX - a.minX) * t,
            y: a.minY + (b.minY - a.minY) * t,
            width: a.width + (b.width - a.width) * t,
            height: a.height + (b.height - a.height) * t,
        )
    }
}
