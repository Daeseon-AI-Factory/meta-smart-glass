import { labelObjects, NoProviderError } from "./llm";

interface LabelBody {
  image?: unknown;
  mimeType?: unknown;
}

// POST /api/label  body: { image: <base64>, mimeType?: string }  → 사진 속 사물 영어 라벨
export async function handleLabel(req: Request): Promise<Response> {
  let body: LabelBody;
  try {
    body = (await req.json()) as LabelBody;
  } catch {
    return Response.json({ error: "invalid JSON body" }, { status: 400 });
  }

  const image = typeof body.image === "string" ? body.image : "";
  if (image === "") {
    return Response.json({ error: "field 'image' (base64) is required" }, { status: 400 });
  }
  const mimeType = typeof body.mimeType === "string" ? body.mimeType : "image/jpeg";

  try {
    return Response.json(await labelObjects(image, mimeType));
  } catch (err) {
    if (err instanceof NoProviderError) {
      return Response.json({ error: err.message }, { status: 503 });
    }
    const detail = err instanceof Error ? err.message : "unknown error";
    return Response.json({ error: "labeling failed", detail }, { status: 502 });
  }
}
