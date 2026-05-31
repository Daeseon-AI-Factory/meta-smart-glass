# Architecture

시스템 구조 + 데이터 흐름.

---

## High-Level Diagram

```
┌─────────────────┐                                            
│   Ray-Ban       │                                            
│   Display       │   ◄── 마이크/카메라/디스플레이 (I/O only)   
│   (글래스)       │                                            
└────────┬────────┘                                            
         │ BLE 5.3 / WiFi 6                                    
         ▼                                                     
┌─────────────────┐                                            
│   iPhone        │                                            
│   - Meta AI app │  ◄── 페어링 (Meta 공식 앱)                  
│   - SmartGlass  │  ◄── 본인 native 앱 (Swift)                
│     Native App  │                                            
└────────┬────────┘                                            
         │ HTTPS                                               
         ▼                                                     
┌─────────────────┐                                            
│   Backend       │                                            
│   (MacBook/     │  ◄── Node.js + TypeScript                  
│    Mac Mini)    │  ◄── API 키 보관, 비즈니스 로직              
└────────┬────────┘                                            
         │                                                     
    ┌────┴─────┬──────────────┐                                
    ▼          ▼              ▼                                
┌────────┐ ┌────────┐  ┌──────────┐                            
│ OpenAI │ │ Claude │  │ Local    │                            
│ GPT-4o │ │ Sonnet │  │ Ollama   │                            
│        │ │ /Haiku │  │ (옵션)    │                            
└────────┘ └────────┘  └──────────┘                            
```

---

## Component Responsibilities

### 글래스 (Ray-Ban Display)
**역할**: I/O 디바이스
- 마이크로 음성 입력
- 카메라로 영상 입력
- 디스플레이로 텍스트/이미지 출력
- Neural Band 제스처 입력

**역할 아님**:
- AI 처리 X
- 데이터 저장 X (32GB 있지만 임시)
- 비즈니스 로직 X

### iPhone
**역할**: 글래스 ↔ 백엔드 브리지 + 일부 로컬 처리
- BLE 페어링 (Meta AI 앱 + 본인 앱)
- 백엔드 API 호출
- Apple Vision Framework (OCR, 객체 인식)
- Mock Device Kit 시뮬레이션 (개발 단계)

### Backend (MacBook 또는 Mac Mini)
**역할**: 두뇌
- API 키 보관 (.env)
- LLM 호출 (OpenAI/Claude)
- STT 호출 (Whisper API 또는 로컬)
- 비즈니스 로직 (프롬프트 엔지니어링, 컨텍스트 관리)
- 데이터 저장 (SQLite로 시작)

**호스팅**:
- 개발: 본인 MacBook + ngrok
- 프로덕션: Mac Mini home server OR Railway/Render ($5-10/월)

### LLM (외부 API 또는 로컬)
**클라우드**:
- **GPT-4o-mini**: default (빠름, 저렴)
- **Claude Haiku 4.5**: fallback (가장 빠른 TTFT)
- **GPT-4o Vision**: 이미지 분석 (메뉴, 표정 등)

**로컬 (옵션)**:
- **Qwen 2.5 32B**: Mac M2 Max 32GB에서 가능
- **Whisper large-v3**: STT 로컬

---

## Data Flow Examples

### Example 1: 영어 답변 제안 (Phase 1 핵심)

```
1. 상대방이 영어로 말함
   "Could you walk me through last week's metrics?"
   
2. 글래스 마이크 → BLE → iPhone
   
3. iPhone의 Native 앱 → 백엔드 /api/transcribe
   
4. 백엔드 → OpenAI Whisper API → 텍스트
   
5. 백엔드 → /api/suggest
   프롬프트: "한국인 워홀러 영어 답변 제안 2-3개"
   → GPT-4o-mini
   
6. 응답: ["Sure, let me pull up the dashboard...", 
         "Of course. The key takeaways were..."]
   
7. 백엔드 → iPhone → BLE → 글래스 디스플레이
   
총 latency 목표: <2초 (음성 끝난 후)
```

### Example 2: 메뉴판 OCR + 번역 (Phase 1 nice to have)

```
1. 사용자 Neural Band 제스처 → 사진 캡쳐
   
2. 글래스 카메라 → BLE → iPhone
   
3. iPhone Apple Vision Framework 로컬 OCR
   → "Maple Latte $5, Espresso $3, Cappuccino $4"
   
4. iPhone → 백엔드 /api/translate
   "한국어로 번역해줘"
   
5. 백엔드 → GPT-4o-mini → 응답
   
6. 글래스 디스플레이에 표시
   
총 latency: ~1초 (OCR 로컬이라 빠름)
```

---

## Security Boundaries

```
┌──────────────────────────────────────────┐
│  Public/Untrusted Zone                    │
│  - 글래스 ↔ 폰 (BLE, 페어링 인증)          │
│  - 폰 ↔ 백엔드 (HTTPS, JWT 인증)          │
└──────────────────────────────────────────┘

┌──────────────────────────────────────────┐
│  Trusted Zone (본인 백엔드)                │
│  - API 키 보관 (.env)                     │
│  - DB 접근                                │
│  - 외부 API 호출                          │
└──────────────────────────────────────────┘
```

**원칙**:
- API 키는 백엔드에만
- 클라이언트(폰/글래스)에는 절대 평문 키 X
- 백엔드와 통신은 HTTPS + 인증 토큰

---

## Performance Budget

각 단계별 latency 목표:

| 단계 | 목표 | 비고 |
|------|------|------|
| 음성 캡쳐 | <50ms | 마이크 → 디지털 |
| BLE 전송 (글래스→폰) | <100ms | BLE 5.3 |
| 폰 로컬 처리 (Apple Vision) | <300ms | OCR, 객체 인식 |
| 백엔드 처리 + LLM | <1000ms | GPT-4o-mini TTFT |
| BLE 전송 (폰→글래스) | <100ms | |
| 디스플레이 렌더 | <50ms | |
| **총 (실시간 use case)** | **<2초** | |

---

## Future Architecture (Phase 3+ B2B)

```
              ┌─────────────────────┐
              │   Admin Dashboard    │
              │   (Web App, React)   │
              └──────────┬──────────┘
                         │
                         ▼
              ┌─────────────────────┐
              │   Multi-tenant       │
              │   Backend            │
              │   (Korea cloud)      │
              └──────┬──────────┬───┘
                     │          │
            ┌────────┘          └────────┐
            ▼                            ▼
     [Worker 1 글래스]              [Worker N 글래스]
     (외국인 노동자)                 (외국인 노동자)
```

회사 1개 = 수십~수백 시트.
회사 데이터 격리 (multi-tenant).
회사별 커스텀 프롬프트/글로사리.
