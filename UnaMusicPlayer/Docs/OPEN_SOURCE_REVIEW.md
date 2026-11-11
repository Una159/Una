# Una Open-Source Readiness Review

Status: preparation only. This change does not make the repository public or announce a production release.

## Decisions

- Planned license: MIT.
- Release strategy: internal review first; public release only after owner acceptance.
- Scope: `UnaMusicPlayer/` is a standalone project subtree. The repository root contains a separate K-Douyin Ultra project and its existing license. Do not replace the repository-root LICENSE or README as part of Una preparation.
- Do not merge this branch into `main` without explicit owner approval.

## Findings

### Confirmed

- iOS Simulator build and Una Quality Gate passed on verified commit `8aea27f68fe31a584bd434f444667dbc4c85a99b` (run [43017273548](https://github.com/Una159/Una/actions/runs/43017273548)); both the simulator build and Gateway checks passed.
- Dedicated Cloudflare Gateway Validation passed after the lockfile and read-only CI workflow were in place at commit `9205b6b13655f229b153c161d41895df81cb6d77` (run [43016948628](https://github.com/Una159/Una/actions/runs/43016948628)). The gateway code with rate limiting and request-bound tests passed at `ff83aab56435574b1481e4efc2d4b4691cbec18c` (run [43016684132](https://github.com/Una159/Una/actions/runs/43016684132)).
- `CloudflareGateway/package-lock.json` is committed (lockfile v3); CI uses `npm ci`. A CycloneDX 1.5 SBOM was generated as a CI artifact with 41 installed components from the locked toolchain.
- The Worker now has Cloudflare API and QR rate-limit bindings (120 and 6 requests/minute per client IP and route respectively), bounded inbound request metadata, bounded upstream responses, and tests for 429/fail-closed behavior. Cloudflare's built-in rate limiting is approximate and location-local; this is not a strict global or per-user quota.
- The Worker is a gateway and depends on separately deployed provider adapters.
- The Worker is not deployed to an owner-controlled production account.
- Four-provider QR tests are mocked tests, not real-account validation.
- CI success is not physical-device or provider production verification.

### Release blockers

1. The selected 1024×1024 AppIcon PNG and its AppIcon.appiconset Contents.json are committed. The verified iOS Simulator build passed, including project metadata validation; verify the icon visually and on a physical device before release.
2. Validate background playback, lock screen, AirPlay, interruptions and file import on physical iPhones.
3. Verify real QR login, logout, search, pagination, playlists, lyrics and authorized playback for each provider.
4. Review upstream adapter repositories, versions and licenses before bundling or deploying them. Keep notices and attribution.
5. `THIRD_PARTY_NOTICES.md`, the npm lockfile and a CycloneDX SBOM are present. Exact license-text review (including optional LGPL libvips components), provider adapter provenance/licenses and asset attributions remain open.
6. Complete privacy, data-retention, CORS, authentication, rate-limit operations, SSRF and secret-handling review. The shared client-held gateway key is extractable; a trusted user-identity layer, per-user quotas and account-level abuse controls remain required before public multi-user launch.
7. Confirm all artwork, fonts, sounds and other assets are original or properly licensed.

## Public-release checklist

- [ ] Owner accepts review and approves public visibility.
- [x] Re-run iOS Simulator build and Una Quality Gate on verified commit `8aea27f68fe31a584bd434f444667dbc4c85a99b` (run [43017273548](https://github.com/Una159/Una/actions/runs/43017273548)).
- [x] Dedicated Gateway Validation passed with locked dependencies (run [43016948628](https://github.com/Una159/Una/actions/runs/43016948628)).
- [x] Final app icon PNG and AppIcon.appiconset Contents.json are committed; [ ] verify asset-catalog compilation in Xcode.
- [ ] Physical-device QA is documented.
- [ ] Real provider login and playback are verified.
- [ ] Provider adapter licenses and terms are reviewed.
- [x] npm lockfile and CycloneDX SBOM generation are in place; complete package license-text, provider adapter and asset attribution audit.
- [ ] No secrets, private data or personal configuration remain in Git history.
- [ ] Documentation and MIT license are reviewed.
- [ ] Release notes and version are prepared.
- [ ] Owner explicitly approves publishing the repository publicly.
