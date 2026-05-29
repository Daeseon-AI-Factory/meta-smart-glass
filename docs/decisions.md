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

## (Future) Decisions to make
- [ ] 한국 vs 캐나다 영업/배포 전략 (B2B 피벗 시)
- [ ] 가격 모델 (구독 vs 일회성 vs B2B)
- [ ] Apple 진입 시 (2027 예상) 대응 전략
- [ ] 사업자 등록 시점/위치 (한국 vs 캐나다)
