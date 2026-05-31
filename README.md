# Smart Glass — English Assistant

워홀 한국인을 위한 실시간 영어 어시스턴트.
Meta Ray-Ban Display (또는 호환 글래스) 대상.

## Status
🚧 Phase 1 - Validation (Mock Device Kit으로 prototype 빌드 중)

## Quick Start

### Prerequisites
- macOS (Apple Silicon 권장)
- Xcode 16+
- Bun 1.0+
- Node.js 20+ (backend용)
- Meta Wearables Developer 계정

### Setup
```bash
# 1. 환경 변수 설정
cp .env.example .env
# .env 파일 열어서 API 키 입력

# 2. Backend
cd backend
bun install
bun run dev

# 3. iOS app
open ios-app/SmartGlass.xcodeproj
# Xcode에서 Cmd+R로 실행
```

## Architecture

```
[Glasses] <-BLE-> [iPhone App] <-HTTPS-> [Backend] -> [LLM API]
```

## Documentation
- [CLAUDE.md](./CLAUDE.md) - Claude Code 컨텍스트
- [docs/decisions.md](./docs/decisions.md) - 의사결정 기록
- [docs/use-cases.md](./docs/use-cases.md) - 사용 사례
- [docs/architecture.md](./docs/architecture.md) - 시스템 구조

## License
Private project. All rights reserved.
