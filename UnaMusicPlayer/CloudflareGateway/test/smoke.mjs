import worker from "../src/index.ts";
import assert from "node:assert/strict";

const sessions = new Map();
const env = {
  NETEASE_ORIGIN: "https://netease.example",
  KUGOU_ORIGIN: "https://kugou.example",
  QISHUI_ORIGIN: "https://qishui.example",
  QQMUSIC_ORIGIN: "https://qqmusic.example",
  GATEWAY_API_KEY: "test-key",
  QR_SESSIONS: {
    async get(key) { return sessions.has(key) ? JSON.parse(sessions.get(key)) : null; },
    async put(key, value) { sessions.set(key, value); },
    async delete(key) { sessions.delete(key); }
  }
};

const originalFetch = globalThis.fetch;
globalThis.fetch = async (input) => {
  const url = new URL(input);
  if (url.pathname === "/login/qr/key" && url.hostname === "netease.example") return Response.json({ data: { unikey: "ne-key" } });
  if (url.pathname === "/login/qr/key" && url.hostname === "kugou.example") return Response.json({ data: { qrcode: "kg-key" } });
  if (url.pathname === "/login/qr/create") return Response.json({ data: { url: "https://login.example/qr", qrurl: "https://login.example/qr", qrimg: "aGVsbG8=" } });
  if (url.pathname === "/login/qr/check" && url.hostname === "netease.example") return Response.json({ code: 803 }, { headers: { "set-cookie": "MUSIC_U=netease-cookie; Path=/" } });
  if (url.pathname === "/login/qr/check" && url.hostname === "kugou.example") return Response.json({ code: 4, data: { token: "kg-token" } });
  if (url.pathname === "/auth/qrcode") return Response.json({ data: { token: "soda-session", qrcode_index_url: "https://login.example/soda" } });
  if (url.pathname === "/auth/qrcode/status") return Response.json({ data: { status: "success", auth: { sessionid: "soda-cookie" } } });
  if (url.pathname === "/login/qrcode") return Response.json({ data: { qrsig: "qq-sig", ptqrtoken: "123", qrcode: "aGVsbG8=" } });
  if (url.pathname === "/login/checkQrcode") return Response.json({ data: { status: "DONE", credential: "qq-cookie" } });
  if (url.pathname === "/search" && url.hostname === "qqmusic.example") return Response.json({ data: { body: { song: { list: [{ songmid: "qq-mid", songname: "QQ 测试歌曲", singer: [{ name: "QQ 测试歌手" }], albumname: "测试专辑" }] } } } });
  if (url.pathname === "/search") return Response.json({ data: [{ id: "s1", name: "测试曲目", singer: "测试歌手", url: "https://media.example/audio.mp3" }] });
  if (url.pathname === "/lyric") return Response.json({ data: { lyric: "[00:01.00]测试歌词" } });
  return Response.json({ data: [] });
};

const call = (path, headers = { "x-una-gateway-key": "test-key" }) =>
  worker.fetch(new Request(`https://gateway.example${path}`, { headers }), env);

try {
  const unauthorized = await worker.fetch(new Request("https://gateway.example/health"), env);
  assert.equal(unauthorized.status, 401);

  const missingSecretEnv = { ...env, GATEWAY_API_KEY: undefined };
  const missingSecret = await worker.fetch(new Request("https://gateway.example/una/v1/netease/search?keywords=test", { headers: { "x-una-gateway-key": "test-key" } }), missingSecretEnv);
  assert.equal(missingSecret.status, 401);

  const health = await (await call("/health")).json();
  assert.equal(health.code, 0);
  assert.equal(health.data.providers.length, 4);

  assert.equal((await call("/not-found")).status, 404);

  assert.equal((await call("/una/v1/netease/search?keywords=")).status, 400);
  assert.equal((await call("/una/v1/netease/search?keywords=" + "x".repeat(121))).status, 400);
  assert.equal((await call("/una/v1/netease/song/url?id=")).status, 400);
  assert.equal((await call("/una/v1/netease/search?keywords=test&limit=0")).status, 400);

  const neteaseQR = await (await call("/una/auth/netease/qr/create")).json();
  assert.equal(neteaseQR.session, "ne-key");
  assert.ok(neteaseQR.qrImage);
  const neteaseStatus = await (await call(`/una/auth/netease/qr/check?session=${neteaseQR.session}`)).json();
  assert.equal(neteaseStatus.status, "success");
  assert.equal(neteaseStatus.credential, "MUSIC_U=netease-cookie; Path=/");

  const kugouQR = await (await call("/una/auth/kugou/qr/create")).json();
  assert.equal(kugouQR.session, "kg-key");
  const kugouStatus = await (await call(`/una/auth/kugou/qr/check?session=${kugouQR.session}`)).json();
  assert.equal(kugouStatus.status, "success");
  assert.equal(kugouStatus.credential, "kg-token");

  const sodaQR = await (await call("/una/auth/qishui/qr/create")).json();
  assert.equal(sodaQR.session, "soda-session");
  const sodaStatus = await (await call(`/una/auth/qishui/qr/check?session=${sodaQR.session}`)).json();
  assert.equal(sodaStatus.credential, "soda-cookie");

  const qqQR = await (await call("/una/auth/qqmusic/qr/create")).json();
  assert.ok(qqQR.session);
  const qqStatus = await (await call(`/una/auth/qqmusic/qr/check?session=${qqQR.session}`)).json();
  assert.equal(qqStatus.credential, "qq-cookie");

  const search = await (await call("/una/v1/qishui/search?keywords=demo")).json();
  assert.equal(search.data[0].title, "测试曲目");

  const qqSearch = await (await call("/una/v1/qqmusic/search?keywords=demo&limit=100")).json();
  assert.equal(qqSearch.data[0].id, "qq-mid");
  assert.equal(qqSearch.data[0].title, "QQ 测试歌曲");
  assert.equal(qqSearch.data[0].artist, "QQ 测试歌手");
  const lyric = await (await call("/una/v1/qishui/lyric?id=s1")).json();
  assert.equal(lyric.data.lyric, "[00:01.00]测试歌词");

  console.log("Una gateway smoke tests passed");
} finally {
  globalThis.fetch = originalFetch;
}
