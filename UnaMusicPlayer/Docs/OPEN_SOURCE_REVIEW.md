# Una Open-Source Readiness Review

Status: preparation only. This change does not make the repository public or announce a production release.

## Decisions

- Planned license: MIT.
- Release strategy: internal review first; public release only after owner acceptance.
- Scope: `UnaMusicPlayer/` is a standalone project subtree. The repository root contains a separate K-Douyin Ultra project and its existing license. Do not replace the repository-root LICENSE or README as part of Una preparation.
- Do not merge this branch into `main` without explicit owner approval.

## Findings

### Confirmed

- iOS Simulator build, Una Quality Gate, and Gateway Validation all passed at commit `27d82c966b1cfce702599a76fd06fb5e22668d63` (runs [42965644529](https://github.com/Una159/Una/actions/runs/42965644529), [42965644544](https://github.com/Una159/Una/actions/runs/42965644544), [42965644524](https://github.com/Una159/Una/actions/runs/42965644524)).
- Earlier Cloudflare Gateway type-check and mocked smoke tests passed at commit `e7b0010`.
- The Worker is a gateway and depends on separately deployed provider adapters.
- The Worker is not deployed to an owner-controlled production account.
- Four-provider QR tests are mocked tests, not real-account validation.
- CI success is not physical-device or provider production verification.

### Release blockers

1. The selected 1024×1024 AppIcon PNG and its AppIcon.appiconset Contents.json are now committed on feature/una-ios-xcode. Xcode asset-catalog validation and a fresh CI run on the icon commit are still required before release.
2. Validate background playback, lock screen, AirPlay, interruptions and file import on physical iPhones.
3. Verify real QR login, logout, search, pagination, playlists, lyrics and authorized playback for each provider.
4. Review upstream adapter repositories, versions and licenses before bundling or deploying them. Keep notices and attribution.
5. Add a complete third-party notices/dependency inventory.
6. Review privacy, data retention, CORS, authentication, rate limiting, SSRF protections and secret handling.
7. Confirm all artwork, fonts, sounds and other assets are original or properly licensed.

## Public-release checklist

- [ ] Owner accepts review and approves public visibility.
- [ ] Re-run iOS Simulator build and Una Quality Gate on the current icon commit; the previous successful runs were on `34d9c3ee61f8d0b0b51f9b2fa097b88de99a013d`.
- [x] Final app icon PNG and AppIcon.appiconset Contents.json are committed; [ ] verify asset-catalog compilation in Xcode.
- [ ] Physical-device QA is documented.
- [ ] Real provider login and playback are verified.
- [ ] Provider adapter licenses and terms are reviewed.
- [ ] Third-party notices and dependency inventory are complete.
- [ ] No secrets, private data or personal configuration remain in Git history.
- [ ] Documentation and MIT license are reviewed.
- [ ] Release notes and version are prepared.
- [ ] Owner explicitly approves publishing the repository publicly.
