# Una × go-music-api Integration

## Scope

The current integration targets three platforms only:

- NetEase Music: upstream source `netease`
- QQ Music: upstream source `qq`
- Kugou Music: upstream source `kugou`

Soda Music is intentionally disabled in Una's Worker routes. Requests to `qishui` return HTTP 501 with `provider_temporarily_disabled`. It is not part of the acceptance scope for this phase.

Upstream project: https://github.com/guohuiyuan/go-music-api  
Upstream license: AGPL-3.0. Preserve notices and comply with source-offer obligations if operating a modified network service.

## Topology

```
Una iOS app
  └─ HTTPS + x-una-gateway-key
       └─ Cloudflare Worker
            └─ HTTPS + server-side GO_MUSIC_API_TOKEN
                 └─ go-music-api (Go/Gin, private Docker service)
                      ├─ NetEase
                      ├─ QQ Music
                      └─ Kugou
```

Configure one shared HTTPS origin in Worker variable `GO_MUSIC_API_ORIGIN`. Store `GO_MUSIC_API_TOKEN` as a Worker secret. The token is intended for a reverse proxy or access gateway in front of go-music-api; upstream go-music-api itself does not document native bearer-token authentication. Keep it separate from `GATEWAY_API_KEY`.

## Verified upstream routes

- Search: `GET /api/v1/music/search?q=...&type=song&sources=netease|qq|kugou` (send `sources` as a repeated query parameter).
- Playback URL: `GET /api/v1/music/url` with the song fields `id`, `source`, `name`, `artist`, `album`, `cover`, `duration`, and optional `extra`.
- Lyrics: `GET /api/v1/music/lyric` with the same song identity fields.
- Playlist detail: `GET /api/v1/playlist/detail?source=...&id=...`.
- User playlists: `GET /api/v1/playlist/user?source=...&page=1&limit=30`.
- QR create: `POST /api/v1/system/qr_login/{source}`.
- QR poll: `GET /api/v1/system/qr_login/{source}?key=...`.

The upstream documents QR login for NetEase, QQ, QQ WeChat and Kugou. Una's current route maps the QQ Music QR flow to upstream `qq`; WeChat-specific QQ login is not separately exposed in Una's client API yet. Upstream QR login stores successful cookies in its server-side `cookies.json`. Una's Worker must not return those cookies to the iOS client.

## Implemented in Worker

- Shared origin and server-side service-token support.
- Provider source mapping for NetEase, QQ Music and Kugou.
- Search, song URL, lyrics, user playlist and playlist detail route mapping.
- QR create/poll route mapping.
- Normalized track, playlist, lyric and play URL response shapes.
- QR success response deliberately omits the upstream cookie.
- Soda provider is excluded from health's active provider list and returns HTTP 501.
- Smoke tests cover source routing, service-token forwarding, metadata normalization, playlist paths and QR cookie non-disclosure.

## Security / deployment constraints

1. Deploy Go API as a separate Go/Docker service. Cloudflare Workers cannot host this Go/Gin process.
2. Keep Go API behind private HTTPS ingress or an authenticated reverse proxy. Upstream itself does not document bearer-token enforcement.
3. Do not expose port 8080 publicly without access control.
4. Persist `cookies.json` on a private volume with restrictive permissions.
5. Do not commit cookies, service tokens, QR session data or account credentials.
6. Keep `GO_MUSIC_API_TOKEN` and `GATEWAY_API_KEY` independently managed and rotated.
7. Test with accounts authorized to use each provider; playback and high-quality access remain subject to platform rights, account entitlements and region.
8. Build a pinned upstream release/commit rather than relying on mutable `latest`.

## Acceptance status

- [x] Worker source mapping for three active platforms.
- [x] Worker path adapters for search, playback URL, lyrics and playlists.
- [x] QR create/poll adapters and cookie non-disclosure.
- [x] Automated mocked contract tests added.
- [ ] CI Gateway Validation on the latest commit.
- [ ] iOS integration against a live Go API instance.
- [ ] Live QR login tests for NetEase, QQ and Kugou.
- [ ] Actual audio playback tests, including Range handling where streaming proxy is used.
- [ ] Private Go API host, HTTPS ingress, persistent cookie storage and Worker secrets configured.
- [ ] Deployment and production smoke test.

Mocked tests do not establish live provider availability. Do not mark the integration production-ready until the unchecked items are verified.
