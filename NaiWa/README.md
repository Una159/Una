# NaiWa reconstruction

This directory is an isolated Theos/rootless build target on the `naiwa-reconstruction` branch.

## Current status

- Build scaffold: added.
- Original binary analysis: separate from this source tree.
- Runtime hooks and feature implementations: not yet reconstructed.
- Device validation: not yet performed.

The current entry point intentionally performs no host-app modification. This scaffold is not a functional replacement for the original `NaiWa.dylib`.

## Build

From this directory in a Theos environment:

```sh
make package
```

The target is configured for arm64/arm64e, rootless packaging, and iOS 15+.
