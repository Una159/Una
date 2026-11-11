# Una

**An independent native music player for iOS.**

Una is a SwiftUI and AVFoundation music player designed around a local-first library, a focused listening experience and optional music-source integrations. The project is being prepared for an MIT-licensed public release; it is **not yet announced as production-ready**.

## Project principles

- **Local-first:** the core player should remain useful without connecting to an online music provider.
- **Native iOS:** use system audio and media APIs where appropriate.
- **Modular sources:** optional provider integrations must not make the local library dependent on third-party services.
- **Privacy by default:** never commit or log account cookies, QR sessions, API keys or personal library data.
- **Respect access rights:** playback is limited to media the user is authorized to access. Una does not bypass DRM, paid access, geographic restrictions or provider controls.

## Current app capabilities

- Import local audio through the system file picker.
- Store and browse a local music library.
- Search local tracks, artists and albums.
- Play, pause, seek, skip, shuffle and repeat.
- Basic background audio and remote-control integration.
- Dark visual design.

## Optional online music integration

The optional Cloudflare Gateway defines normalized routes for NetEase, Kugou, Qishui and QQ Music. It is a gateway scaffold, not a guarantee that upstream provider services are deployed or that real-account flows currently work.

See [Cloudflare Gateway documentation](CloudflareGateway/README.md) and [integration status](Docs/INTEGRATION_STATUS.md). Mocked CI tests are not live provider verification.

## Build the iOS app

Requirements: macOS with Xcode, an iOS 17-compatible toolchain and Swift 5 language mode.

1. Open `Una.xcodeproj`.
2. Select the `Una` scheme and an iOS Simulator or connected iPhone.
3. Configure your own signing team and bundle identifier if needed.
4. Build and run.

GitHub Actions workflows validate the simulator build and gateway. See [integration status](Docs/INTEGRATION_STATUS.md).

## Run Gateway checks

```sh
cd CloudflareGateway
npm install
npm test
```

Deployment requires your own Cloudflare account, Worker secrets, provider adapter origins and KV configuration. Never put production secrets in source control.

## Repository layout

- `Una/` — native iOS application.
- `CloudflareGateway/` — optional Cloudflare Worker API gateway.
- `Docs/` — architecture, integration and release-readiness notes.

## License

Una is intended to be distributed under the MIT License. See [LICENSE](LICENSE).

Third-party provider adapters, APIs, media, trademarks and artwork may have separate licenses and terms. The MIT license for Una does not grant rights to third-party content or services.

## Contributing and security

See [CONTRIBUTING.md](CONTRIBUTING.md), [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) and [SECURITY.md](SECURITY.md).

## Status

This is an active development project. Features present in source code may still require real-device or real-provider validation. Check integration status before relying on a capability.
