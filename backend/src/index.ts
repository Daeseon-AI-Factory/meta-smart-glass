import { handleSuggest } from "./api/suggest";
import { handleTranslate } from "./api/translate";
import { handleLabel } from "./api/label";

const PORT = Number(process.env.PORT ?? 3001);

const server = Bun.serve({
  port: PORT,
  // 모든 인터페이스에 바인딩 → 실기기(폰)가 Mac의 LAN IP로 접근 가능.
  hostname: "0.0.0.0",
  routes: {
    "/health": () =>
      Response.json({
        status: "ok",
        service: "smart-glass-backend",
        timestamp: new Date().toISOString(),
      }),
    "/api/suggest": { POST: handleSuggest },
    "/api/translate": { POST: handleTranslate },
    "/api/label": { POST: handleLabel },
  },
  fetch() {
    return new Response("Not Found", { status: 404 });
  },
});

console.log(`Server running at http://localhost:${server.port}`);
