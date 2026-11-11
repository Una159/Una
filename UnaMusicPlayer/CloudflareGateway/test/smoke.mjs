import worker from "../src/index.ts";

const env = {
  NETEASE_ORIGIN: "https://netease.example",
  KUGOU_ORIGIN: "https://kugou.example",
  QISHUI_ORIGIN: "https://qishui.example",
  QQMUSIC_ORIGIN: "https://qqmusic.example",
  GATEWAY_API_KEY: "test-key",
  QR_SESSIONS: {
    async get() { return null; },
    async put() {},
    async delete() {}
  }
};

const unauthorized = await worker.fetch(
  new Request("https://gateway.example/health"),
  env
);
if (unauthorized.status !== 401) throw new Error("Gateway key must be enforced");

const health = await worker.fetch(
  new Request("https://gateway.example/health", {
    headers: { "x-una-gateway-key": "test-key" }
  }),
  env
);
const healthJSON = await health.json();
if (health.status !== 200 || healthJSON.data.providers.length !== 4) {
  throw new Error("Health response must list four configured providers");
}

const missing = await worker.fetch(
  new Request("https://gateway.example/not-found", {
    headers: { "x-una-gateway-key": "test-key" }
  }),
  env
);
if (missing.status !== 404) throw new Error("Unknown routes must return 404");

console.log("Una gateway smoke tests passed");
