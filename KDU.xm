#import "KDUFloatingLauncher.h"
#import <UIKit/UIKit.h>
#import "KDUConfigManager.h"
#import "KDUFeatureRegistry.h"
#import "KDUCompatibility.h"
#import "KDUSettingsIntegration.h"

#pragma mark - Initialization

%ctor {
    @autoreleasepool {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[KDUConfigManager shared] loadDefaultsIfNeeded];
            [[KDUFeatureRegistry shared] registerBuiltInFeatures];
            [[KDUCompatibility shared] refreshDiagnostics];
            [[KDUFloatingLauncher shared] installIfNeeded];
        });
    }
}

#pragma mark - Controller View Hook

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    // Avoid collecting user-visible labels or writing the app's view tree
    // to a temporary file. Settings integration only needs a throttled,
    // read-only inspection of the currently visible controller.
    static CFTimeInterval lastSettingsScan = 0;
    CFTimeInterval now = CACurrentMediaTime();
    if (now - lastSettingsScan < 0.75) return;
    lastSettingsScan = now;

    dispatch_async(dispatch_get_main_queue(), ^{
        [[KDUFloatingLauncher shared] installIfNeeded];
        [KDUSettingsIntegration scanForSettingsPage];
    });
}

%end
