# Real iPhone injection validation

## Scope

This is the only test track that can certify MobileSubstrate injection. A successful iOS Simulator run, a successful Theos build, or a valid DEB package is not proof that the tweak loads inside Douyin.

## Preconditions

- A test iPhone that the owner is authorized to modify.
- A jailbreak/injection environment compatible with the device's iOS version and CPU architecture.
- A supported Douyin build installed from a trusted source.
- A backup and a recovery path before installing test packages.
- A package built from the exact commit SHA recorded in the report.

Do not test on a primary device until the package has passed static checks and can be removed cleanly.

## Validation sequence

1. Record device model, iOS version/build, jailbreak/bootstrap and injection framework versions.
2. Record Douyin bundle ID and exact app version/build.
3. Inspect the DEB control metadata and installed file list.
4. Confirm the dylib architecture matches the device (arm64/arm64e as appropriate).
5. Confirm the filter plist targets the intended bundle ID: `com.ss.iphone.ugc.Aweme`.
6. Install the package using the package manager appropriate to the device's bootstrap.
7. Respring/restart the target app as required by the injection environment.
8. Launch Douyin and confirm the process loads the dylib using the injection framework's own diagnostics/logs.
9. Confirm the K-Douyin Ultra entry appears in the intended settings page.
10. Exercise each implemented feature independently; record expected and actual behavior.
11. Repeat launch/close cycles and inspect crash reports and device logs.
12. Remove the package and confirm Douyin launches normally without the tweak.

## Evidence required for PASS

- Device and software version details.
- Package filename, version, SHA-256 and source commit SHA.
- Injection log showing the target process and dylib load (redact personal data).
- Screenshot of the plugin entry and tested screens.
- Feature-by-feature result table.
- Crash/log review and uninstall/recovery result.

## Failure classification

- **Package/install failure:** package metadata, dependency, architecture or bootstrap mismatch.
- **Not injected:** target process starts but the framework does not load the dylib.
- **Injected, entry missing:** dylib loads but settings integration does not detect/modify the intended page.
- **Entry visible, feature ineffective:** UI appears but the selected feature has no working implementation.
- **Crash/regression:** app crashes, hangs or loses normal behavior after injection.

A feature is not certified merely because its toggle is visible. Only implemented behavior tested on the target Douyin version may be marked PASS.
