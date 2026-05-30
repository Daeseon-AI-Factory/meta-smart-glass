import { getSuggestions, NoProviderError } from "./llm";

interface SuggestBody {
  text?: unknown;
  context?: unknown;
}

// POST /api/suggest 핸들러. body: { text: string, context?: string }
export async function handleSuggest(req: Request): Promise<Response> {
  let body: SuggestBody;
  try {
    body = (await req.json()) as SuggestBody;
  } catch {
    return Response.json({ error: "invalid JSON body" }, { status: 400 });
  }

  const text = typeof body.text === "string" ? body.text.trim() : "";
  if (text === "") {
    return Response.json({ error: "field 'text' is required" }, { status: 400 });
  }
  const context = typeof body.context === "string" ? body.context : undefined;

  try {
    return Response.json(await getSuggestions(text, context));
  } catch (err) {
    if (err instanceof NoProviderError) {
      return Response.json({ error: err.message }, { status: 503 });
    }
    const detail = err instanceof Error ? err.message : "unknown error";
    return Response.json({ error: "suggestion failed", detail }, { status: 502 });
  }
}
