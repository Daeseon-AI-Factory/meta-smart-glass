import type { Suggestion, Tone } from "./types";

const TONES: readonly Tone[] = ["professional", "casual", "safe"];

// LLM 응답 텍스트에서 suggestions 추출 + 검증.
// 구조화 출력이면 순수 JSON이지만, 혹시 모를 prose를 대비해
// 첫 '{' ~ 마지막 '}' 구간을 관대하게 파싱한다(defense-in-depth).
export function parseSuggestions(raw: string): Suggestion[] {
  const parsed = JSON.parse(extractJsonObject(raw)) as { suggestions?: unknown };
  if (!Array.isArray(parsed.suggestions)) {
    throw new Error("response has no 'suggestions' array");
  }
  const suggestions = parsed.suggestions
    .map(toSuggestion)
    .filter((s): s is Suggestion => s !== null);
  if (suggestions.length === 0) {
    throw new Error("no valid suggestions in response");
  }
  return suggestions;
}

function extractJsonObject(raw: string): string {
  const start = raw.indexOf("{");
  const end = raw.lastIndexOf("}");
  if (start === -1 || end === -1 || end < start) {
    throw new Error("no JSON object found in response");
  }
  return raw.slice(start, end + 1);
}

function toSuggestion(value: unknown): Suggestion | null {
  if (typeof value !== "object" || value === null) return null;
  const { text, tone } = value as { text?: unknown; tone?: unknown };
  if (typeof text !== "string" || text.trim() === "") return null;
  const normalizedTone: Tone = TONES.includes(tone as Tone) ? (tone as Tone) : "safe";
  return { text: text.trim(), tone: normalizedTone };
}
