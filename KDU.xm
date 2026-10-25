#import <UIKit/UIKit.h>
#import "KDUConfigManager.h"
#import "KDUFeatureRegistry.h"
#import "KDUCompatibility.h"
#import "KDUFloatingLauncher.h"

%group KDUAwemeHooks
%hook UIApplication
- (void)applicationDidBecomeActive:(UIApplication *)application {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[KDUConfigManager shared] loadDefaultsIfNeeded];
        [[KDUFeatureRegistry shared] registerBuiltInFeatures];
        [[KDUCompatibility shared] refreshDiagnostics];
        [[KDUFloatingLauncher shared] installIfNeeded];
    });
}
%end
%end

%ctor {
    @autoreleasepool {
        %init(KDUAwemeHooks);
    }
}
