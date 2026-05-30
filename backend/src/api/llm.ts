import { complete as openaiComplete, OPENAI_MODEL } from "../providers/openai";
import { complete as anthropicComplete, ANTHROPIC_MODEL } from "../providers/anthropic";
import {
  ENGLISH_COACH_SYSTEM,
  SUGGESTION_SCHEMA,
  TRANSLATOR_SYSTEM,
  buildUserMessage,
} from "../prompt";
import { parseSuggestions, parseTranslation } from "../parse";
import type { Provider, Suggestion } from "../types";

// 설정된 프로바이더가 하나도 없을 때(키 미설정).
export class NoProviderError extends Error {}

interface RunArgs<T> {
  system: string;
  user: string;
  schema?: { name: string; schema: Record<string, unknown> };
  parse: (raw: string) => T;
}

interface RunResult<T> {
  result: T;
  provider: Provider;
  model: string;
  latencyMs: number;
}

// Primary(OpenAI) → 실패 시 Fallback(Anthropic). 키가 있는 프로바이더만 순서대로 시도.
// parse 실패도 그 프로바이더의 실패로 보고 다음으로 넘어간다.
async function runWithFallback<T>(args: RunArgs<T>): Promise<RunResult<T>> {
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
      const raw =
        provider === "openai"
          ? await openaiComplete({ system: args.system, user: args.user, schema: args.schema })
          : await anthropicComplete({ system: args.system, user: args.user, schema: args.schema });
      const result = args.parse(raw);
      return {
        result,
        provider,
        model: provider === "openai" ? OPENAI_MODEL : ANTHROPIC_MODEL,
        latencyMs: Math.round(performance.now() - start),
      };
    } catch (err) {
      errors.push(`${provider}: ${err instanceof Error ? err.message : String(err)}`);
    }
  }

  throw new Error(`all providers failed — ${errors.join("; ")}`);
}

export interface SuggestionsResponse {
  suggestions: Suggestion[];
  provider: Provider;
  model: string;
  latencyMs: number;
}

export async function getSuggestions(
  text: string,
  context?: string,
): Promise<SuggestionsResponse> {
  const { result, provider, model, latencyMs } = await runWithFallback({
    system: ENGLISH_COACH_SYSTEM,
    user: buildUserMessage(text, context),
    schema: { name: "suggestions", schema: SUGGESTION_SCHEMA },
    parse: parseSuggestions,
  });
  return { suggestions: result, provider, model, latencyMs };
}

export interface TranslationResponse {
  translation: string;
  provider: Provider;
  model: string;
  latencyMs: number;
}

export async function getTranslation(text: string): Promise<TranslationResponse> {
  const { result, provider, model, latencyMs } = await runWithFallback({
    system: TRANSLATOR_SYSTEM,
    user: text,
    parse: parseTranslation,
  });
  return { translation: result, provider, model, latencyMs };
}
