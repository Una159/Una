
#import <UIKit/UIKit.h>
#import "KDUConfigManager.h"
#import "KDUFeatureRegistry.h"
#import "KDUCompatibility.h"
#import "KDUSettingsIntegration.h"

%ctor {
    @autoreleasepool {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[KDUConfigManager shared] loadDefaultsIfNeeded];
            [[KDUFeatureRegistry shared] registerBuiltInFeatures];
            [[KDUCompatibility shared] refreshDiagnostics];
            [KDUSettingsIntegration installHooks];
        });
    }
}
