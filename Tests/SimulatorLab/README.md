# K-Douyin Ultra — iOS Simulator Lab

This repository currently builds a Theos MobileSubstrate tweak, not a standalone iOS app/Xcode project. The simulator lab therefore separates **host-app UI validation** from **tweak injection validation**. A stock iOS Simulator cannot load a jailbreak MobileSubstrate tweak.

## Goals

1. Provide a repeatable simulator environment for UIKit layout, navigation, search, category filtering, feature details, theme changes and configuration persistence.
2. Keep simulator results separate from real-device injection results.
3. Never report injection as passed based only on a successful simulator build.

## Current source boundary

The production tweak sources are in the repository root. A future host target may reuse UIKit-only components after their dependencies are separated from Logos, MobileSubstrate and process-injection code. Do not compile `KDU.xm` into the simulator host target.

## Simulator test matrix

| Area | Test | Pass condition |
|---|---|---|
| Launch | Open host app | No crash; root settings screen appears |
| Navigation | Open feature detail and return | Correct title/content; no broken navigation |
| Search | Search a known feature; clear query | Matching rows only; all rows restored |
| Categories | Switch categories | Only selected category is shown |
| Theme | Toggle light/dark/system | Readable labels, controls and backgrounds |
| Persistence | Change a toggle, terminate, relaunch | Setting remains stored |
| Layout | iPhone SE-sized and large iPhone simulator | No clipped controls or horizontal overflow |
| Stability | Repeatedly open/close detail screens | No crash or duplicate navigation |

## Running

Run `scripts/mac-test-lab.sh` from the repository root. It checks the local Xcode toolchain, available simulators, iOS Simulator SDK, and tweak source/package metadata. It does not claim that a UIKit host app or the tweak itself has passed UI tests.

## Evidence

Store simulator screenshots, test logs and OS/device details with each run. Record the tested commit SHA. Keep a separate real-device report under `TestResults/Device/`.
