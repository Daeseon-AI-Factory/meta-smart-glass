import { GoogleGenAI } from "@google/genai";
import type { CompleteArgs, VisionArgs } from "../types";

// Primary 프로바이더 (무료 티어). 빠르고 번역 강함.
const GEMINI_MODEL_ID = "gemini-2.5-flash";
export const GEMINI_MODEL = GEMINI_MODEL_ID;

export async function complete(args: CompleteArgs): Promise<string> {
  const ai = new GoogleGenAI({ apiKey: requireKey() });
  const response = await ai.models.generateContent({
    model: GEMINI_MODEL_ID,
    contents: args.user,
    config: {
      systemInstruction: args.system,
      temperature: 0.4,
      maxOutputTokens: 1024,
      // Gemini 2.5는 thinking 기본 ON → 단순 작업 + <500ms 목표라 끈다(저지연 + 토큰 절약).
      thinkingConfig: { thinkingBudget: 0 },
      // schema가 있으면 JSON 강제. shape는 프롬프트가 명시 + 관대한 파서가 검증(defense-in-depth).
      responseMimeType: args.schema ? "application/json" : undefined,
    },
  });
  return response.text ?? "";
}

// 멀티모달: 이미지 + 프롬프트 → 텍스트(JSON). 객체 라벨링용.
export async function completeVision(args: VisionArgs): Promise<string> {
  const ai = new GoogleGenAI({ apiKey: requireKey() });
  const response = await ai.models.generateContent({
    model: GEMINI_MODEL_ID,
    contents: [
      { inlineData: { mimeType: args.imageMimeType, data: args.imageBase64 } },
      { text: args.user },
    ],
    config: {
      systemInstruction: args.system,
      temperature: 0.2,
      maxOutputTokens: 1024,
      thinkingConfig: { thinkingBudget: 0 },
      responseMimeType: "application/json",
    },
  });
  return response.text ?? "";
}

function requireKey(): string {
  const key = process.env.GEMINI_API_KEY;
  if (!key) throw new Error("GEMINI_API_KEY not set");
  return key;
}
