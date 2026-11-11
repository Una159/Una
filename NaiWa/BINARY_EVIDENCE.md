# NaiWa binary evidence ledger

Analyzed input: user-supplied `NaiWa.dylib`, Mach-O 64-bit ARM64, 2,256,416 bytes, `cryptid=0`. The original binary is kept outside the package source tree.

## Runtime and host identity

Observed in the binary:

- Host bundle identifier: `com.netease.cloudmusic`
- Main executable string: `neteasemusic`
- URL scheme: `orpheus`
- Plugin version string: `0.0.22`
- 72 entries in `__objc_classlist`
- Host class strings include `NMSettingTabViewController`, `NMRCTPageViewController`, `NMTabBarController`, `NMMainViewController`, `NMHomeTabbarView`, and `NMAppDelegate`

The host app's exact version is not embedded as a confirmed target version. A separate modern public plugin project reports testing against NetEase Music 9.6.09 (7516), but that does not prove NaiWa targeted the same build.

## NaiWa-owned runtime classes and selectors

Observed class names include:

- `NWSettings_e735c0198aa0e327b4f2`
- `NWSettings_74aaab5f302b24a8f33f`
- `NWPlayer_e9edc045db6503bfd9f4`
- `NaiWa.SystemDock`
- `NWPlayer`
- `NWSettings`

Observed settings selectors include `viewDidLoad`, `viewWillAppear:`, `viewDidLayoutSubviews`, `rebuild`, `changed:`, `settingsAuthorized`, and `applyAuthorizationToCell:`.

Observed player selectors include `initWithFrame:`, `intrinsicContentSize`, `open`, `toggle`, `queue`, `playButtonClicked:`, and `playingListClicked:`.

Observed dock selectors include `updateTabs:selected:media:`, `performMediaAction:`, `viewDidLayoutSubviews`, `hitTest:withEvent:`, `open`, and `longPress:`.

These are string/runtime metadata observations. The complete method type encodings, call graph, and all original IMP relationships are not yet recovered.

## Initialization observations

- An init-offset entry points to code near `0xd268`, which dispatches a once-only initialization block near `0x1e8048`.
- The block reads `NSUserDefaults`.
- Code near `0x4030` checks the OS major version against `0x1a` (26) and performs a class lookup.
- Runtime/configuration gating appears near `0x40fc`.
- UI-related initialization is visible near `0xd2c4`, but the exact controller and ordering remain unresolved.

The iOS 26 check is evidence of a compatibility gate, not proof that earlier iOS releases are unsupported; the surrounding branch and fallback still need tracing.

## Feature groups observed

Entry-point-like strings:

- Appearance, menus, top tabs, edge fades, revision surfaces, typography
- Search and search extras, chart limits
- Detail glass, comment composers, chat, panels, sidebar backdrop
- Wallpaper hierarchy, splash handling, ad hiding, control hiding

Preference strings include settings glass, tab/player/comment/message glass, popup/sidebar glass, dock display mode, search filtering, font/color, wallpaper path/kind, hidden controls and positions, splash/ad privacy options, and performance settings. See `REVERSE_ENGINEERING.md` for the extracted key list.

## Authorization and privacy boundary

The binary references Security.framework key creation/verification and Keychain APIs, SHA-256, RSA PKCS#1 v1.5 SHA-256 verification, and an upload task method named `uploadEnvelope:identity:message:session:`. Strings include `device.v1`, `expired`, `device_limit`, and `unsupported-device`.

The exact server URL, signed payload format, public key, and device-binding algorithm have not been reconstructed. The implementation must preserve legitimate authorization and must not patch out signature/device checks.

## Current build/integration boundary

The branch now has a bundle-scoped diagnostic tweak and a rootless Theos package workflow. It does not yet install functional host hooks. The current CI run is repeatedly cancelled before a job step starts, so no successful package artifact has been produced. This is an infrastructure/runner blocker, not evidence of a compiler error.

Next reverse-engineering priorities:

1. Recover method metadata and IMP addresses for the three NaiWa-owned controller classes.
2. Trace the Dock manager's host tab-bar capture and restoration.
3. Recover settings data model, defaults, and cell construction.
4. Trace authorization request/response and key storage without bypassing it.
5. Validate on the exact installed NetEase Music build before enabling any hook.
