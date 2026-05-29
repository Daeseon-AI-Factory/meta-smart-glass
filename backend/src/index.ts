const PORT = Number(process.env.PORT ?? 3001);

const server = Bun.serve({
  port: PORT,
  routes: {
    "/health": () =>
      Response.json({
        status: "ok",
        service: "smart-glass-backend",
        timestamp: new Date().toISOString(),
      }),
  },
  fetch() {
    return new Response("Not Found", { status: 404 });
  },
});

console.log(`Server running at http://localhost:${server.port}`);
