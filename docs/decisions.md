# Decision Log

본 프로젝트의 주요 의사결정 기록. 시간 지나면 왜 그렇게 했는지 잊혀지니까.

---

## 2026-05-25: Tech Stack 결정

### Swift Native (not Flutter, not React Native)
**선택**: Swift + Meta Wearables Device Access Toolkit (iOS native)

**대안**: 
- Flutter (Dart) — 커뮤니티 wrapper (meta_wearables)
- React Native — 공식 SDK 없음
- Web Apps (HTML/JS) — 카메라 접근 불가

**이유**:
- 실시간 BLE + 카메라 = 네이티브가 가장 안정적
- Meta 공식 1순위 지원 (Swift Package 직접 배포)
- Flutter wrapper는 community 유지보수 (v0.2.1, 1인 메인테이너)
- Vision/AR 산업 표준이 native (HoloLens, Vision Pro, etc.)
- AI 코딩 도구 (Claude Code) Swift 학습 데이터 풍부

**Trade-off 인지**:
- Android 별도 작업 필요 (Kotlin) — Year 2로 미룸
- Swift 학습 곡선 — AI 도구로 단축 가능

---

### iOS first (not Android, not cross-platform)
**선택**: iOS only at launch

**이유**:
- 솔로 개발자 시간 제약
- Ray-Ban Display 주력 사용자 = iPhone (premium 시장)
- 본인 iPhone 16 Pro Max 보유 = 즉시 테스트 가능
- iOS 사용자 ARPU 높음 (일반 통념)
- Android는 검증 후 Year 2 추가

---

### Cloud LLM first (not local Ollama)
**선택**: OpenAI/Anthropic API로 시작

**대안**: 본인 Mac M2 Max에서 Ollama + 로컬 모델

**이유**:
- 셋업 5분 vs 1-2시간
- 검증 단계: 빠른 iteration > 비용 최적화
- Mac M2 Max는 백업 옵션 (검증 후 latency/cost 최적화)

**나중 검토**:
- 사용량 늘면 Ollama 하이브리드
- Mac Mini M4 Pro ($1,799)을 home server로

---

## 2026-05-25: Hardware 결정

### Mock Device Kit으로 시작 (글래스 구매 X)
**이유**:
- Ray-Ban Display $799 + 미국 여행/친구 = $1,200-1,700 CAD
- 본인 use case 검증 전엔 너무 큰 투자
- Meta가 Mock Device Kit 제공 = 시뮬레이션 가능

**구매 결정 시점**: prototype 1-2개월 사용 후 진짜 가치 확인되면

---

## 2026-05-25: Repo 구조

### 모노 repo (not multi-repo)
**이유**:
- 솔로 개발자
- core/adapters 분리로 portable
- 한 곳에서 통합 관리

---

## 2026-05-31: 객체 라벨링 — 엔진 · 커버리지 · 해자

### Live(실시간 객체 라벨링) 엔진 = 온디바이스 YOLO11 (not 클라우드)
**선택**: 카메라 영상 → 폰 안 CoreML(YOLO11n)으로 실시간 검출.
**이유**:
- 실시간 (Neural Engine 60fps). 클라우드(Gemini)는 호출당 2-3초 + 쿼터라 영상에 불가.
- 무료 · 오프라인 · 프라이버시. architecture.md의 "물체 영어 라벨링 / YOLO / 실시간 15+ FPS"가 원래 계획이었음.

**Trade-off**: 모델이 학습한 클래스로 제한 (COCO 80개). → 커버리지는 하이브리드로 보완(아래).

### 커버리지 = 하이브리드 2층 ("전부 학습"은 안 함)
**선택**: 흔한 사물 = 온디바이스 ambient(실시간) + 모르는/특이한 거 = 탭 → Gemini(아무거나).
**이유**:
- "아무거나 + 실시간 + 온디바이스" 셋 다 최대 = 물리적 불가(택2). 도구를 나누면 셋 다 가짐.
- 일상에서 마주치는 사물은 유한(~수백 개). 세세한 long tail은 탭으로 해결, 거대 모델로 X.

**기술 메모(자주 헷갈림)**: 클래스 수(80→500)는 속도에 거의 영향 없음(마지막 출력층만 커짐). 무거운 건 *모델 크기*(nano→small→large)와 입력 해상도. → 클래스 늘리기 자체는 싸다.

### 해자 = 학습 경험 (not detection 범위)
**이유**:
- 라벨링 자체는 commodity (Google Lens, Meta AI on-glasses). 범위로 경쟁하면 짐.
- 타깃 = 영어 0인 초보. "chair"만 떠선 무의미 → **영어 + 한국어 + 발음 + 본 단어 저장·복습**이 진짜 가치.
- 다음 투자는 "더 많은 클래스"가 아니라 학습 레이어(발음 TTS, 단어 누적/복습).

### 폰 단독으로도 제품 (글래스가 전제 아님)
**이유**: point-and-learn은 폰에서도 쓸만함 → 글래스/Meta preview 없이 **지금 검증·출시 가능**(de-risk). 글래스는 그 위에 얹는 ambient 강화일 뿐.

---

## 2026-05-31 (cont.): 라벨 UX · 모델 · 배포 방향

### Live/Look 라벨 = 영어만 (한국어 제거)
**선택**: 박스/칩에 영어 단어만. 한국어 뜻 안 띄움.
**이유**: 사물이 *눈앞에 보이므로* 시각 자체가 뜻을 전달함 → 새 정보는 *영어 이름*뿐. 유저: "한국어 딱히 필요없다, 내가 보는 사물이 영어로 뭔지 아는 게 중요". (단어장 데이터엔 korean 필드는 보관 — 추후 beginner/B2B 모드 대비.)

### 온디바이스 모델 = yolo11n 유지 (600클래스 OIV7 폐기)
**선택**: COCO 80짜리 yolo11n 그대로. 600클래스 안 감.
**이유**: OIV7는 정확도가 절반(mAP~18) → 실기기에서 오히려 덜·느리게 잡힘(troubleshooting 참조). breadth는 모델 키우기 말고 클라우드 탭(Gemini)으로.

### 학습 루프 = 첫 해자 조각 (단어장 + 발음)
**선택**: Look에서 본 단어 자동 저장(WordStore, Documents JSON) + 단어장 탭 + 탭하면 온디바이스 TTS 발음. spaced-repetition 퀴즈는 다음.
**이유**: detection은 commodity (경쟁 리서치: Vocam·LingoLens·Lenzo가 이미 함; Meta Ray-Ban은 번역만/유럽 6개어/하드웨어 게이트). 차별화는 "기억시키기" — Lens는 잊고 우린 남긴다. 그리고 진짜 해자는 *기능*도 아니라 **버티컬**(워홀/이민 노동자 직무 영어 → B2B 산업 트레이닝). Meta=번역기(목발), 우리=학습(능력 키움) — 정반대 목표.

### 배포 = AWS App Runner (학습 목적)
**선택**: Railway가 더 빠르지만 일부러 AWS(App Runner). 컨테이너→ECR→App Runner, 시크릿은 런타임 env.
**이유**: 이 배포를 teach-first·전부-기록 DevOps 학습 과제로 진행(`content/logs/.../devops-from-zero`). Lambda(Bun 미스핏)·생EC2 제외.

---

## (Future) Decisions to make
- [ ] 한국 vs 캐나다 영업/배포 전략 (B2B 피벗 시)
- [ ] 가격 모델 (구독 vs 일회성 vs B2B)
- [ ] Apple 진입 시 (2027 예상) 대응 전략
- [ ] 사업자 등록 시점/위치 (한국 vs 캐나다)
