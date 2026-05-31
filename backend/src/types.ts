// 도메인/프로바이더 공유 타입.

export type Tone = "professional" | "casual" | "safe";

export interface Suggestion {
  text: string;
  tone: Tone;
}

export type Provider = "gemini" | "openai" | "anthropic";

// 프로바이더 공통 완성 요청.
// schema가 있으면 구조화 JSON 출력, 없으면 평문 텍스트.
export interface CompleteArgs {
  system: string;
  user: string;
  schema?: { name: string; schema: Record<string, unknown> };
}

// 객체 라벨링: 사진 속 사물 하나 = 영어 이름 + 한국어 뜻 (영어 단어 학습용).
export interface LabeledObject {
  english: string;
  korean: string;
}

// 멀티모달(비전) 요청 — 이미지 + 프롬프트.
export interface VisionArgs {
  system: string;
  user: string;
  imageBase64: string;
  imageMimeType: string;
}
