import { complete as geminiComplete, completeVision, GEMINI_MODEL } from "../providers/gemini";
import { complete as openaiComplete, OPENAI_MODEL } from "../providers/openai";
import { complete as anthropicComplete, ANTHROPIC_MODEL } from "../providers/anthropic";
import {
  ENGLISH_COACH_SYSTEM,
  OBJECT_LABEL_SYSTEM,
  OBJECT_LABEL_USER,
  SUGGESTION_SCHEMA,
  TRANSLATOR_SYSTEM,
  buildUserMessage,
} from "../prompt";
import { parseObjects, parseSuggestions, parseTranslation } from "../parse";
import type { CompleteArgs, LabeledObject, Provider, Suggestion } from "../types";

// 설정된 프로바이더가 하나도 없을 때(키 미설정).
export class NoProviderError extends Error {}

interface ProviderImpl {
  complete: (args: CompleteArgs) => Promise<string>;
  model: string;
  envKey: string;
}

// 프로바이더 레지스트리. ORDER = fallback 우선순위 (무료 Gemini 우선).
const PROVIDERS: Record<Provider, ProviderImpl> = {
  gemini: { complete: geminiComplete, model: GEMINI_MODEL, envKey: "GEMINI_API_KEY" },
  openai: { complete: openaiComplete, model: OPENAI_MODEL, envKey: "OPENAI_API_KEY" },
  anthropic: { complete: anthropicComplete, model: ANTHROPIC_MODEL, envKey: "ANTHROPIC_API_KEY" },
};
const ORDER: Provider[] = ["gemini", "openai", "anthropic"];

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

// 키가 있는 프로바이더만 ORDER 순서대로 시도. parse 실패도 그 프로바이더의 실패로 보고 다음으로.
async function runWithFallback<T>(args: RunArgs<T>): Promise<RunResult<T>> {
  const attempts = ORDER.filter((provider) => process.env[PROVIDERS[provider].envKey]);
  if (attempts.length === 0) {
    throw new NoProviderError(
      "no LLM provider configured (set GEMINI_API_KEY, OPENAI_API_KEY, or ANTHROPIC_API_KEY)",
    );
  }

  const errors: string[] = [];
  for (const provider of attempts) {
    const { complete, model } = PROVIDERS[provider];
    const start = performance.now();
    try {
      const raw = await complete({ system: args.system, user: args.user, schema: args.schema });
      const result = args.parse(raw);
      return { result, provider, model, latencyMs: Math.round(performance.now() - start) };
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

export interface ObjectsResponse {
  objects: LabeledObject[];
  provider: Provider;
  model: string;
  latencyMs: number;
}

// 객체 라벨링은 멀티모달 → 현재 Gemini 전용 (무료 + 비전). fallback 없음.
export async function labelObjects(
  imageBase64: string,
  imageMimeType: string,
): Promise<ObjectsResponse> {
  if (!process.env.GEMINI_API_KEY) {
    throw new NoProviderError("GEMINI_API_KEY required for object labeling (vision)");
  }
  const start = performance.now();
  const raw = await completeVision({
    system: OBJECT_LABEL_SYSTEM,
    user: OBJECT_LABEL_USER,
    imageBase64,
    imageMimeType,
  });
  return {
    objects: parseObjects(raw),
    provider: "gemini",
    model: GEMINI_MODEL,
    latencyMs: Math.round(performance.now() - start),
  };
}
