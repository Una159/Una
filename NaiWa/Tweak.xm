#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// This reconstruction deliberately performs diagnostics only.
// Hooks stay disabled until each target selector and type encoding is verified.
%ctor {
    @autoreleasepool {
        NSString *bundleIdentifier = NSBundle.mainBundle.bundleIdentifier;
        if (![bundleIdentifier isEqualToString:@"com.netease.cloudmusic"]) {
            return;
        }

        NSDictionary *info = NSBundle.mainBundle.infoDictionary ?: @{};
        NSString *shortVersion = [info[@"CFBundleShortVersionString"] description] ?: @"unknown";
        NSString *buildVersion = [info[@"CFBundleVersion"] description] ?: @"unknown";

        NSArray<NSString *> *candidateClasses = @[
            @"NMSettingTabViewController",
            @"NMRCTPageViewController",
            @"NMTabBarController",
            @"NMMainViewController",
            @"NMHomeTabbarView",
            @"NMAppDelegate"
        ];

        NSMutableArray<NSString *> *present = [NSMutableArray array];
        NSMutableArray<NSString *> *missing = [NSMutableArray array];
        for (NSString *name in candidateClasses) {
            if (NSClassFromString(name)) {
                [present addObject:name];
            } else {
                [missing addObject:name];
            }
        }

        NSLog(@"[NaiWa] loaded in %@ %@ (%@)", bundleIdentifier, shortVersion, buildVersion);
        NSLog(@"[NaiWa] host class probe present=%@ missing=%@", present, missing);
        NSLog(@"[NaiWa] diagnostic-only build; no host methods have been replaced");
    }
}
