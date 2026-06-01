# Bun 백엔드 컨테이너 이미지. AWS App Runner(또는 어디서든) 실행용.
# 시크릿(.env)은 절대 안 넣음 — .dockerignore로 제외, 키는 런타임 환경변수로 주입.
FROM oven/bun:1-slim

WORKDIR /app

# 1) 의존성 매니페스트만 먼저 복사 → 레이어 캐시(소스만 바뀌면 install 재실행 안 함, 빌드 빠름)
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile --production

# 2) 앱 소스 복사
COPY tsconfig.json ./
COPY src ./src

# 3) App Runner는 이 포트로 헬스체크·트래픽을 보냄. 앱은 PORT env를 읽음(index.ts).
ENV PORT=8080
EXPOSE 8080

# 4) 실행 — Bun이 TS를 그대로 구동(빌드 단계 불필요)
CMD ["bun", "src/index.ts"]
