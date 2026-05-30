import OpenAI from "openai";
import { ENGLISH_COACH_SYSTEM, SUGGESTION_SCHEMA, buildUserMessage } from "../prompt";
import { parseSuggestions } from "../parse";
import type { SuggestResult } from "../types";

// Primary 프로바이더. 일관성 우선이라 temperature는 낮게(0.4).
const MODEL = "gpt-4o-mini";

export async function suggestWithOpenAI(
  text: string,
  context: string | undefined,
  signal?: AbortSignal,
): Promise<SuggestResult> {
  // 키 없는 환경에서 import만으로 깨지지 않도록 호출 시점에 클라이언트 생성.
  const client = new OpenAI({ apiKey: requireKey() });
  const completion = await client.chat.completions.create(
    {
      model: MODEL,
      temperature: 0.4,
      max_completion_tokens: 300,
      messages: [
        { role: "system", content: ENGLISH_COACH_SYSTEM },
        { role: "user", content: buildUserMessage(text, context) },
      ],
      response_format: {
        type: "json_schema",
        json_schema: { name: "suggestions", strict: true, schema: SUGGESTION_SCHEMA },
      },
    },
    { signal },
  );
  const raw = completion.choices[0]?.message.content ?? "";
  return { suggestions: parseSuggestions(raw), model: MODEL };
}

function requireKey(): string {
  const key = process.env.OPENAI_API_KEY;
  if (!key) throw new Error("OPENAI_API_KEY not set");
  return key;
}
