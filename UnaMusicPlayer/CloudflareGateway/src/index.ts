export interface Env {
  NETEASE_ORIGIN?: string;
  KUGOU_ORIGIN?: string;
  QISHUI_ORIGIN?: string;
  QQMUSIC_ORIGIN?: string;
  ALLOWED_ORIGIN?: string;
  GATEWAY_API_KEY?: string;
  QR_SESSIONS?: KVNamespace;
  API_RATE_LIMITER?: RateLimitBinding;
  QR_RATE_LIMITER?: RateLimitBinding;
}

type Provider = "netease" | "kugou" | "qishui" | "qqmusic";
type RouteKind = "search" | "song-url" | "lyric" | "playlist" | "playlist-tracks" | "qr-create" | "qr-check";
const PROVIDERS: Provider[] = ["netease", "kugou", "qishui", "qqmusic"];
const GO_SOURCE: Record<Provider, string> = { netease: "netease", kugou: "kugou", qishui: "soda", qqmusic: "qq" };
const JSON_HEADERS = { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" };

function json(data: unknown, status = 200, extra: HeadersInit = {}) {
  return new Response(JSON.stringify(data), { status, headers: { ...JSON_HEADERS, ...extra } });
}
function providerOrigin(env: Env, provider: Provider): string | undefined {
  const value = ({ netease: env.NETEASE_ORIGIN, kugou: env.KUGOU_ORIGIN, qishui: env.QISHUI_ORIGIN, qqmusic: env.QQMUSIC_ORIGIN })[provider];
  if (!value) return undefined;
  try {
    const u = new URL(value);
    if (u.protocol !== "https:" || !u.hostname || u.username || u.password || (u.pathname !== "/" && u.pathname !== "") || u.search || u.hash) return undefined;
    return u.origin;
  } catch { return undefined; }
}
function cookieHeaderFromSetCookie(value: string | null): string | undefined {
  if (!value) return undefined;
  const pairs = value.split(/,(?=[^;,=\s]+=)/)
    .map(part => part.split(";", 1)[0].trim())
    .filter(part => /^[^=;,\s]+=/.test(part));
  return pairs.length ? [...new Set(pairs)].join("; ") : undefined;
}
function firstPlayableURL(payload: any, depth = 0): string | undefined {
  if (!payload || depth > 5) return undefined;
  if (Array.isArray(payload)) {
    for (const item of payload) { const found = firstPlayableURL(item, depth + 1); if (found) return found; }
    return undefined;
  }
  if (typeof payload !== "object") return undefined;
  for (const key of ["url", "playUrl", "play_url", "streamURL", "media_url", "audio"]) {
    const candidate = payload[key];
    if (typeof candidate === "string" && /^https:\/\//i.test(candidate)) return candidate;
  }
  for (const value of Object.values(payload)) {
    const found = firstPlayableURL(value, depth + 1);
    if (found) return found;
  }
  return undefined;
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
  const rawArtist = first(row, ["artist", "singer", "artistName", "author", "singername"]);
  const artist = Array.isArray(rawArtist)
    ? rawArtist.map(item => typeof item === "string" ? item : first(item, ["name", "title", "nick"]) ?? "").filter(Boolean).join(" / ")
    : typeof rawArtist === "object" && rawArtist !== null
      ? String(first(rawArtist, ["name", "title", "nick"]) ?? "未知歌手")
      : String(rawArtist ?? "未知歌手");
  const rawAlbum = first(row, ["album", "albumName", "albumname"]);
  const album = typeof rawAlbum === "string" ? rawAlbum : first(rawAlbum, ["name", "title"]) ?? null;
  const rawDuration = Number(first(row, ["duration", "interval", "dt"]) ?? 0);
  const duration = rawDuration > 10000 ? rawDuration / 1000 : rawDuration || null;
  const artwork = first(row, ["artworkURL", "artwork", "picUrl", "cover", "coverUrl"]);
  const page = first(row, ["pageURL", "shareUrl", "webUrl"]);
  const stream = first(row, ["streamURL", "playUrl", "play_url", "media_url"]);
  return {
    id: String(first(row, ["id", "songId", "songid", "mid", "songmid", "hash", "track_id", "trackId"]) ?? ""),
    title: String(first(row, ["title", "name", "songName", "songname"]) ?? "未知歌曲"),
    artist,
    album: album == null ? null : String(album),
    duration,
    artworkURL: typeof artwork === "string" && /^https:\/\//i.test(artwork) ? artwork : null,
    pageURL: typeof page === "string" ? page : null,
    streamURL: typeof stream === "string" && /^https:\/\//i.test(stream) ? stream : null,
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

function goMusicTarget(provider: Provider, kind: RouteKind, q: URLSearchParams, body: any): { path: string; method: string; body?: unknown } {
  const source = GO_SOURCE[provider];
  const p = new URLSearchParams();
  const copy = ["id", "name", "artist", "album", "cover", "duration", "extra", "page", "limit", "uid", "uin"];
  for (const key of copy) { const value = q.get(key); if (value !== null && value !== "") p.set(key, value); }
  p.set("source", source);
  if (kind === "search") {
    p.set("q", q.get("keywords") ?? q.get("q") ?? "");
    p.set("type", "song");
    p.delete("id"); p.delete("name"); p.delete("artist"); p.delete("album"); p.delete("cover"); p.delete("duration"); p.delete("extra");
    return { path: `/api/v1/music/search?${p.toString()}`, method: "GET" };
  }
  if (kind === "song-url") return { path: `/api/v1/music/url?${p.toString()}`, method: "GET" };
  if (kind === "lyric") return { path: `/api/v1/music/lyric?${p.toString()}`, method: "GET" };
  if (kind === "playlist") return { path: `/api/v1/playlist/user?${p.toString()}`, method: "GET" };
  if (kind === "playlist-tracks") return { path: `/api/v1/playlist/detail?${p.toString()}`, method: "GET" };
  if (kind === "qr-create") return { path: `/api/v1/system/qr_login/${source}`, method: "POST", body: {} };
  if (kind === "qr-check") return { path: `/api/v1/system/qr_login/${source}?${new URLSearchParams({ key: q.get("session") ?? "" }).toString()}`, method: "GET" };
  return { path: "/health", method: "GET" };
}

const UPSTREAM_TIMEOUT_MS = 15_000;
const MAX_UPSTREAM_RESPONSE_BYTES = 4 * 1024 * 1024;

async function enforceRateLimit(
  env: Env,
  request: Request,
  route: string,
  isQR: boolean,
  cors: HeadersInit
): Promise<Response | undefined> {
  const limiter = isQR ? env.QR_RATE_LIMITER : env.API_RATE_LIMITER;
  // Fail closed: protected routes must never silently run without their configured limiter.
  if (!limiter) return json({ code: 503, message: "rate_limiter_not_configured" }, 503, cors);
  const clientIP = request.headers.get("cf-connecting-ip")?.trim() || "unknown";
  try {
    const result = await limiter.limit({ key: `una:${isQR ? "qr" : "api"}:${route}:${clientIP}` });
    if (!result.success) {
      return json({ code: 429, message: "rate_limit_exceeded" }, 429, {
        ...cors,
        "retry-after": "60"
      });
    }
    return undefined;
  } catch {
    // A broken/missing platform binding must not become an accidental unlimited proxy.
    return json({ code: 503, message: "rate_limiter_unavailable" }, 503, cors);
  }
}

async function callUpstream(origin: string, path: string, method: string, incoming: Request, body?: unknown) {
  const url = new URL(path, origin);
  const headers = new Headers({ accept: "application/json" });
  for (const name of ["cookie", "authorization", "user-agent", "x-requested-with"]) {
    const value = incoming.headers.get(name); if (value) headers.set(name, value);
  }
  let payload: string | undefined;
  if (body !== undefined) { headers.set("content-type", "application/json"); payload = JSON.stringify(body); }
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort("upstream_timeout"), UPSTREAM_TIMEOUT_MS);
  try {
    const response = await fetch(url, { method, headers, body: method === "GET" ? undefined : payload, redirect: "manual", signal: controller.signal });
    const declaredLength = Number(response.headers.get("content-length") ?? 0);
    if (declaredLength > MAX_UPSTREAM_RESPONSE_BYTES) {
      await response.body?.cancel();
      throw new Error("upstream_response_too_large");
    }
    const reader = response.body?.getReader();
    const chunks: Uint8Array[] = [];
    let totalBytes = 0;
    if (reader) {
      try {
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          totalBytes += value.byteLength;
          if (totalBytes > MAX_UPSTREAM_RESPONSE_BYTES) {
            await reader.cancel("upstream_response_too_large");
            throw new Error("upstream_response_too_large");
          }
          chunks.push(value);
        }
      } finally {
        reader.releaseLock();
      }
    }
    const bytes = new Uint8Array(totalBytes);
    let offset = 0;
    for (const chunk of chunks) {
      bytes.set(chunk, offset);
      offset += chunk.byteLength;
    }
    const responseHeaders = new Headers({ "content-type": response.headers.get("content-type") ?? "application/json", "cache-control": "no-store" });
    const setCookie = response.headers.get("set-cookie");
    if (setCookie) responseHeaders.set("set-cookie", setCookie);
    return new Response(bytes, { status: response.status, headers: responseHeaders });
  } finally {
    clearTimeout(timeout);
  }
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    // Bound attacker-controlled request metadata before parsing or proxying it.
    if (request.url.length > 4096) return json({ code: 414, message: "request_url_too_long" }, 414);
    const declaredBodyLength = Number(request.headers.get("content-length") ?? 0);
    if (Number.isFinite(declaredBodyLength) && declaredBodyLength > 16 * 1024) {
      return json({ code: 413, message: "request_body_too_large" }, 413);
    }
    const allowedOrigins = (env.ALLOWED_ORIGIN ?? "").split(",").map(value => value.trim()).filter(Boolean);
    const requestOrigin = request.headers.get("origin");
    const originAllowed = !requestOrigin || allowedOrigins.includes(requestOrigin);
    const corsOrigin = requestOrigin && originAllowed ? requestOrigin : (allowedOrigins.length === 1 ? allowedOrigins[0] : "null");
    const cors = { "access-control-allow-origin": corsOrigin, "access-control-allow-methods": "GET,POST,OPTIONS", "access-control-allow-headers": "content-type,authorization,cookie,x-una-gateway-key", "access-control-max-age": "600", "vary": "origin" };
    if (!originAllowed) return json({ code: 403, message: "origin_not_allowed" }, 403, cors);
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
    // Fail closed: never expose provider adapters when the gateway secret is missing or mismatched.
    if (!env.GATEWAY_API_KEY || request.headers.get("x-una-gateway-key") !== env.GATEWAY_API_KEY) return json({ code: 401, message: "unauthorized" }, 401, cors);
    if (url.pathname === "/health") return json({ code: 0, message: "ok", data: { service: "una-music-gateway", providers: PROVIDERS.map(p => ({ id: p, configured: !!providerOrigin(env, p) })) } }, 200, cors);

    const authMatch = url.pathname.match(/^\/una\/auth\/(netease|kugou|qishui|qqmusic)\/qr\/(create|check)$/);
    const legacyNeteaseQRMatch = url.pathname.match(/^\/login\/qr\/(key|create|check)$/);
    const apiMatch = url.pathname.match(/^\/una\/v1\/(netease|kugou|qishui|qqmusic)\/(search|song\/url|lyric|playlist|playlist\/tracks)$/);
    if (!authMatch && !legacyNeteaseQRMatch && !apiMatch) return json({ code: 404, message: "route_not_found" }, 404, cors);
    if (apiMatch && request.method !== "GET") return json({ code: 405, message: "method_not_allowed" }, 405, { ...cors, allow: "GET, OPTIONS" });
    if (authMatch && !["GET", "POST"].includes(request.method)) return json({ code: 405, message: "method_not_allowed" }, 405, { ...cors, allow: "GET, POST, OPTIONS" });
    if (legacyNeteaseQRMatch && request.method !== "GET") return json({ code: 405, message: "method_not_allowed" }, 405, { ...cors, allow: "GET, OPTIONS" });
    if (apiMatch) {
      const keywords = url.searchParams.get("keywords") ?? "";
      const id = url.searchParams.get("id") ?? "";
      const limit = Number(url.searchParams.get("limit") ?? "20");
      if (apiMatch[2] === "search" && (!keywords.trim() || keywords.length > 120)) {
        return json({ code: 400, message: "invalid_search_keywords" }, 400, cors);
      }
      if (["song/url", "lyric", "playlist/tracks"].includes(apiMatch[2]) && (!id || id.length > 160)) {
        return json({ code: 400, message: "invalid_resource_id" }, 400, cors);
      }
      if (!Number.isFinite(limit) || limit < 1) return json({ code: 400, message: "invalid_limit" }, 400, cors);
      url.searchParams.set("limit", String(Math.min(Math.floor(limit), 50)));
    }
    const provider = (authMatch?.[1] ?? (legacyNeteaseQRMatch ? "netease" : apiMatch?.[1])) as Provider;
    const origin = providerOrigin(env, provider);
    if (!origin) return json({ code: 503, message: `${provider}_adapter_not_configured` }, 503, cors);
    const rateLimitResponse = await enforceRateLimit(env, request, url.pathname, !!(authMatch || legacyNeteaseQRMatch), cors);
    if (rateLimitResponse) return rateLimitResponse;

    try {
      let target: { path: string; method: string; body?: unknown };
      if (legacyNeteaseQRMatch) {
        target = { path: url.pathname + url.search, method: "GET" };
      } else if (authMatch) {
        let body: any = {};
        if (request.method === "POST") {
          try {
            const rawBody = await request.clone().text();
            if (new TextEncoder().encode(rawBody).byteLength > 16 * 1024) {
              return json({ code: 413, message: "request_body_too_large" }, 413, cors);
            }
            body = rawBody ? JSON.parse(rawBody) : {};
            if (!body || typeof body !== "object" || Array.isArray(body)) {
              return json({ code: 400, message: "invalid_request_body" }, 400, cors);
            }
          } catch {
            return json({ code: 400, message: "invalid_request_body" }, 400, cors);
          }
        }
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
      const upstreamRequest = new Request(request, { headers: new Headers(request.headers) });
      if (env.GO_MUSIC_API_TOKEN) upstreamRequest.headers.set("authorization", `Bearer ${env.GO_MUSIC_API_TOKEN}`);
      const upstream = await callUpstream(origin, target.path, target.method, upstreamRequest, target.body);
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
      if (env.GO_MUSIC_API_ORIGIN && authMatch) {
        const data = parsed?.data ?? parsed;
        const credential = first(data, ["cookie", "credential", "token", "tokenstr"]);
        const statusCode = Number(parsed?.code ?? data?.code ?? 0);
        if (authMatch[2] === "create") {
          const session = String(first(data, ["key", "unikey", "token", "session"]) ?? "");
          const qrUrl = first(data, ["url", "qrurl", "qrcode_url", "qr_url"]);
          const qrImage = first(data, ["qrimg", "qrcode", "qrImage", "image"]);
          return json({ session, qrUrl, qrImage, status: "waiting", raw: data }, 200, cors);
        }
        if (credential || statusCode === 200 && (data?.status === "success" || data?.status === "done")) return json({ status: "success", credential: credential ?? null }, 200, cors);
        return json({ status: data?.status === "scanned" ? "scanned" : data?.status === "expired" ? "expired" : "waiting", raw: data }, 200, cors);
      }
      if (authMatch && provider === "netease" && authMatch[2] === "check") {
        const code = Number(parsed?.code ?? parsed?.data?.code ?? 0);
        const credential = cookieHeaderFromSetCookie(upstream.headers.get("set-cookie")) ?? first(parsed?.data, ["cookie", "credential"]);
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
      const stream = firstPlayableURL(parsed);
      return json({ code: 0, message: stream ? "success" : "not_playable_or_not_authorized", data: { url: stream ?? null } }, 200, cors);
    } catch {
      return json({ code: 502, message: "adapter_request_failed", provider }, 502, cors);
    }
  }
};
