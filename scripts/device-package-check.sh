#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 path/to/package.deb"
  exit 64
fi

DEB="$1"
test -s "$DEB" || { echo "FAIL: package not found or empty: $DEB"; exit 2; }
command -v dpkg-deb >/dev/null || { echo "FAIL: dpkg-deb is required"; exit 3; }

echo "== DEB metadata =="
dpkg-deb -I "$DEB"
echo
echo "== Package file list =="
dpkg-deb -c "$DEB"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
dpkg-deb -x "$DEB" "$TMP"

DYLIB="$TMP/Library/MobileSubstrate/DynamicLibraries/KDouyinUltra.dylib"
PLIST="$TMP/Library/MobileSubstrate/DynamicLibraries/KDouyinUltra.plist"

test -s "$DYLIB" || { echo "FAIL: expected dylib missing"; exit 4; }
test -s "$PLIST" || { echo "FAIL: filter plist missing"; exit 5; }
grep -q 'com.ss.iphone.ugc.Aweme' "$PLIST" || {
  echo "FAIL: filter plist does not target Douyin bundle ID"
  exit 6
}

echo
echo "== SHA-256 =="
shasum -a 256 "$DEB" "$DYLIB" "$PLIST"

echo
echo "PASS: package structure and target filter are valid."
echo "NOT TESTED: architecture compatibility, actual injection, runtime behavior."
if command -v lipo >/dev/null; then
  echo
  echo "== Mach-O architectures =="
  lipo -info "$DYLIB" || true
else
  echo "NOTE: lipo unavailable; install Xcode command line tools for architecture inspection."
fi
