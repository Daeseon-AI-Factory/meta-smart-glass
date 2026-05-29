# Smart Glass — English Assistant for Working Holiday

## Project Overview
워홀 한국인을 위한 실시간 영어 어시스턴트 (Meta Ray-Ban Display 대상).
장기적으론 외국인 노동자 산업 트레이닝 도구로 확장 예정.

## User
- 1인 개발자 (한국인, 토론토 워홀 중)
- 본인이 직접 daily user
- 영어 학습/업무 보조 + 향후 B2B 산업 트레이닝

## Tech Stack (확정)
- **iOS Native**: Swift 6 + Xcode 16+
- **Glasses SDK**: Meta Wearables Device Access Toolkit (developer preview)
- **Backend**: Node.js + TypeScript (API 키 보호 + LLM orchestration)
- **LLM**: OpenAI GPT-4o-mini (default) + Anthropic Claude Haiku 4.5 (fallback)
- **STT**: Whisper (large-v3 로컬 또는 OpenAI Whisper API)
- **Vision**: Apple Vision Framework 우선, 나중에 YOLOv8 CoreML

## Hardware
- **Dev machine**: MacBook Pro M2 Max 32GB (현재 사용)
- **Phone**: iPhone 16 Pro Max
- **Target glasses**: Ray-Ban Display (구매 미정, Mock Device Kit으로 개발 중)
- **Future option**: Mac Mini M4 Pro 48GB as home LLM server

## Architecture
```
[Glasses (BLE)] <-> [iPhone (Meta AI app + 본인 앱)] <-> [Backend (Mac/cloud)]
                                                          |
                                                          v
                                                  [LLM API / 로컬 Ollama]
```

- 글래스 = I/O only (camera, mic, display)
- 폰 = 본인 native 앱 + Meta SDK
- 백엔드 = LLM 호출, API 키 보관, 비즈니스 로직

## Code Conventions

### Swift
- Swift 6 strict concurrency 사용
- async/await 우선 (callbacks 지양)
- SwiftUI for UI (UIKit fallback)
- 변수/함수명: English camelCase
- 주석: Korean OK (본인 이해 우선)

### TypeScript (backend)
- ESM modules
- Bun runtime
- Strict TS
- 함수형 스타일 선호

### Files
- 한 파일 = 한 책임
- 200줄 넘으면 분리 검토
- Test 파일은 같은 폴더에 `*.test.swift` / `*.test.ts`

## Critical Constraints

### Security
- **API 키 절대 client-side X** — 모든 LLM 호출은 backend 경유
- .env 절대 git commit 금지
- 사용자 음성/영상 데이터: 로컬 처리 우선, 클라우드는 명시적 동의

### Performance
- 글래스 표시 latency 목표: <500ms (실시간 느낌)
- 클라우드 LLM TTFT: <1초
- 로컬 처리 (Whisper, Vision): <300ms

### Privacy
- 캐나다 PIPEDA, 한국 PIPA 준수
- 데이터 수집 명시적 동의
- 회의 녹음은 캐나다 one-party consent 가정 (verify 필요)

## Common Commands

### iOS dev
```bash
# Xcode 열기
open ios-app/SmartGlass.xcodeproj

# 빌드 + 시뮬레이터 실행
xcodebuild -scheme SmartGlass -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max'
```

### Backend dev
```bash
cd backend
bun install
bun run dev    # localhost:3001
ngrok http 3001  # 외부 노출
```

### LLM 호출 테스트
```bash
curl -X POST http://localhost:3001/api/suggest \
  -H "Content-Type: application/json" \
  -d '{"text": "Could you walk me through last week metrics?"}'
```

## Important Files
- `prompts/english-coach.md`: 영어 답변 제안 프롬프트 (자주 수정됨)
- `ios-app/SmartGlass/Core/Session.swift`: 글래스 세션 관리
- `backend/src/api/llm.ts`: LLM 호출 로직

## Things to Avoid
- API 키 하드코딩
- 거대한 함수 (50줄+)
- 클라이언트에서 LLM 직접 호출
- 한국어 변수명/함수명 (주석은 OK)
- npm 사용 (bun 통일)
- UIKit 신규 코드 (SwiftUI 우선)
- Promise chains (async/await 우선)

## Current Phase
**Phase 1 - Validation (Month 1-2)**: 
Mock Device Kit + 시뮬레이터로 prototype.
글래스 구매 X. 본인이 매일 쓸 가치 있는지 검증 중.

## Decisions Log
주요 의사결정은 `docs/decisions.md`에 기록.
- Why Swift Native (not Flutter): 실시간 성능 + Meta 공식 지원
- Why iOS first (not Android): iPhone 사용자 ARPU + 솔로 개발 효율
- Why Cloud LLM first (not local): 셋업 빠름 + 검증 우선
