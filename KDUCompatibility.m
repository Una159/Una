#import "KDUCompatibility.h"
#import <UIKit/UIKit.h>

@implementation KDUCompatibility {
    NSDictionary *_lastDiagnostics;
}
+ (instancetype)shared {
    static KDUCompatibility *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [KDUCompatibility new]; });
    return instance;
}
- (void)refreshDiagnostics {
    NSString *version = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"unknown";
    NSString *build = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"unknown";
    _lastDiagnostics = @{
        @"bundleIdentifier": NSBundle.mainBundle.bundleIdentifier ?: @"unknown",
        @"appVersion": version,
        @"appBuild": build,
        @"systemVersion": UIDevice.currentDevice.systemVersion ?: @"unknown",
        @"status": @"diagnostics-only; compatibility not yet certified"
    };
}
- (NSDictionary *)diagnostics {
    if (!_lastDiagnostics) [self refreshDiagnostics];
    return _lastDiagnostics ?: @{};
}
@end
