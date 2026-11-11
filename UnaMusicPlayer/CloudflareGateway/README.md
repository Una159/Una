# Una Cloudflare Music Gateway

This Worker is the single HTTPS API entry point used by Una. It normalizes the four provider routes and never logs request cookies or authorization headers.

## Architecture boundary

The Worker is a gateway, not a provider implementation. Each provider origin must be a separately deployed, trusted adapter service. The provider clients have different runtimes, QR session lifetimes, signing requirements and upstream protocols.

| Provider | Expected adapter | Upstream routes used |
|---|---|---|
| NetEase | NeteaseCloudMusicApi-compatible service | `/login/qr/*`, `/cloudsearch`, `/song/url/v1`, `/lyric`, `/user/playlist`, `/playlist/track/all` |
| Kugou | KuGouMusicApi-compatible service | `/login/qr/*`, `/search`, `/song/url`, `/search/lyric`, `/playlist/track/all` |
| Qishui | Qishui-compatible Node service | `/auth/qrcode`, `/auth/qrcode/status`, `/search`, `/lyric`, `/me/playlists`, `/playlist/detail`, `/download/url` |
| QQ Music | QQMusicapi-compatible service | `/login/qrcode`, `/login/checkQrcode`, `/search/general`, `/song/urls`, `/song/lyric`, `/user/songlist` |

## Configure and deploy

1. Deploy and review the four upstream adapter services. Check their current maintenance status, licenses and security before exposing them.
2. Configure HTTPS Worker variables: `NETEASE_ORIGIN`, `KUGOU_ORIGIN`, `QISHUI_ORIGIN`, `QQMUSIC_ORIGIN`.
3. Set `GATEWAY_API_KEY` as a Worker secret and enter the same value in Una Settings → Music Platform Integration → Gateway Access Key.
4. Create a KV namespace with `npx wrangler kv namespace create QR_SESSIONS`, then bind its ID in `wrangler.toml`.
5. Verify `API_RATE_LIMITER` and `QR_RATE_LIMITER` use positive namespace IDs not already used by another Worker in your Cloudflare account. The checked-in IDs are project defaults; change them if they collide.
6. Deploy with `npx wrangler deploy`.
7. Check `/health`. This reports configured origins only; it does not prove provider login works.

## Unified routes

- `GET /una/auth/{provider}/qr/create`
- `GET /una/auth/{provider}/qr/check?session=...`
- `GET /una/v1/{provider}/search?keywords=...&limit=20`
- `GET /una/v1/{provider}/song/url?id=...`
- `GET /una/v1/{provider}/lyric?id=...`
- `GET /una/v1/{provider}/playlist?uid=...&uin=...`
- `GET /una/v1/{provider}/playlist/tracks?id=...&limit=20`

Provider IDs: `netease`, `kugou`, `qishui`, `qqmusic`.

## Security and playback policy

- Production upstream origins must use HTTPS.
- Keep upstream cookies and tokens in server-side adapter storage or iOS Keychain; never log them.
- The Worker enforces Cloudflare Rate Limiting bindings: API routes are limited to 120 requests/minute per client IP and route; QR routes are limited to 6 requests/minute per client IP and route. Exceeded requests return HTTP 429 with `Retry-After: 60`. These limits are approximate and local to each Cloudflare location, not a strict global quota or a per-user identity system.
- Keep upstream services private to Worker egress where practical. Add account-level WAF/abuse controls and per-user quotas before a public multi-user launch.
- Return only playback URLs authorized for the current account, territory and subscription. Never bypass DRM, memberships or access controls.
- Community adapters are unofficial and may break when providers change protocols.

## Known limitations before production

- Cloudflare Rate Limiting counters are approximate and location-local; the shared client API key does not identify individual users. Add a trusted user identity layer and global/per-user abuse controls before public multi-user launch.
- Provider-specific QR response/session normalization still requires tests against exact deployed adapter versions.
- Qishui QR confirmation behavior must be verified with the actual scanning app.
- QQ QR sessions require the KV namespace.
- Playlist account identity extraction needs real account tests.
- Run live tests for all four providers, expiring playback URLs, unavailable tracks, pagination, empty lyrics and logout.
