import type { BoundingBox, LabeledObject, Suggestion, Tone } from "./types";

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

// 번역은 평문 출력. 비어있으면 실패로 보고 fallback 유도.
export function parseTranslation(raw: string): string {
  const text = raw.trim();
  if (text === "") throw new Error("empty translation");
  return text;
}

// 객체 라벨링 응답 → {english, korean}[] 추출 + 검증.
export function parseObjects(raw: string): LabeledObject[] {
  const parsed = JSON.parse(extractJsonObject(raw)) as { objects?: unknown };
  if (!Array.isArray(parsed.objects)) {
    throw new Error("response has no 'objects' array");
  }
  const objects = parsed.objects
    .map(toLabeledObject)
    .filter((o): o is LabeledObject => o !== null);
  if (objects.length === 0) {
    throw new Error("no valid objects in response");
  }
  return objects;
}

function toLabeledObject(value: unknown): LabeledObject | null {
  if (typeof value !== "object" || value === null) return null;
  const { english, korean, box } = value as {
    english?: unknown;
    korean?: unknown;
    box?: unknown;
  };
  if (typeof english !== "string" || english.trim() === "") return null;
  return {
    english: english.trim(),
    korean: typeof korean === "string" ? korean.trim() : "",
    box: toBox(box),
  };
}

// Gemini box [ymin, xmin, ymax, xmax] (0-1000) → {x,y,width,height} 정규화 0-1.
function toBox(value: unknown): BoundingBox | undefined {
  if (!Array.isArray(value) || value.length !== 4) return undefined;
  const nums = value.map(Number);
  if (nums.some((n) => !Number.isFinite(n))) return undefined;
  const [ymin, xmin, ymax, xmax] = nums as [number, number, number, number];
  const width = Math.abs(xmax - xmin) / 1000;
  const height = Math.abs(ymax - ymin) / 1000;
  if (width <= 0 || height <= 0) return undefined;
  return {
    x: Math.min(xmin, xmax) / 1000,
    y: Math.min(ymin, ymax) / 1000,
    width,
    height,
  };
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
