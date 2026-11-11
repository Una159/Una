# Reconstruction status and evidence boundary

This project is being rebuilt from a supplied ARM64 Mach-O image. The source tree is not a source-equivalent decompilation: names and preference strings do not independently establish call order, defaults, selector signatures, or host-app compatibility.

## Implemented in this branch

- Rootless Theos package scaffold and GitHub Actions build workflow.
- Package injection filter restricted to the official NetEase Cloud Music bundle ID.
- Runtime diagnostic probe for six host classes already observed in the supplied binary/reference research; it reports host app/build versions and class presence without changing host behavior.
- Central preference access and a subset of observed preference-key constants.
- Reversible Objective-C instance-method replacement helper. Inherited methods are shadowed on the target class rather than mutating a superclass implementation.
- Standalone dock surface (NWDockView) with equal-width items, selection state, accessibility labels, and a system-material glass surface.
- Immutable dock state snapshot (NWDockState).

## Not yet implemented or verified

- Original host-app tab-bar discovery and safe replacement.
- Original updateTabs:selected:media: argument types and exact update semantics.
- Player lifecycle, queue synchronization, background playback, and AVPlayer ownership.
- Settings controller and complete feature-to-preference mapping.
- Search, comments, chat, sidebar, wallpaper, typography, ad suppression, and splash feature execution paths.
- Authorization request/response format, signature payload, and device binding.
- Runtime injection and device-level visual/regression testing.
- A successful GitHub Actions package build and downloadable .deb artifact.

## Safety and correctness constraints

- No guessed host class or selector is installed as a hook.
- Authorization/signature checks are not bypassed.
- The original binary is not copied into the package or overwritten.
- UI classes are isolated until the target app's actual integration points are proven.
- A successful CI package build is necessary but does not prove runtime compatibility.

For each feature, recover and record: target class, selector, type encoding, original implementation call-through, call site, preference key/default, initialization gate, and teardown behavior. Only then connect the standalone implementation to the host.
