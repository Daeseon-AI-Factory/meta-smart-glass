import { getTranslation, NoProviderError } from "./llm";

interface TranslateBody {
  text?: unknown;
}

// POST /api/translate  body: { text: string }  (OCR/sign text → 한국어)
export async function handleTranslate(req: Request): Promise<Response> {
  let body: TranslateBody;
  try {
    body = (await req.json()) as TranslateBody;
  } catch {
    return Response.json({ error: "invalid JSON body" }, { status: 400 });
  }

  const text = typeof body.text === "string" ? body.text.trim() : "";
  if (text === "") {
    return Response.json({ error: "field 'text' is required" }, { status: 400 });
  }

  try {
    return Response.json(await getTranslation(text));
  } catch (err) {
    if (err instanceof NoProviderError) {
      return Response.json({ error: err.message }, { status: 503 });
    }
    const detail = err instanceof Error ? err.message : "unknown error";
    return Response.json({ error: "translation failed", detail }, { status: 502 });
  }
}
