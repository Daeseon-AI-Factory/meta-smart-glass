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
