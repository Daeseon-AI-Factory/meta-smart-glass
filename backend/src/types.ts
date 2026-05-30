// 영어 답변 제안 도메인 타입 — 프로바이더/오케스트레이터/HTTP 계층이 공유.

export type Tone = "professional" | "casual" | "safe";

export interface Suggestion {
  text: string;
  tone: Tone;
}

export type Provider = "openai" | "anthropic";

export interface SuggestResult {
  suggestions: Suggestion[];
  model: string;
}
