import { suggestWithOpenAI } from "../providers/openai";
import { suggestWithAnthropic } from "../providers/anthropic";
import type { Provider, SuggestResult } from "../types";

export interface SuggestionsResponse extends SuggestResult {
  provider: Provider;
  latencyMs: number;
}

// 설정된 프로바이더가 하나도 없을 때(키 미설정).
export class NoProviderError extends Error {}

// Primary(OpenAI GPT-4o-mini) → 실패 시 Fallback(Anthropic Haiku 4.5).
// 키가 있는 프로바이더만 순서대로 시도한다.
export async function getSuggestions(
  text: string,
  context?: string,
): Promise<SuggestionsResponse> {
  const attempts: Provider[] = [];
  if (process.env.OPENAI_API_KEY) attempts.push("openai");
  if (process.env.ANTHROPIC_API_KEY) attempts.push("anthropic");

  if (attempts.length === 0) {
    throw new NoProviderError(
      "no LLM provider configured (set OPENAI_API_KEY or ANTHROPIC_API_KEY)",
    );
  }

  const errors: string[] = [];
  for (const provider of attempts) {
    const start = performance.now();
    try {
      const result =
        provider === "openai"
          ? await suggestWithOpenAI(text, context)
          : await suggestWithAnthropic(text, context);
      return { ...result, provider, latencyMs: Math.round(performance.now() - start) };
    } catch (err) {
      errors.push(`${provider}: ${err instanceof Error ? err.message : String(err)}`);
    }
  }

  throw new Error(`all providers failed — ${errors.join("; ")}`);
}
