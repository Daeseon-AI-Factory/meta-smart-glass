# Vision Labeler Prompt

물체 인식 + 영어 단어 학습 use case.

---

## Use Case
사용자가 카메라로 본 물체에 영어 라벨/단어 표시.
영어 어휘 학습 + 일상 단어 노출.

---

## Approach: Two-Tier System

### Tier 1: Real-time (로컬, 빠름)
- **YOLO** 또는 **Apple Vision Framework**
- 출력: class 이름만 (예: "cup", "laptop", "chair")
- Latency: <100ms
- No LLM 호출

### Tier 2: Detailed (LLM, 풍부함)
- 사용자가 "이거 정확히 뭐야?" 요청할 때만
- GPT-4o Vision 호출
- 출력: 자세한 설명 + 학습 팁

---

## Tier 2 Prompt v0.1

```
You are a vocabulary teacher for a Korean English learner.

INPUT: An image
JOB: Identify the most prominent object and provide:
1. Common English name (1-2 words)
2. (If applicable) More specific/formal name
3. Brief description in Korean
4. 1 example sentence using this word

RULES:
- Pick ONE main object, not many
- English word: simple, common
- Korean description: 1 sentence
- Example: natural English, useful for daily conversation

OUTPUT FORMAT:
```json
{
  "main_word": "coffee",
  "specific": "espresso macchiato",
  "korean_explanation": "에스프레소에 우유 거품을 살짝 얹은 음료",
  "example_sentence": "I'll have an espresso macchiato, please.",
  "difficulty": "intermediate"
}
```

EXAMPLES:

Image: red apple
{
  "main_word": "apple",
  "specific": "red apple",
  "korean_explanation": "빨간 사과",
  "example_sentence": "An apple a day keeps the doctor away.",
  "difficulty": "beginner"
}

Image: laptop on desk
{
  "main_word": "laptop",
  "specific": "MacBook Pro",
  "korean_explanation": "노트북 컴퓨터",
  "example_sentence": "I'm working from my laptop today.",
  "difficulty": "beginner"
}
```

---

## Tier 1: YOLO Class Mapping (80 COCO classes)

YOLO 출력 → 사용자 친화 영어 단어:

```json
{
  "person": "person",
  "bicycle": "bicycle",
  "car": "car",
  "motorcycle": "motorcycle",
  "airplane": "airplane",
  "bus": "bus",
  "train": "train",
  "truck": "truck",
  "boat": "boat",
  "traffic light": "traffic light",
  "fire hydrant": "fire hydrant",
  "stop sign": "stop sign",
  "parking meter": "parking meter",
  "bench": "bench",
  "bird": "bird",
  "cat": "cat",
  "dog": "dog",
  "horse": "horse",
  "sheep": "sheep",
  "cow": "cow",
  "elephant": "elephant",
  "bear": "bear",
  "zebra": "zebra",
  "giraffe": "giraffe",
  "backpack": "backpack",
  "umbrella": "umbrella",
  "handbag": "handbag",
  "tie": "tie",
  "suitcase": "suitcase",
  "frisbee": "frisbee",
  "skis": "skis",
  "snowboard": "snowboard",
  "sports ball": "ball",
  "kite": "kite",
  "baseball bat": "bat",
  "baseball glove": "glove",
  "skateboard": "skateboard",
  "surfboard": "surfboard",
  "tennis racket": "tennis racket",
  "bottle": "bottle",
  "wine glass": "wine glass",
  "cup": "cup",
  "fork": "fork",
  "knife": "knife",
  "spoon": "spoon",
  "bowl": "bowl",
  "banana": "banana",
  "apple": "apple",
  "sandwich": "sandwich",
  "orange": "orange",
  "broccoli": "broccoli",
  "carrot": "carrot",
  "hot dog": "hot dog",
  "pizza": "pizza",
  "donut": "donut",
  "cake": "cake",
  "chair": "chair",
  "couch": "couch",
  "potted plant": "plant",
  "bed": "bed",
  "dining table": "table",
  "toilet": "toilet",
  "tv": "TV",
  "laptop": "laptop",
  "mouse": "mouse",
  "remote": "remote",
  "keyboard": "keyboard",
  "cell phone": "phone",
  "microwave": "microwave",
  "oven": "oven",
  "toaster": "toaster",
  "sink": "sink",
  "refrigerator": "fridge",
  "book": "book",
  "clock": "clock",
  "vase": "vase",
  "scissors": "scissors",
  "teddy bear": "teddy bear",
  "hair drier": "hair dryer",
  "toothbrush": "toothbrush"
}
```

이게 본인 학습할 80개 일상 영어 단어 list.

---

## Display Strategy

글래스에 어떻게 보여줄지:

### Real-time mode (Tier 1)
화면 우측 하단에 작게:
```
🪑 chair
💻 laptop  
☕ cup
```

물체 위에 floating label X (화면 작아서 어려움). 리스트 형태가 깔끔.

### Detail mode (Tier 2)
사용자 Neural Band gesture (탭) → 모달 형태:
```
┌──────────────┐
│ ☕ COFFEE    │
│ 커피         │
│              │
│ "I'd like    │
│  a coffee."  │
└──────────────┘
```

---

## Tuning Log

### v0.1 (2026-05-25)
- 초기 버전
- COCO 80개로 시작
- 검증 후 한국인 자주 모르는 단어 추가 (예: 미국 음식 종류, 가전제품 등)

### v0.2 (예정)
- [ ] 사용자 학습 히스토리 트래킹 (이미 학습한 단어 skip)
- [ ] 난이도별 필터링
- [ ] SRS (간격 반복 학습) 통합
