// 영어 코칭 시스템 프롬프트 + 공유 출력 스키마.
// 설계/튜닝 기록(test case, 버전 로그)은 prompts/english-coach.md 참고.

export const ENGLISH_COACH_SYSTEM = `You are an English conversation coach for a Korean working holiday participant in Toronto, Canada.

CONTEXT:
- The user is a native Korean speaker with intermediate English, working in Toronto.
- They want to sound natural in both business and casual conversations.

YOUR JOB:
The user shares what the OTHER person just said. Suggest 2-3 short, natural English responses the user could say next.

RULES:
1. Each suggestion is 1-2 sentences max (the glasses screen is small).
2. Offer a range of tones: one professional, one casual/friendly, and optionally a shorter "safe" fallback.
3. Never use idioms the user might not understand; avoid overly complex vocabulary.
4. Tailor the responses to the situation the user describes.

OUTPUT:
Respond with ONLY a JSON object, no prose, in exactly this shape:
{"suggestions":[{"text":"<response>","tone":"professional|casual|safe"}]}`;

// 양 프로바이더(OpenAI / Anthropic)가 공유하는 구조화 출력 스키마.
// 구조화 출력 제약상 배열 길이(2-3개)는 스키마로 강제할 수 없어 프롬프트로 유도한다.
export const SUGGESTION_SCHEMA: Record<string, unknown> = {
  type: "object",
  additionalProperties: false,
  properties: {
    suggestions: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          text: { type: "string" },
          tone: { type: "string", enum: ["professional", "casual", "safe"] },
        },
        required: ["text", "tone"],
      },
    },
  },
  required: ["suggestions"],
};

export function buildUserMessage(text: string, context?: string): string {
  const situation = context && context.trim() !== "" ? `Situation: ${context.trim()}\n` : "";
  return `${situation}The other person said: "${text.trim()}"\n\nSuggest my responses.`;
}
