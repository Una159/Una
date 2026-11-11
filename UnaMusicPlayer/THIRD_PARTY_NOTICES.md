# Third-party notices and dependency inventory

Status: preliminary inventory for release review. This file is not a substitute for checking the exact versions and license texts resolved by the release build.

## Native iOS application

- The app uses Apple platform frameworks, including SwiftUI, AVFoundation and MediaPlayer. These are supplied by the Apple SDK; consult Apple's current platform terms.
- No third-party Swift package manifest or CocoaPods lockfile is currently tracked in this project subtree.
- App artwork is the owner-selected Una icon. Confirm provenance and rights for any additional artwork, fonts, sounds or bundled media before release.

## Cloudflare Gateway tooling

The gateway's `package.json` declares these direct development dependencies:

| Package | Declared version | Purpose | Release check |
|---|---:|---|---|
| `typescript` | `^5.7.3` | Type checking | Verify exact resolved version and license from npm metadata |
| `wrangler` | `^4.0.0` | Cloudflare local development/deployment CLI | Verify exact resolved version and license from npm metadata |

These are development dependencies; they are not intentionally bundled into the iOS application or served to app users.

## Provider adapters and services

No provider adapter implementation is vendored in this repository. The gateway expects separately deployed NetEase-, Kugou-, Qishui- and QQ Music-compatible services. Their source repositories, exact versions, licenses, attribution requirements, terms of service and redistribution rights have **not** yet been approved. Do not bundle, redistribute or deploy an adapter until that review is complete.

Provider names and trademarks remain the property of their respective owners. Una is an independent project and is not endorsed by the providers.

## Required release procedure

1. Run `npm install` in `CloudflareGateway/` and commit the resulting lockfile after review.
2. Generate a software bill of materials (SBOM), for example with `npm sbom --json`, and retain the release copy.
3. Review every direct and transitive dependency's exact version, license, advisories and maintenance status.
4. Add required license texts and notices for any dependency distributed with the release.
5. Record each deployed provider adapter's repository URL, immutable commit/tag, license, attribution and deployment owner.
6. Re-check all artwork, fonts, sounds and other bundled assets.
7. Update this document with the verified results before public distribution.

## Current release status

- [ ] Exact npm dependency tree and lockfile reviewed.
- [ ] SBOM generated and reviewed.
- [ ] Provider adapter licenses and terms approved.
- [ ] Third-party notices/license texts complete.
- [ ] All bundled artwork, fonts and sounds cleared.
