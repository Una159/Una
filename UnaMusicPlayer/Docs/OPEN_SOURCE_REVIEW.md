# Una Open-Source Readiness Review

Status: preparation only. This change does not make the repository public or announce a production release.

## Decisions

- Planned license: MIT.
- Release strategy: internal review first; public release only after owner acceptance.
- Scope: `UnaMusicPlayer/` is a standalone project subtree. The repository root contains a separate K-Douyin Ultra project and its existing license. Do not replace the repository-root LICENSE or README as part of Una preparation.
- Do not merge this branch into `main` without explicit owner approval.

## Findings

### Confirmed

- iOS Simulator build and Una Quality Gate passed on branch HEAD `2d49dba4efc78666f0fd5fc62e9835aa2ebc10ab` (runs [43014304671](https://github.com/Una159/Una/actions/runs/43014304671) and [43014304684](https://github.com/Una159/Una/actions/runs/43014304684)); the Quality Gate's simulator build and gateway checks both passed.
- Cloudflare Gateway type-check and mocked smoke tests passed at commits `4eb9dcaa49582d6cc76dafaf46cf2394df5c8892` (run [42987951673](https://github.com/Una159/Una/actions/runs/42987951673)); the current HEAD Quality Gate also passed its gateway checks.
- The Worker is a gateway and depends on separately deployed provider adapters.
- The Worker is not deployed to an owner-controlled production account.
- Four-provider QR tests are mocked tests, not real-account validation.
- CI success is not physical-device or provider production verification.

### Release blockers

1. The selected 1024×1024 AppIcon PNG and its AppIcon.appiconset Contents.json are committed. The current HEAD iOS Simulator build passed, including project metadata validation; verify the icon visually and on a physical device before release.
2. Validate background playback, lock screen, AirPlay, interruptions and file import on physical iPhones.
3. Verify real QR login, logout, search, pagination, playlists, lyrics and authorized playback for each provider.
4. Review upstream adapter repositories, versions and licenses before bundling or deploying them. Keep notices and attribution.
5. A preliminary THIRD_PARTY_NOTICES.md inventory is present. It is not complete until dependency lockfiles/SBOM, exact package licenses, provider adapter provenance/licenses and asset attributions are recorded.
6. Review privacy, data retention, CORS, authentication, rate limiting, SSRF protections and secret handling.
7. Confirm all artwork, fonts, sounds and other assets are original or properly licensed.

## Public-release checklist

- [ ] Owner accepts review and approves public visibility.
- [x] Re-run iOS Simulator build and Una Quality Gate on current verified HEAD `2d49dba4efc78666f0fd5fc62e9835aa2ebc10ab` (runs [43014304671](https://github.com/Una159/Una/actions/runs/43014304671), [43014304684](https://github.com/Una159/Una/actions/runs/43014304684)).
- [x] Final app icon PNG and AppIcon.appiconset Contents.json are committed; [ ] verify asset-catalog compilation in Xcode.
- [ ] Physical-device QA is documented.
- [ ] Real provider login and playback are verified.
- [ ] Provider adapter licenses and terms are reviewed.
- [ ] Preliminary THIRD_PARTY_NOTICES.md exists; complete lockfile/SBOM, package license and provider adapter/asset attribution audit.
- [ ] No secrets, private data or personal configuration remain in Git history.
- [ ] Documentation and MIT license are reviewed.
- [ ] Release notes and version are prepared.
- [ ] Owner explicitly approves publishing the repository publicly.
