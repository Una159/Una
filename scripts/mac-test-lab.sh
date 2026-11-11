#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "== K-Douyin Ultra Mac Test Lab =="
echo "Repository: $ROOT"
echo "Commit: $(git rev-parse HEAD 2>/dev/null || echo unknown)"
echo

command -v xcodebuild >/dev/null || { echo "FAIL: xcodebuild not found"; exit 2; }
command -v xcrun >/dev/null || { echo "FAIL: xcrun not found"; exit 2; }

echo "-- Xcode --"
xcodebuild -version

echo "-- iOS Simulator SDK --"
SIM_SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
echo "$SIM_SDK"
test -d "$SIM_SDK"

echo "-- Available simulators --"
xcrun simctl list devices available

echo "-- Required tweak source files --"
for f in Makefile KDU.xm KDouyinUltra.plist KDUSettingsController.m KDUConfigManager.m; do
  test -s "$f" || { echo "FAIL: missing or empty $f"; exit 3; }
  echo "OK: $f"
done

echo "-- Package filter --"
grep -q 'com.ss.iphone.ugc.Aweme' KDouyinUltra.plist || {
  echo "FAIL: expected Douyin bundle identifier missing from filter plist"
  exit 4
}

echo "-- Architecture declaration --"
grep -q 'ARCHS = arm64 arm64e' Makefile || {
  echo "WARN: Makefile does not declare the expected arm64/arm64e architectures"
}

echo
echo "PASS: Mac toolchain and source preflight completed."
echo "NOT TESTED: UIKit host-app UI, MobileSubstrate injection, Douyin runtime behavior."
echo "Reason: this repository is a Theos tweak and does not yet contain a standalone Simulator host target."
