import Anthropic from "@anthropic-ai/sdk";
import { ENGLISH_COACH_SYSTEM, SUGGESTION_SCHEMA, buildUserMessage } from "../prompt";
import { parseSuggestions } from "../parse";
import type { SuggestResult } from "../types";

// Fallback 프로바이더. Haiku 4.5 = 가장 빠른 TTFT.
// effort/extended thinking 미지원이라 붙이지 않는다(붙이면 400).
const MODEL = "claude-haiku-4-5";

export async function suggestWithAnthropic(
  text: string,
  context: string | undefined,
  signal?: AbortSignal,
): Promise<SuggestResult> {
  const client = new Anthropic({ apiKey: requireKey() });
  const message = await client.messages.create(
    {
      model: MODEL,
      max_tokens: 400,
      temperature: 0.4,
      // 시스템 프롬프트는 안정적이라 캐시 후보로 표시.
      // 단 Haiku 4.5의 최소 캐시 프리픽스는 4096토큰 — 현재 프롬프트는 그보다 짧아
      // 실제 캐시는 아직 안 걸린다(에러 아님). 프롬프트가 커지면 자동 적용.
      system: [
        { type: "text", text: ENGLISH_COACH_SYSTEM, cache_control: { type: "ephemeral" } },
      ],
      messages: [{ role: "user", content: buildUserMessage(text, context) }],
      output_config: { format: { type: "json_schema", schema: SUGGESTION_SCHEMA } },
    },
    { signal },
  );
  const raw = message.content.find((block) => block.type === "text")?.text ?? "";
  return { suggestions: parseSuggestions(raw), model: MODEL };
}

function requireKey(): string {
  const key = process.env.ANTHROPIC_API_KEY;
  if (!key) throw new Error("ANTHROPIC_API_KEY not set");
  return key;
}
