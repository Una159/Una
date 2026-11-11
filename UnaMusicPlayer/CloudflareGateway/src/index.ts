export interface Env {
  NETEASE_ORIGIN?: string;
  KUGOU_ORIGIN?: string;
  QISHUI_ORIGIN?: string;
  QQMUSIC_ORIGIN?: string;
  ALLOWED_ORIGIN?: string;
  GATEWAY_API_KEY?: string;
  QR_SESSIONS?: KVNamespace;
}

type Provider = "netease" | "kugou" | "qishui" | "qqmusic";
type RouteKind = "search" | "song-url" | "lyric" | "playlist" | "playlist-tracks" | "qr-create" | "qr-check";
const PROVIDERS: Provider[] = ["netease", "kugou", "qishui", "qqmusic"];
const JSON_HEADERS = { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" };

function json(data: unknown, status = 200, extra: HeadersInit = {}) {
  return new Response(JSON.stringify(data), { status, headers: { ...JSON_HEADERS, ...extra } });
}
function providerOrigin(env: Env, provider: Provider): string | undefined {
  const value = ({ netease: env.NETEASE_ORIGIN, kugou: env.KUGOU_ORIGIN, qishui: env.QISHUI_ORIGIN, qqmusic: env.QQMUSIC_ORIGIN })[provider];
  if (!value) return undefined;
  try { const u = new URL(value); return u.protocol === "https:" ? u.origin : undefined; } catch { return undefined; }
}
function first(obj: any, keys: string[]): any {
  for (const key of keys) if (obj?.[key] !== undefined && obj?.[key] !== null) return obj[key];
  return undefined;
}
function rowsFrom(payload: any): any[] {
  const candidates = [
    payload?.data, payload?.result?.songs, payload?.result?.playlists,
    payload?.songs, payload?.list, payload?.playlist,
    payload?.data?.list, payload?.data?.songs, payload?.data?.info,
    payload?.data?.lists, payload?.data?.playlists, payload?.data?.playlist,
    payload?.data?.body?.song?.list, payload?.body?.song?.list,
    payload?.data?.result?.songs, payload?.data?.result?.playlists
  ];
  return candidates.find(Array.isArray) ?? [];
}
function normalizeTrack(row: any, provider: Provider) {
  return {
    id: String(first(row, ["id", "songId", "songid", "mid", "songmid", "hash", "track_id", "trackId"]) ?? ""),
    title: String(first(row, ["title", "name", "songName", "songname"]) ?? "未知歌曲"),
    artist: String(first(row, ["artist", "singer", "artistName", "author", "singername"]) ?? "未知歌手"),
    album: first(row, ["album", "albumName", "albumname"]) ?? null,
    duration: Number(first(row, ["duration", "interval", "dt"]) ?? 0) || null,
    artworkURL: first(row, ["artworkURL", "artwork", "picUrl", "cover", "coverUrl", "albummid"]) ?? null,
    pageURL: first(row, ["pageURL", "shareUrl", "webUrl", "url"]) ?? null,
    streamURL: first(row, ["streamURL", "playUrl", "url", "audio", "media_url"]) ?? null,
    provider
  };
}
function normalizePlaylist(row: any) {
  return {
    id: String(first(row, ["id", "playlist_id", "listid", "dissid", "tid"]) ?? ""),
    name: String(first(row, ["name", "title", "dissname", "playlist_name"]) ?? "未命名歌单"),
    creator: first(row, ["creator", "nickname", "username", "author"]) ?? null,
    coverURL: first(row, ["coverURL", "cover", "picUrl", "imgurl", "logo"]) ?? null,
    trackCount: Number(first(row, ["trackCount", "track_count", "songnum", "song_count"]) ?? 0)
  };
}
function upstreamPath(provider: Provider, kind: RouteKind, q: URLSearchParams): { path: string; method: string; body?: unknown } {
  const id = q.get("id") ?? "";
  const keywords = q.get("keywords") ?? "";
  const limit = q.get("limit") ?? "20";
  switch (provider) {
    case "netease":
      if (kind === "search") return { path: `/cloudsearch?keywords=${encodeURIComponent(keywords)}&type=1&limit=${encodeURIComponent(limit)}`, method: "GET" };
      if (kind === "song-url") return { path: `/song/url/v1?id=${encodeURIComponent(id)}&level=standard`, method: "GET" };
      if (kind === "lyric") return { path: `/lyric?id=${encodeURIComponent(id)}`, method: "GET" };
      if (kind === "playlist") return { path: `/user/playlist?uid=${encodeURIComponent(q.get("uid") ?? "")}&limit=${encodeURIComponent(limit)}`, method: "GET" };
      if (kind === "playlist-tracks") return { path: `/playlist/track/all?id=${encodeURIComponent(id)}&limit=${encodeURIComponent(limit)}`, method: "GET" };
      break;
    case "kugou":
      if (kind === "search") return { path: `/search?keywords=${encodeURIComponent(keywords)}&pagesize=${encodeURIComponent(limit)}&type=song`, method: "GET" };
      if (kind === "song-url") return { path: `/song/url?hash=${encodeURIComponent(id)}&quality=320`, method: "GET" };
      if (kind === "lyric") return { path: `/search/lyric?hash=${encodeURIComponent(id)}`, method: "GET" };
      if (kind === "playlist") return { path: `/user/playlist`, method: "GET" };
      if (kind === "playlist-tracks") return { path: `/playlist/track/all?id=${encodeURIComponent(id)}&pagesize=${encodeURIComponent(limit)}`, method: "GET" };
      break;
    case "qishui":
      if (kind === "search") return { path: `/search?keyword=${encodeURIComponent(keywords)}&count=${encodeURIComponent(limit)}`, method: "GET" };
      if (kind === "song-url") return { path: `/download/url?track_id=${encodeURIComponent(id)}`, method: "GET" };
      if (kind === "lyric") return { path: `/lyric?track_id=${encodeURIComponent(id)}`, method: "GET" };
      if (kind === "playlist") return { path: `/me/playlists`, method: "POST", body: {} };
      if (kind === "playlist-tracks") return { path: `/playlist/detail?playlist_id=${encodeURIComponent(id)}`, method: "GET" };
      break;
    case "qqmusic":
      if (kind === "search") return { path: `/search/general`, method: "POST", body: { keyword: keywords, page: Number(q.get("page") ?? 1), num: Number(limit) } };
      if (kind === "song-url") return { path: `/song/urls?mids=${encodeURIComponent(id)}&type=M500`, method: "GET" };
      if (kind === "lyric") return { path: `/song/lyric?mid=${encodeURIComponent(id)}&decode=1`, method: "GET" };
      if (kind === "playlist") return { path: `/user/songlist?uin=${encodeURIComponent(q.get("uin") ?? "")}&page=1&num=${encodeURIComponent(limit)}`, method: "GET" };
      if (kind === "playlist-tracks") return { path: `/songlist/detail?id=${encodeURIComponent(id)}`, method: "GET" };
      break;
  }
  return { path: "/health", method: "GET" };
}
function qrRoute(provider: Provider, kind: "qr-create" | "qr-check", q: URLSearchParams, body: any) {
  if (provider === "netease" || provider === "kugou") {
    if (kind === "qr-create") return { path: `/login/qr/key?timestamp=${Date.now()}`, method: "GET" as const };
    return { path: `/login/qr/check?key=${encodeURIComponent(q.get("session") ?? "")}&timestamp=${Date.now()}`, method: "GET" as const };
  }
  if (provider === "qishui") {
    if (kind === "qr-create") return { path: `/auth/qrcode`, method: "GET" as const };
    return { path: `/auth/qrcode/status`, method: "POST" as const, body: { token: q.get("session") ?? "" } };
  }
  if (kind === "qr-create") return { path: `/login/qrcode`, method: "POST" as const, body: {} };
  return { path: `/login/checkQrcode`, method: "POST" as const, body: { ...(body ?? {}), token: q.get("session") ?? body?.token ?? "" } };
}
async function callUpstream(origin: string, path: string, method: string, incoming: Request, body?: unknown) {
  const url = new URL(path, origin);
  const headers = new Headers({ accept: "application/json" });
  for (const name of ["cookie", "authorization", "user-agent", "x-requested-with"]) {
    const value = incoming.headers.get(name); if (value) headers.set(name, value);
  }
  let payload: string | undefined;
  if (body !== undefined) { headers.set("content-type", "application/json"); payload = JSON.stringify(body); }
  const response = await fetch(url, { method, headers, body: method === "GET" ? undefined : payload, redirect: "manual" });
  const text = await response.text();
  const responseHeaders = new Headers({ "content-type": response.headers.get("content-type") ?? "application/json", "cache-control": "no-store" });
  const setCookie = response.headers.get("set-cookie");
  if (setCookie) responseHeaders.set("set-cookie", setCookie);
  return new Response(text, { status: response.status, headers: responseHeaders });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const corsOrigin = env.ALLOWED_ORIGIN ?? "null";
    const cors = { "access-control-allow-origin": corsOrigin, "access-control-allow-methods": "GET,POST,OPTIONS", "access-control-allow-headers": "content-type,authorization,cookie,x-una-gateway-key", "vary": "origin" };
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
    // Fail closed: never expose provider adapters when the gateway secret is missing or mismatched.
    if (!env.GATEWAY_API_KEY || request.headers.get("x-una-gateway-key") !== env.GATEWAY_API_KEY) return json({ code: 401, message: "unauthorized" }, 401, cors);
    if (url.pathname === "/health") return json({ code: 0, message: "ok", data: { service: "una-music-gateway", providers: PROVIDERS.map(p => ({ id: p, configured: !!providerOrigin(env, p) })) } }, 200, cors);

    const authMatch = url.pathname.match(/^\/una\/auth\/(netease|kugou|qishui|qqmusic)\/qr\/(create|check)$/);
    const legacyNeteaseQRMatch = url.pathname.match(/^\/login\/qr\/(key|create|check)$/);
    const apiMatch = url.pathname.match(/^\/una\/v1\/(netease|kugou|qishui|qqmusic)\/(search|song\/url|lyric|playlist|playlist\/tracks)$/);
    if (!authMatch && !legacyNeteaseQRMatch && !apiMatch) return json({ code: 404, message: "route_not_found" }, 404, cors);
    const provider = (authMatch?.[1] ?? (legacyNeteaseQRMatch ? "netease" : apiMatch?.[1])) as Provider;
    const origin = providerOrigin(env, provider);
    if (!origin) return json({ code: 503, message: `${provider}_adapter_not_configured` }, 503, cors);

    try {
      let target: { path: string; method: string; body?: unknown };
      if (legacyNeteaseQRMatch) {
        target = { path: url.pathname + url.search, method: "GET" };
      } else if (authMatch) {
        const body = request.method === "POST" ? await request.clone().json().catch(() => ({})) : {};
        if (provider === "kugou" && authMatch[2] === "create") {
          const keyResponse = await callUpstream(origin, `/login/qr/key?timestamp=${Date.now()}`, "GET", request);
          const keyJSON: any = await keyResponse.json().catch(() => ({}));
          const key = first(keyJSON?.data, ["qrcode", "key"]) ?? first(keyJSON, ["qrcode", "key"]);
          if (!key) return json({ code: 502, message: "kugou_qr_key_missing" }, 502, cors);
          const createResponse = await callUpstream(origin, `/login/qr/create?key=${encodeURIComponent(String(key))}&qrimg=true&timestamp=${Date.now()}`, "GET", request);
          const createJSON: any = await createResponse.json().catch(() => ({}));
          const data = createJSON?.data ?? createJSON;
          return json({ session: String(key), qrUrl: first(data, ["url", "qrurl", "qrcode_url"]), qrImage: first(data, ["qrimg", "qrcode", "qrImage"]), status: "waiting" }, createResponse.status, cors);
        }
        if (provider === "netease" && authMatch[2] === "create") {
          const keyResponse = await callUpstream(origin, `/login/qr/key?timestamp=${Date.now()}`, "GET", request);
          const keyJSON: any = await keyResponse.json().catch(() => ({}));
          const key = first(keyJSON?.data, ["unikey", "key"]) ?? first(keyJSON, ["unikey", "key"]);
          if (!key) return json({ code: 502, message: "netease_qr_key_missing" }, 502, cors);
          const createResponse = await callUpstream(origin, `/login/qr/create?key=${encodeURIComponent(String(key))}&qrimg=true&timestamp=${Date.now()}`, "GET", request);
          const createJSON: any = await createResponse.json().catch(() => ({}));
          const data = createJSON?.data ?? createJSON;
          return json({ session: String(key), qrUrl: first(data, ["qrurl", "url", "qrUrl"]), qrImage: first(data, ["qrimg", "qrImage", "image"]), status: "waiting" }, createResponse.status, cors);
        }
        target = qrRoute(provider, authMatch[2] === "create" ? "qr-create" : "qr-check", url.searchParams, body);
      } else {
        const kind = ({ search: "search", "song/url": "song-url", lyric: "lyric", playlist: "playlist", "playlist/tracks": "playlist-tracks" } as Record<string, RouteKind>)[apiMatch![2]];
        target = upstreamPath(provider, kind, url.searchParams);
      }
      if (authMatch && provider === "qqmusic" && authMatch[2] === "check") {
        const session = url.searchParams.get("session") ?? "";
        if (!env.QR_SESSIONS) return json({ code: 503, message: "qr_session_store_not_configured" }, 503, cors);
        const saved = await env.QR_SESSIONS.get(`qq:${session}`, "json") as any;
        if (!saved) return json({ status: "expired", message: "二维码已过期，请重新生成" }, 200, cors);
        target.body = { ...(saved ?? {}), ...(target.body as object ?? {}) };
      }
      if (!authMatch && apiMatch?.[2] === "playlist" && provider === "netease" && !url.searchParams.get("uid")) {
        const accountResponse = await callUpstream(origin, "/user/account", "GET", request);
        const account: any = await accountResponse.json().catch(() => ({}));
        const uid = first(account?.profile, ["userId", "user_id"]) ?? first(account?.account, ["id", "userId"]);
        if (uid) target.path = `/user/playlist?uid=${encodeURIComponent(String(uid))}&limit=${encodeURIComponent(url.searchParams.get("limit") ?? "30")}`;
      }
      if (!authMatch && apiMatch?.[2] === "playlist" && provider === "qqmusic" && !url.searchParams.get("uin")) {
        const selfResponse = await callUpstream(origin, "/user/self", "GET", request);
        const self: any = await selfResponse.json().catch(() => ({}));
        const uin = first(self?.data, ["uin", "musicid", "id"]) ?? first(self, ["uin", "musicid"]);
        if (uin) target.path = `/user/songlist?uin=${encodeURIComponent(String(uin))}&page=1&num=${encodeURIComponent(url.searchParams.get("limit") ?? "30")}`;
      }
      const upstream = await callUpstream(origin, target.path, target.method, request, target.body);
      if (!upstream.ok) return json({ code: upstream.status, message: "upstream_error", provider }, upstream.status, cors);
      if (legacyNeteaseQRMatch) {
        const headers = new Headers({ ...cors, "content-type": upstream.headers.get("content-type") ?? "application/json", "cache-control": "no-store" });
        const setCookie = upstream.headers.get("set-cookie");
        if (setCookie) headers.set("set-cookie", setCookie);
        headers.set("access-control-expose-headers", "set-cookie");
        return new Response(await upstream.text(), { status: upstream.status, headers });
      }
      const raw = await upstream.text();
      let parsed: any; try { parsed = JSON.parse(raw); } catch { return json({ code: 502, message: "upstream_invalid_json", provider }, 502, cors); }
      if (!authMatch && provider === "kugou" && apiMatch?.[2] === "lyric") {
        const lyricMeta = first(parsed?.data, ["candidates", "info", "list"]) ?? first(parsed, ["candidates", "info", "list"]);
        const candidate = Array.isArray(lyricMeta) ? lyricMeta[0] : lyricMeta;
        const lyricID = first(candidate, ["id", "lyrics_id"]);
        const accessKey = first(candidate, ["accesskey", "accessKey"]);
        if (lyricID && accessKey) {
          const lyricResponse = await callUpstream(origin, `/lyric?id=${encodeURIComponent(String(lyricID))}&accesskey=${encodeURIComponent(String(accessKey))}&decode=true`, "GET", request);
          if (lyricResponse.ok) parsed = await lyricResponse.json().catch(() => parsed);
        }
      }
      if (authMatch && provider === "netease" && authMatch[2] === "check") {
        const code = Number(parsed?.code ?? parsed?.data?.code ?? 0);
        const credential = upstream.headers.get("set-cookie") ?? first(parsed?.data, ["cookie", "credential"]);
        if (code === 803 || credential) return json({ status: "success", credential: credential ?? null }, 200, cors);
        return json({ status: code === 801 ? "scanned" : code === 802 ? "expired" : "waiting", message: first(parsed, ["message", "msg"]) ?? null }, 200, cors);
      }
      if (authMatch && provider === "kugou" && authMatch[2] === "check") {
        const data = parsed?.data ?? parsed;
        const credential = first(data, ["cookie", "credential", "token", "tokenstr", "authToken"]);
        const code = Number(parsed?.code ?? parsed?.status ?? 0);
        if (credential) return json({ status: "success", credential }, 200, cors);
        return json({ status: code === 2 ? "scanned" : code === 3 ? "expired" : "waiting", message: first(data, ["message", "msg"]) ?? null }, 200, cors);
      }
      if (authMatch) {
        if (provider === "qishui" && authMatch[2] === "create") {
          const session = String(first(parsed, ["token", "session", "key"]) ?? first(parsed?.data, ["token", "session", "key"]) ?? "");
          const qrUrl = first(parsed, ["qrcode_index_url", "qrcode", "qr_url", "url"]) ?? first(parsed?.data, ["qrcode_index_url", "qrcode", "qr_url", "url"]);
          const qrImage = first(parsed, ["qrImage", "qrimg", "image"]) ?? first(parsed?.data, ["qrImage", "qrimg", "image"]);
          return json({ session, qrUrl, qrImage, status: "waiting" }, 200, cors);
        }
        if (provider === "qqmusic" && authMatch[2] === "create") {
          if (!env.QR_SESSIONS) return json({ code: 503, message: "qr_session_store_not_configured" }, 503, cors);
          const session = crypto.randomUUID();
          await env.QR_SESSIONS.put(`qq:${session}`, JSON.stringify(parsed?.data ?? parsed), { expirationTtl: 300 });
          const data = parsed?.data ?? parsed;
          return json({ session, qrUrl: first(data, ["url", "qrUrl", "qrcode_url"]), qrImage: first(data, ["qrcode", "qrImage", "qrimg", "image"]), status: "waiting" }, 200, cors);
        }
        if (provider === "qqmusic" && authMatch[2] === "check") {
          const session = url.searchParams.get("session") ?? "";
          const data = parsed?.data ?? parsed;
          const credential = first(data, ["cookie", "credential", "token", "sessionid"]);
          const status = String(first(data, ["status", "message", "msg"]) ?? "waiting").toLowerCase();
          if (credential || ["success", "done", "logged_in", "authorized"].includes(status)) {
            await env.QR_SESSIONS?.delete(`qq:${session}`);
            return json({ status: "success", credential: credential ?? null }, 200, cors);
          }
          return json({ status: status.includes("scan") || status === "conf" ? "scanned" : status.includes("refuse") || status.includes("timeout") ? "expired" : "waiting", message: first(data, ["message", "msg"]) ?? null }, 200, cors);
        }
        if (provider === "qishui" && authMatch[2] === "check") {
          const data = parsed?.data ?? parsed;
          const credential = first(data?.auth, ["sessionid", "session_id"]) ?? first(data, ["sessionid", "session_id", "cookie", "credential"]);
          const rawStatus = String(first(data, ["status", "message", "msg"]) ?? "waiting").toLowerCase();
          if (credential) return json({ status: "success", credential }, 200, cors);
          const normalized = rawStatus.includes("scan") || rawStatus === "2" ? "scanned" : rawStatus.includes("expire") || rawStatus === "3" ? "expired" : "waiting";
          return json({ status: normalized, message: first(data, ["message", "msg"]) ?? null }, 200, cors);
        }
        return json(parsed, 200, cors);
      }
      const kind = apiMatch![2];
      if (kind === "search") return json({ code: 0, message: "success", data: rowsFrom(parsed).map(row => normalizeTrack(row, provider)), rawCode: parsed?.code ?? parsed?.status ?? null }, 200, cors);
      if (kind === "playlist") return json({ code: 0, message: "success", data: rowsFrom(parsed).map(normalizePlaylist) }, 200, cors);
      if (kind === "playlist/tracks") return json({ code: 0, message: "success", data: rowsFrom(parsed).map(row => normalizeTrack(row, provider)) }, 200, cors);
      if (kind === "lyric") {
        const rawLyric = first(parsed?.data, ["lrc", "lyric", "content"]) ?? first(parsed, ["lrc", "lyric", "content"]);
        const lyric = typeof rawLyric === "string" ? rawLyric : first(rawLyric, ["lyric", "content"]) ?? null;
        const translatedRaw = first(parsed, ["tlyric", "translatedLyric"]);
        const translated = typeof translatedRaw === "string" ? translatedRaw : first(translatedRaw, ["lyric"]) ?? null;
        return json({ code: 0, message: "success", data: { lyric, translated } }, 200, cors);
      }
      const stream = first(parsed?.data?.[0], ["url", "playUrl"]) ?? first(parsed?.data, ["url", "playUrl", "play_url"]) ?? first(parsed, ["url", "playUrl", "play_url"]);
      return json({ code: 0, message: stream ? "success" : "not_playable_or_not_authorized", data: { url: stream ?? null } }, 200, cors);
    } catch {
      return json({ code: 502, message: "adapter_request_failed", provider }, 502, cors);
    }
  }
};
