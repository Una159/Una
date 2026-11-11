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


## Cloudflare Dashboard Git integration

The Worker source is **not at the repository root**. For the connected Git repository, configure the Worker build settings as follows:

| Setting | Value |
|---|---|
| Repository | `Una159/Una` |
| Production branch for this project | `feature/una-ios-xcode` (keep deployment manual until live-provider checks pass) |
| Root directory | `UnaMusicPlayer/CloudflareGateway` |
| Build command | `npm ci && npm test` |
| Deploy command | `npx wrangler deploy` |
| Worker name | `una-music-gateway` (from `wrangler.toml`) |

Do not use repository root `/` as the Worker root: that directory does not contain this gateway's `package.json` or `wrangler.toml`. If the Cloudflare dashboard does not expose a separate deploy command for this connection, use the dashboard's Workers Builds configuration for the same root directory and verify that it invokes Wrangler from this folder.

Before enabling automatic production deployments, switch the production branch only after the gateway has passed live provider tests. Until then, use a manual deployment from the Cloudflare dashboard or run Wrangler from this directory after the account configuration is complete.

## Local configuration (no production credentials in Git)

```sh
cd UnaMusicPlayer/CloudflareGateway
npm ci
cp .dev.vars.example .dev.vars
```

Edit `.dev.vars` with a long random `GATEWAY_API_KEY`, the exact HTTPS origins of your four adapter services, and the app's allowed origin. Keep `.dev.vars` local; it is ignored by Git. Start local development with `npm run dev`. The local Worker still needs the KV and rate-limit bindings configured in Wrangler for QR and protected API routes to work end-to-end.

For Cloudflare, set `GATEWAY_API_KEY` with `npx wrangler secret put GATEWAY_API_KEY` (never put it in `wrangler.toml`, GitHub source, or a public build variable). Set the four provider origins and `ALLOWED_ORIGIN` as Worker environment variables in the Cloudflare dashboard or Wrangler configuration. Create the KV namespace and replace the commented placeholder binding in `wrangler.toml` with the real namespace ID before deploying QR login. Confirm the two Rate Limiting namespace IDs are available in this Cloudflare account; change them if they conflict.

### Required values before a usable deployment

- Four real HTTPS adapter origins: NetEase, Kugou, Qishui and QQ Music.
- One strong gateway API key, stored as a Worker secret and in Una's local settings.
- A real Cloudflare KV namespace ID for `QR_SESSIONS`.
- The actual app origin(s) for `ALLOWED_ORIGIN`; do not use a wildcard for credentialed requests.
- Two available Cloudflare Rate Limiting namespace IDs.

Do not substitute example domains or sample secrets. A deployment without these values may publish the Worker code, but provider routes will correctly return configuration errors and QR login will remain unavailable.

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
