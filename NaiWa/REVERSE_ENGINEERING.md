# NaiWa binary analysis inventory

Input analyzed separately from this repository: `NaiWa.dylib` (ARM64 Mach-O).
This document records strings and Objective-C/runtime symbols observed in the binary.
A string's presence is evidence of a feature identifier, not proof that the feature
is enabled, reachable, or correctly understood.

## Observed feature entry-point strings

- `NWApplyAppearance`
- `NWApplyMenus`
- `NWApplySearch`
- `NWApplySearchExtras`
- `NWApplyDetailGlass`
- `NWApplyChartLimit`
- `NWApplyCommentComposers`
- `NWApplyAdHiding`
- `NWApplyChat`
- `NWApplyPanels`
- `NWApplySidebarBackdrop`
- `NWApplySplash`
- `NWApplyControlHiding`
- `NWApplyEdgeFades`
- `NWApplyRevisionSurfaces`
- `NWApplyTypography`
- `NWApplyWallpaperToHierarchy`

## Observed preference keys

- `com.naiwa.native.enabled`
- `com.naiwa.debug.enabled`
- `com.naiwa.debug.inspect`
- `com.naiwa.debug.allBorders`
- `com.naiwa.debug.floating`
- `com.naiwa.appearance.settingsGlass`
- `com.naiwa.appearance.cleanTop`
- `com.naiwa.appearance.cleanBottom`
- `com.naiwa.glass.tabs`
- `com.naiwa.glass.player`
- `com.naiwa.comments.glass`
- `com.naiwa.comments.input`
- `com.naiwa.messages.glass`
- `com.naiwa.appearance.detailsGlass`
- `com.naiwa.chat.bubbles`
- `com.naiwa.appearance.popupGlass`
- `com.naiwa.appearance.sidebarGlass`
- `com.naiwa.dock.tabDisplayMode`
- `com.naiwa.search.native`
- `com.naiwa.search.hideAI`
- `com.naiwa.text.font`
- `com.naiwa.text.color`
- `com.naiwa.sidebar.order`
- `com.naiwa.appearance.hideTopTabs`
- `com.naiwa.performance.frameMeter`
- `com.naiwa.performance.highRefresh`
- `com.naiwa.wallpaper.energySaving`
- `com.naiwa.privacy.skipSplash`
- `com.naiwa.privacy.hideAds`
- `com.naiwa.sidebar.blur`
- `com.naiwa.sidebar.opacity`
- `com.naiwa.wallpaper.path`
- `com.naiwa.wallpaper.kind`
- `com.naiwa.wallpaper.suspended`
- `com.naiwa.wallpaper.import`
- `com.naiwa.search.hideShortcuts`
- `com.naiwa.search.hideSuggestions`
- `com.naiwa.search.hideHistory`
- `com.naiwa.search.hideCharts`
- `com.naiwa.controls.hidden`
- `com.naiwa.controls.positions`
- `com.naiwa.text.fontFile`

## Observed runtime and media symbols

The binary contains Objective-C runtime references including
`class_getInstanceMethod`, `method_getImplementation`,
`method_setImplementation`, `class_replaceMethod`,
`class_addMethod`, `objc_getAssociatedObject`, and
`objc_setAssociatedObject`.

Media-related strings include `AVPlayerItem`, `AVPlayerLayer`,
`AVPlayerLooper`, `playButtonClicked:`, and `playingListClicked:`.

## Reconstruction boundary

The scaffold currently provides typed preference access and a reversible
method-replacement primitive. It intentionally registers no host-app hooks.
Before enabling a feature, its target class, selector, original IMP call-through,
initialization order, preference semantics, and teardown behavior must be
verified against disassembly and runtime testing.

Authorization and signature-validation code is not bypassed or replaced.
