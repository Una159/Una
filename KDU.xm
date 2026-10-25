#import <UIKit/UIKit.h>
#import "Sources/Core/KDUConfigManager.h"
#import "Sources/Core/KDUFeatureRegistry.h"
#import "Sources/Core/KDUCompatibility.h"
#import "Sources/Settings/KDUFloatingLauncher.h"

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
