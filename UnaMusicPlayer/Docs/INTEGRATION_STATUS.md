# Una integration status

This file is the source-of-truth checklist for the current integration branch.

## Branch and scope

- Repository: `Una159/Una`
- Working branch: `feature/una-ios-xcode`
- Do not merge into `main` until the owner explicitly approves the release.
- Product target: a native iOS music player with a unified provider experience.

## Current code on this branch

- Native SwiftUI app, local music library and AVFoundation playback layer.
- A new Online Music tab backed by `GatewayMusicView`.
- Provider selection for Netease, Kugou, Qishui and QQ Music.
- Gateway client operations for search, song URL resolution, lyrics, playlists, playlist tracks and QR login polling.
- Gateway API key and provider credentials stored in iOS Keychain.
- Cloudflare Worker routes and smoke coverage for four QR flows plus search and lyrics.
- The owner-approved 1024 × 1024 logo is present in the local handoff package; the binary AppIcon asset still needs to be uploaded to this branch.

## Important release blockers

The gateway is an adapter scaffold, not proof of live provider compatibility. Provider origins must be configured and each upstream route must be validated against the current provider adapter implementation. In particular:

- QR create/check flows must be tested with real accounts and provider-issued session state.
- Search, playlist ownership, playlist tracks, lyric variants and stream URL response shapes must be verified per provider.
- Stream URLs must only be exposed when the account and provider authorize playback; no DRM or membership restriction bypass.
- Configure a non-empty gateway API key, strict allowed origin, HTTPS upstreams and a KV namespace before public deployment.
- Never commit secrets, cookies, QR tokens or account credentials.

## Required verification before calling this production-ready

- Cloudflare Worker deployed to an owner-controlled account with secrets and bindings configured.
- Four provider login flows tested with real accounts.
- Search, playlist, lyric and playback tested for each provider.
- iOS Simulator build passes on GitHub Actions.
- Device tests cover background audio, lock-screen controls, AirPlay, route changes and interrupted playback.
- Error, expired-session, rate-limit and unsupported-track states have UI coverage.

## Status vocabulary

- **Implemented** means source code exists.
- **Static check passed** means parser/type checker passed locally.
- **CI passed** means the corresponding GitHub Actions job passed.
- **Live verified** means a real provider account and real playback session passed.
