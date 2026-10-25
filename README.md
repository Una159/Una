# K-Douyin Ultra — shared-source starter

A modular Objective-C / Logos starter project intended for **authorized local testing** of a Douyin/iOS UI enhancement tweak. The codebase is shared between a Theos `.deb` build and a raw `.dylib` build for an IPA injection workflow.

## What is implemented in this starter

- Feature registry with stable IDs and categories.
- Persistent preferences stored in `NSUserDefaults` (inside the target app sandbox).
- Settings screen with search, categories, and switches.
- A small floating launcher to open the settings screen.
- Placeholder modules for video, download, interface, privacy, comments, messages, and live UI.
- Compatibility/version diagnostics placeholder.

## Important limits

This is a **starter scaffold**, not a finished all-features Douyin plugin. The feature modules are registered but mostly disabled placeholders; they do not magically implement downloading, ad removal, private API behavior, or server-side capabilities. Those need separate implementation and testing against the exact Douyin build. The current app version is intentionally not hardcoded.

The floating launcher and settings UI are generic UIKit code. Whether they appear in a particular IPA injection tool depends on that tool loading the dylib into the correct process and preserving required dependencies/signing.

## Build: Theos `.deb`

Install Theos and an iOS SDK on a macOS/Linux build host, then:

```sh
make package
```

For a rootless jailbreak target, configure the Theos rootless environment as appropriate for your setup, then:

```sh
make package THEOS_PACKAGE_SCHEME=rootless
```

Review `control` and bundle identifiers before packaging.

## Build: raw dylib for IPA injection

```sh
make clean
make KDU_BUILD_IPA=1
```

This builds the tweak/dylib target with the same source files. The exact output path depends on your Theos setup. The raw dylib is **not itself an IPA**: inject it into a copy of the target IPA with your chosen injection tool, then re-sign the IPA. Do not install the `.deb` through an IPA injector.

## Next steps

1. Confirm exact Douyin version/build number and injection tool.
2. Build and verify the launcher/settings screen first.
3. Implement one module at a time; use logs and a clean rollback path.
4. Test on a spare device or a restorable IPA copy before daily use.
