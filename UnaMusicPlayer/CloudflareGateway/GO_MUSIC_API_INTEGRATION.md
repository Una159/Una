# Una Music Backend Integration

## Decision

Use `github.com/guohuiyuan/go-music-api` as a separately deployed provider service candidate, behind Una's existing Cloudflare Worker. Do not run this Go service inside Cloudflare Workers: it is a Go/Gin HTTP server and the upstream project documents Docker deployment on port 8080.

Upstream repository: https://github.com/guohuiyuan/go-music-api

License: AGPL-3.0. Preserve upstream copyright and license notices. If Una modifies and operates a covered version as a network service, provide users access to the Corresponding Source as required by AGPL-3.0. Review the license with counsel before commercial distribution.

## Verified upstream capabilities (README at review time)

- NetEase (`netease`): song search, lyrics, playlists, albums, QR login.
- QQ Music (`qq`): song search, lyrics, playlists, albums, QR login.
- Kugou (`kugou`): song search, lyrics, playlists, albums, QR login.
- Soda (`soda`): lyrics, playlists and albums are listed; single-song search is explicitly marked not yet working in the go-music-api README. Do not advertise full Soda search or QR login until independently verified.
- Actual playback, account features, availability and quality depend on upstream platform behavior, user account entitlements and region.

## Deployment topology

```
Una iOS app
    |
    | HTTPS + Una gateway credential
    v
Cloudflare Worker (una-music-gateway)
    |
    | private HTTPS origin + service credential
    v
go-music-api (Go/Gin, Docker, port 8080)
    |
    +-- NetEase
    +-- QQ Music
    +-- Kugou
    +-- Soda (partial / needs live verification)
```

The Go API is one shared origin, not four independent provider origins. The current Worker implementation expects provider-specific adapter origins and provider-specific route shapes. It must be adapted to the upstream REST contract before setting all provider origins to the same URL. Do not configure that shortcut: the current route mapping would call incompatible paths and return false failures.

## Upstream REST contract to integrate

- Search: `GET /api/v1/music/search?q={keywords}&type=song&sources={source}`
- Playback URL: `GET /api/v1/music/url?... ` (confirm exact required query parameters against the upstream Swagger/API before wiring)
- Stream proxy: `GET /api/v1/music/stream?... ` (confirm exact required query parameters)
- Lyrics: `GET /api/v1/music/lyric?... ` (confirm exact required query parameters)
- Playlist detail: `GET /api/v1/playlist/detail?source={source}&id={id}`
- User playlists: `GET /api/v1/playlist/user?source={source}&page=1&limit=30`
- QR login: upstream documents `POST /api/v1/system/qr_login/{source}` and status polling `GET /api/v1/system/qr_login/{source}?key=...` for NetEase, QQ, and Kugou. Soda QR login is not listed.

Before implementation, fetch the exact Swagger schema and response shapes. Do not guess the song URL or lyric query keys.

## Runtime security requirements

1. Bind the Go API to a private network or private ingress. Do not expose port 8080 publicly without authentication and rate limits.
2. Put the Go API service credential in server-side secrets only. Never embed it in the iOS app or commit it to Git.
3. Keep platform cookies in server-side storage with restrictive file permissions or a dedicated secret store. Never return raw cookies in logs or public responses.
4. Use HTTPS between Cloudflare Worker and the Go API. Validate the upstream hostname and prevent arbitrary URL proxying.
5. Keep the Cloudflare gateway key separate from the Go API service credential; rotate them independently.
6. Restrict playback to content the user is entitled to access. Do not bypass DRM, paid access, or platform controls.

## Deployment prerequisites

- A host that can run Docker and Go API containers (Cloudflare Workers alone cannot host this Go service).
- A domain and HTTPS ingress for the Go API, preferably private or access-controlled.
- A persistent, private volume for the upstream `cookies.json` data.
- Cloudflare Worker secret for the Go API service credential and a separate Una client gateway key.
- A Cloudflare KV namespace for QR session state if the current Worker QR implementation requires it.
- Live tests using authorized accounts for each provider.

## Acceptance checklist

- [ ] Build upstream image from a pinned release/commit, not mutable `latest`.
- [ ] Verify upstream license and preserve required notices/source offer.
- [ ] Add authenticated health check and private ingress.
- [ ] Implement a Worker adapter for the single shared Go API origin.
- [ ] Normalize provider IDs (`netease`, `qq`, `kugou`, `soda`) to Una IDs.
- [ ] Verify search, metadata, lyrics, stream range requests and error handling.
- [ ] Verify QR login for NetEase, QQ and Kugou; explicitly mark Soda login unsupported unless proven.
- [ ] Test Soda search separately; it is a known gap in the reviewed go-music-api README.
- [ ] Confirm Cloudflare secrets, KV and rate-limit bindings in the actual account.
- [ ] Run live integration tests before enabling public deployment.
