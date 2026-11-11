import worker from "../src/index.ts";
import assert from "node:assert/strict";

const sessions = new Map();
const env = {
  NETEASE_ORIGIN: "https://netease.example",
  KUGOU_ORIGIN: "https://kugou.example",
  QISHUI_ORIGIN: "https://qishui.example",
  QQMUSIC_ORIGIN: "https://qqmusic.example",
  ALLOWED_ORIGIN: "https://app.una.example",
  GATEWAY_API_KEY: "test-key",
  QR_SESSIONS: {
    async get(key) { return sessions.has(key) ? JSON.parse(sessions.get(key)) : null; },
    async put(key, value) { sessions.set(key, value); },
    async delete(key) { sessions.delete(key); }
  }
,
  API_RATE_LIMITER: {
    async limit({ key }) { return { success: !key.endsWith(":198.51.100.8") }; }
  },
  QR_RATE_LIMITER: {
    async limit({ key }) { return { success: !key.endsWith(":198.51.100.8") }; }
  }
};

const originalFetch = globalThis.fetch;
globalThis.fetch = async (input, init = {}) => {
  const url = new URL(input);
  if (url.hostname === "go-api.example") console.log("GO_API_REQUEST", url.href);
  if (url.hostname === "go-api.example" && url.pathname === "/api/v1/music/search" && url.searchParams.get("q") === "oversized") return new Response("{}", { headers: { "content-length": String(5 * 1024 * 1024) } });
  if (url.hostname === "go-api.example" && url.pathname === "/api/v1/music/search" && url.searchParams.get("q") === "chunked") return new Response(new ReadableStream({ start(controller) { controller.enqueue(new Uint8Array(4 * 1024 * 1024)); controller.enqueue(new Uint8Array(1)); controller.close(); } }));
  if (url.hostname === "go-api.example" && url.pathname === "/api/v1/music/search") {
    assert.equal(url.searchParams.get("type"), "song");
    assert.ok(["netease", "qq", "kugou"].includes(url.searchParams.get("sources")));
    assert.equal(new Headers(init.headers).get("authorization"), "Bearer service-token");
    return Response.json({ code: 200, data: [{ id: "go-1", source: url.searchParams.get("sources"), name: "统一接口测试", artist: "测试歌手", album: "测试专辑", cover: "https://img.example/cover.jpg", duration: 180 }] });
  }
  if (url.hostname === "go-api.example" && url.pathname === "/api/v1/music/url") return Response.json({ code: 200, data: { url: "https://media.example/go.mp3" } });
  if (url.hostname === "go-api.example" && url.pathname === "/api/v1/music/lyric") return Response.json({ code: 200, data: { lyric: "[00:01.00]统一歌词" } });
  if (url.hostname === "go-api.example" && url.pathname === "/api/v1/playlist/user") return Response.json({ code: 200, data: { playlists: [{ id: "pl-1", name: "测试歌单" }] } });
  if (url.hostname === "go-api.example" && url.pathname === "/api/v1/playlist/detail") return Response.json({ code: 200, data: { songs: [{ id: "go-1", name: "统一接口测试", artist: "测试歌手" }] } });
  if (url.hostname === "go-api.example" && url.pathname.startsWith("/api/v1/system/qr_login/") && init.method === "POST") return Response.json({ code: 200, data: { key: `qr-${url.pathname.split("/").pop()}`, url: "https://login.example/go-qr", image_url: "data:image/png;base64,abc" } });
  if (url.hostname === "go-api.example" && url.pathname.startsWith("/api/v1/system/qr_login/")) return Response.json({ code: 200, data: { status: "success", cookie: "DO_NOT_LEAK" } });
  if (url.pathname === "/login/qr/key" && url.hostname === "netease.example") return Response.json({ data: { unikey: "ne-key" } });
  if (url.pathname === "/login/qr/key" && url.hostname === "kugou.example") return Response.json({ data: { qrcode: "kg-key" } });
  if (url.pathname === "/login/qr/create") return Response.json({ data: { url: "https://login.example/qr", qrurl: "https://login.example/qr", qrimg: "aGVsbG8=" } });
  if (url.pathname === "/login/qr/check" && url.hostname === "netease.example") return Response.json({ code: 803 }, { headers: { "set-cookie": "MUSIC_U=netease-cookie; Path=/" } });
  if (url.pathname === "/login/qr/check" && url.hostname === "kugou.example") return Response.json({ code: 4, data: { token: "kg-token" } });
  if (url.pathname === "/auth/qrcode") return Response.json({ data: { token: "soda-session", qrcode_index_url: "https://login.example/soda" } });
  if (url.pathname === "/auth/qrcode/status") return Response.json({ data: { status: "success", auth: { sessionid: "soda-cookie" } } });
  if (url.pathname === "/login/qrcode") return Response.json({ data: { qrsig: "qq-sig", ptqrtoken: "123", qrcode: "aGVsbG8=" } });
  if (url.pathname === "/login/checkQrcode") return Response.json({ data: { status: "DONE", credential: "qq-cookie" } });
  if (url.pathname === "/song/urls" && url.hostname === "qqmusic.example") return Response.json({ data: { tracks: [{ media: { playUrl: "https://media.example/qq.mp3" } }] } });
  if (url.pathname === "/search/general" && url.hostname === "qqmusic.example") return Response.json({ data: { body: { song: { list: [{ songmid: "qq-mid", songname: "QQ 测试歌曲", singer: [{ name: "QQ 测试歌手" }], albumname: "测试专辑" }] } } } });
  if (url.pathname === "/search" && url.hostname === "qishui.example" && url.searchParams.get("keyword") === "oversized") return new Response("{}", { headers: { "content-length": String(5 * 1024 * 1024) } });
  if (url.pathname === "/search" && url.hostname === "qishui.example" && url.searchParams.get("keyword") === "chunked") {
    return new Response(new ReadableStream({
      start(controller) {
        controller.enqueue(new Uint8Array(4 * 1024 * 1024));
        controller.enqueue(new Uint8Array(1));
        controller.close();
      }
    }));
  }
  if (url.pathname === "/search") return Response.json({ data: [{ id: "s1", name: "测试曲目", singer: "测试歌手", url: "https://media.example/audio.mp3" }] });
  if (url.pathname === "/lyric") return Response.json({ data: { lyric: "[00:01.00]测试歌词" } });
  return Response.json({ data: [] });
};

const call = (path, headers = { "x-una-gateway-key": "test-key", "cf-connecting-ip": "198.51.100.20" }) =>
  worker.fetch(new Request(`https://gateway.example${path}`, { headers }), env);

try {
  const unauthorized = await worker.fetch(new Request("https://gateway.example/health"), env);
  assert.equal(unauthorized.status, 401);
  const allowedOrigin = await worker.fetch(new Request("https://gateway.example/health", { headers: { "x-una-gateway-key": "test-key", origin: "https://app.una.example" } }), env);
  assert.equal(allowedOrigin.status, 200);
  assert.equal(allowedOrigin.headers.get("access-control-allow-origin"), "https://app.una.example");
  const blockedOrigin = await worker.fetch(new Request("https://gateway.example/health", { headers: { "x-una-gateway-key": "test-key", origin: "https://evil.example" } }), env);
  assert.equal(blockedOrigin.status, 403);
  const wrongMethod = await worker.fetch(new Request("https://gateway.example/una/v1/netease/search?keywords=test", { method: "POST", headers: { "x-una-gateway-key": "test-key" } }), env);
  assert.equal(wrongMethod.status, 405);

  const oversizedURL = await worker.fetch(new Request(`https://gateway.example/health?${"x".repeat(4100)}`, { headers: { "x-una-gateway-key": "test-key" } }), env);
  assert.equal(oversizedURL.status, 414);
  const oversizedQRBody = await worker.fetch(new Request("https://gateway.example/una/auth/qqmusic/qr/check?session=test", {
    method: "POST", headers: { "x-una-gateway-key": "test-key", "content-type": "application/json" }, body: JSON.stringify({ payload: "x".repeat(17 * 1024) })
  }), env);
  assert.equal(oversizedQRBody.status, 413);
  const invalidQRBody = await worker.fetch(new Request("https://gateway.example/una/auth/qqmusic/qr/check?session=test", {
    method: "POST", headers: { "x-una-gateway-key": "test-key", "content-type": "application/json" }, body: "[]"
  }), env);
  assert.equal(invalidQRBody.status, 400);

  const missingSecretEnv = { ...env, GATEWAY_API_KEY: undefined };
  const missingSecret = await worker.fetch(new Request("https://gateway.example/una/v1/netease/search?keywords=test", { headers: { "x-una-gateway-key": "test-key" } }), missingSecretEnv);
  assert.equal(missingSecret.status, 401);

  const health = await (await call("/health")).json();
  assert.equal(health.code, 0);
  assert.equal(health.data.providers.length, 3);

  assert.equal((await call("/not-found")).status, 404);

  const blockedQR = await call("/una/auth/netease/qr/create", {
    "x-una-gateway-key": "test-key",
    "cf-connecting-ip": "198.51.100.8"
  });
  assert.equal(blockedQR.status, 429);
  assert.equal(blockedQR.headers.get("retry-after"), "60");
  const blockedAPI = await call("/una/v1/netease/search?keywords=demo", {
    "x-una-gateway-key": "test-key",
    "cf-connecting-ip": "198.51.100.8"
  });
  assert.equal(blockedAPI.status, 429);

  const missingLimiterEnv = { ...env, API_RATE_LIMITER: undefined };
  const missingLimiter = await worker.fetch(new Request("https://gateway.example/una/v1/netease/search?keywords=demo", {
    headers: { "x-una-gateway-key": "test-key", "cf-connecting-ip": "198.51.100.20" }
  }), missingLimiterEnv);
  assert.equal(missingLimiter.status, 503);

  assert.equal((await call("/una/v1/netease/search?keywords=")).status, 400);
  assert.equal((await call("/una/v1/netease/search?keywords=" + "x".repeat(121))).status, 400);
  assert.equal((await call("/una/v1/netease/song/url?id=")).status, 400);
  assert.equal((await call("/una/v1/netease/search?keywords=test&limit=0")).status, 400);

  const neteaseQR = await (await call("/una/auth/netease/qr/create")).json();
  assert.equal(neteaseQR.session, "ne-key");
  assert.ok(neteaseQR.qrImage);
  const neteaseStatus = await (await call(`/una/auth/netease/qr/check?session=${neteaseQR.session}`)).json();
  assert.equal(neteaseStatus.status, "success");
  assert.equal(neteaseStatus.credential, "MUSIC_U=netease-cookie");

  const kugouQR = await (await call("/una/auth/kugou/qr/create")).json();
  assert.equal(kugouQR.session, "kg-key");
  const kugouStatus = await (await call(`/una/auth/kugou/qr/check?session=${kugouQR.session}`)).json();
  assert.equal(kugouStatus.status, "success");
  assert.equal(kugouStatus.credential, "kg-token");

  assert.equal((await call("/una/auth/qishui/qr/create")).status, 501);

  const qqQR = await (await call("/una/auth/qqmusic/qr/create")).json();
  assert.ok(qqQR.session);
  const qqStatus = await (await call(`/una/auth/qqmusic/qr/check?session=${qqQR.session}`)).json();
  assert.equal(qqStatus.credential, "qq-cookie");


  const qqSearch = await (await call("/una/v1/qqmusic/search?keywords=demo&limit=100")).json();
  assert.equal(qqSearch.data[0].id, "qq-mid");
  assert.equal(qqSearch.data[0].title, "QQ 测试歌曲");
  assert.equal(qqSearch.data[0].artist, "QQ 测试歌手");
  const qqSongURL = await (await call("/una/v1/qqmusic/song/url?id=qq-mid")).json();
  assert.equal(qqSongURL.data.url, "https://media.example/qq.mp3");
  const lyric = await (await call("/una/v1/netease/lyric?id=s1")).json();
  assert.equal(lyric.data.lyric, "[00:01.00]测试歌词");

  const sharedEnv = { ...env, GO_MUSIC_API_ORIGIN: "https://go-api.example", GO_MUSIC_API_TOKEN: "service-token" };
  const sharedCall = (path) => worker.fetch(new Request(`https://gateway.example${path}`, { headers: { "x-una-gateway-key": "test-key", "cf-connecting-ip": "198.51.100.20" } }), sharedEnv);
  for (const provider of ["netease", "qqmusic", "kugou"]) {
    const unified = await (await sharedCall(`/una/v1/${provider}/search?keywords=demo`)).json();
    console.log("UNIFIED_RESULT", provider, JSON.stringify(unified));
    assert.equal(unified.data[0].title, "统一接口测试");
    assert.equal(unified.data[0].provider, provider);
  }
  const sharedURL = await (await sharedCall("/una/v1/netease/song/url?id=go-1&name=统一接口测试&artist=测试歌手")).json();
  assert.equal(sharedURL.data.url, "https://media.example/go.mp3");
  const sharedLyric = await (await sharedCall("/una/v1/kugou/lyric?id=go-1&name=统一接口测试&artist=测试歌手")).json();
  assert.equal(sharedLyric.data.lyric, "[00:01.00]统一歌词");
  const sharedPlaylist = await (await sharedCall("/una/v1/qqmusic/playlist")).json();
  assert.equal(sharedPlaylist.data[0].name, "测试歌单");
  const sharedTracks = await (await sharedCall("/una/v1/netease/playlist/tracks?id=pl-1")).json();
  assert.equal(sharedTracks.data[0].title, "统一接口测试");
  const sharedQR = await (await sharedCall("/una/auth/netease/qr/create")).json();
  assert.equal(sharedQR.session, "go-qr-key");
  const sharedQRStatus = await (await sharedCall(`/una/auth/netease/qr/check?session=${sharedQR.session}`)).json();
  assert.equal(sharedQRStatus.status, "success");
  assert.equal("credential" in sharedQRStatus, false);

  console.log("Una gateway smoke tests passed");
} finally {
  globalThis.fetch = originalFetch;
}
