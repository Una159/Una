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
    _lastDiagnostics = @{
        @"bundleIdentifier": NSBundle.mainBundle.bundleIdentifier ?: @"unknown",
        @"appVersion": [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"unknown",
        @"appBuild": [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"unknown",
        @"systemVersion": UIDevice.currentDevice.systemVersion ?: @"unknown",
        @"status": @"scaffold only; target-version hooks not certified"
    };
}
- (NSDictionary *)diagnostics {
    if (!_lastDiagnostics) [self refreshDiagnostics];
    return _lastDiagnostics ?: @{};
}
@end
