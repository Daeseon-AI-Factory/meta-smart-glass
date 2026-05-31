import Anthropic from "@anthropic-ai/sdk";
import type { CompleteArgs } from "../types";

// Fallback 프로바이더. Haiku 4.5 = 가장 빠른 TTFT.
// effort/extended thinking 미지원이라 붙이지 않는다(붙이면 400).
export const ANTHROPIC_MODEL = "claude-haiku-4-5";

export async function complete(args: CompleteArgs): Promise<string> {
  const client = new Anthropic({ apiKey: requireKey() });
  const base = {
    model: ANTHROPIC_MODEL,
    max_tokens: 400,
    temperature: 0.4,
    // 시스템 프롬프트는 안정적이라 캐시 후보로 표시.
    // 단 Haiku 4.5 최소 캐시 프리픽스는 4096토큰 — 현재 프롬프트는 그보다 짧아
    // 실제 캐시는 아직 안 걸린다(에러 아님). 프롬프트가 커지면 자동 적용.
    system: [
      { type: "text" as const, text: args.system, cache_control: { type: "ephemeral" as const } },
    ],
    messages: [{ role: "user" as const, content: args.user }],
  };
  const message = args.schema
    ? await client.messages.create({
        ...base,
        output_config: { format: { type: "json_schema", schema: args.schema.schema } },
      })
    : await client.messages.create(base);
  return message.content.find((block) => block.type === "text")?.text ?? "";
}

function requireKey(): string {
  const key = process.env.ANTHROPIC_API_KEY;
  if (!key) throw new Error("ANTHROPIC_API_KEY not set");
  return key;
}
