# Una Open-Source Readiness Review

Status: preparation only. This change does not make the repository public or announce a production release.

## Decisions

- Planned license: MIT.
- Release strategy: internal review first; public release only after owner acceptance.
- Scope: `UnaMusicPlayer/` is a standalone project subtree. The repository root contains a separate K-Douyin Ultra project and its existing license. Do not replace the repository-root LICENSE or README as part of Una preparation.
- Do not merge this branch into `main` without explicit owner approval.

## Findings

### Confirmed

- An iOS Simulator build completed successfully in GitHub Actions at commit `986dbc1`.
- Cloudflare Gateway type-check and mocked smoke tests completed successfully at commit `e7b0010`.
- The Worker is a gateway and depends on separately deployed provider adapters.
- The Worker is not deployed to an owner-controlled production account.
- Four-provider QR tests are mocked tests, not real-account validation.

### Release blockers

1. The current Git tree has an AppIcon asset catalog manifest but no referenced binary AppIcon image. Add and verify the owner-approved final icon before release.
2. Recheck iOS build after all latest commits.
3. Validate background playback, lock screen, AirPlay, interruptions and file import on physical iPhones.
4. Verify real QR login, logout, search, pagination, playlists, lyrics and authorized playback for each provider.
5. Review upstream adapter repositories, versions and licenses before bundling or deploying them. Keep notices and attribution.
6. Add a complete third-party notices/dependency inventory.
7. Review privacy, data retention, CORS, authentication, rate limiting, SSRF protections and secret handling.
8. Confirm all artwork, fonts, sounds and other assets are original or properly licensed.

## Public-release checklist

- [ ] Owner accepts review and approves public visibility.
- [ ] Latest iOS and gateway CI checks pass.
- [ ] Final app icon binary is present and verified in Xcode.
- [ ] Physical-device QA is documented.
- [ ] Provider adapter licenses and terms are reviewed.
- [ ] Third-party notices and dependency inventory are complete.
- [ ] No secrets, private data or personal configuration remain in Git history.
- [ ] Documentation and MIT license are reviewed.
- [ ] Release notes and version are prepared.
- [ ] Owner explicitly approves publishing the repository publicly.
