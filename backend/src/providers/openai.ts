import OpenAI from "openai";
import type { CompleteArgs } from "../types";

// Primary 프로바이더. 일관성 우선이라 temperature 낮게(0.4).
export const OPENAI_MODEL = "gpt-4o-mini";

// 범용 완성. schema가 있으면 strict json_schema, 없으면 평문 텍스트.
export async function complete(args: CompleteArgs): Promise<string> {
  const client = new OpenAI({ apiKey: requireKey() });
  const base = {
    model: OPENAI_MODEL,
    temperature: 0.4,
    max_completion_tokens: 400,
    messages: [
      { role: "system" as const, content: args.system },
      { role: "user" as const, content: args.user },
    ],
  };
  const completion = args.schema
    ? await client.chat.completions.create({
        ...base,
        response_format: {
          type: "json_schema",
          json_schema: { name: args.schema.name, strict: true, schema: args.schema.schema },
        },
      })
    : await client.chat.completions.create(base);
  return completion.choices[0]?.message.content ?? "";
}

function requireKey(): string {
  const key = process.env.OPENAI_API_KEY;
  if (!key) throw new Error("OPENAI_API_KEY not set");
  return key;
}
