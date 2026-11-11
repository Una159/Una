# NaiWa reconstruction

Isolated Theos/rootless build target on the naiwa-reconstruction branch.

## Current status
- Build scaffold and CI workflow: committed.
- Preference access, runtime hook helper, feature-key registry: committed.
- Standalone dock UI/state foundation: committed.
- Original host-app hook integration: not yet verified.
- Full feature parity and device validation: not yet complete.

The supplied original NaiWa.dylib remains separate from this source tree. This reconstruction intentionally does not install guessed host-app hooks. The standalone dock view is an implementation foundation, not proof that the original dock has been fully reproduced.

## Build
From this directory in a configured Theos environment:
make package

Configured for arm64/arm64e, rootless packaging, and iOS 15+.
