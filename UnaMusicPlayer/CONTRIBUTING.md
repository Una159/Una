# Contributing to Una

Thank you for considering a contribution.

## Project scope

Una is an independent native iOS music player. The repository separates the iOS app from the optional Cloudflare gateway and provider adapters. Contributions should preserve the ability to use the local music player without configuring any third-party music account.

## Before opening a pull request

1. Search existing issues and pull requests.
2. For substantial changes, open an issue first to discuss scope and design.
3. Keep changes focused and include tests or a reproducible manual test plan.
4. Never include credentials, cookies, QR session tokens, private user data, or production endpoints.
5. Respect upstream provider terms, copyright, regional restrictions, subscriptions and DRM. Do not add bypasses.

## Development checks

### iOS

- Open `Una.xcodeproj` in Xcode.
- Build the `Una` scheme for an iOS Simulator.
- Test on a physical device for audio-session, background playback, route changes and lock-screen behavior when changing playback code.

### Cloudflare Gateway

From `CloudflareGateway/`:

```sh
npm install
npm test
```

Do not commit generated secrets or local environment files.

## Pull request expectations

Include:
- What changed and why.
- Screenshots for UI changes.
- Build/test results and environment.
- Any migration, configuration or security implications.
- Provider and adapter versions tested, where applicable.

By submitting a contribution, you agree that it is provided under the MIT License in this directory. You retain copyright in your contribution and grant recipients the rights described by that license.
