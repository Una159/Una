
#import "KDUFloatingLauncher.h"
#import <UIKit/UIKit.h>
#import "KDUConfigManager.h"
#import "KDUFeatureRegistry.h"
#import "KDUCompatibility.h"
#import "KDUSettingsIntegration.h"
#import <objc/runtime.h>

#pragma mark - Home UI Diagnostics

static BOOL KDUIsTargetAppController(UIViewController *controller) {
    if (!controller) return NO;

    NSString *name = NSStringFromClass(controller.class);
    if (name.length == 0) return NO;

    // 仅诊断抖音主应用的控制器，不处理插件设置页。
    if ([name containsString:@"KDUSettings"] ||
        [name containsString:@"KDUFeature"]) {
        return NO;
    }

    return YES;
}

static void KDUDescribeViewTree(UIView *view,
                                NSUInteger depth,
                                NSMutableString *output) {
    if (!view || depth > 12 || output.length > 18000) return;

    NSString *indent = [@"" stringByPaddingToLength:depth * 2
                                        withString:@" "
                                   startingAtIndex:0];

    CGRect frame = view.frame;

    [output appendFormat:@"%@%@ frame=(%.0f,%.0f,%.0f,%.0f) hidden=%d alpha=%.2f",
        indent,
        NSStringFromClass(view.class),
        frame.origin.x,
        frame.origin.y,
        frame.size.width,
        frame.size.height,
        view.hidden,
        view.alpha];

    if ([view isKindOfClass:UILabel.class]) {
        UILabel *label = (UILabel *)view;
        if (label.text.length > 0) {
            NSString *safeText =
                [label.text stringByReplacingOccurrencesOfString:@"\n"
                                                      withString:@" "];
            [output appendFormat:@" text=\"%@\"",
                [safeText substringToIndex:MIN(safeText.length, 80)]];
        }
    }

    if ([view isKindOfClass:UIButton.class]) {
        UIButton *button = (UIButton *)view;
        NSString *title = [button titleForState:UIControlStateNormal];
        if (title.length > 0) {
            [output appendFormat:@" buttonTitle=\"%@\"", title];
        }

        NSString *accessibilityLabel = button.accessibilityLabel;
        if (accessibilityLabel.length > 0) {
            [output appendFormat:@" accessibility=\"%@\"",
                accessibilityLabel];
        }
    }

    [output appendString:@"\n"];

    for (UIView *subview in view.subviews) {
        KDUDescribeViewTree(subview, depth + 1, output);
    }
}

static void KDUWriteHomeDiagnostics(UIViewController *controller) {
    if (!KDUIsTargetAppController(controller)) return;
    if (!controller.isViewLoaded || !controller.view.window) return;

    // 避免反复覆盖诊断文件。
    static CFTimeInterval lastWrite = 0;
    CFTimeInterval now = CACurrentMediaTime();
    if (now - lastWrite < 10.0) return;
    lastWrite = now;

    NSMutableString *report = [NSMutableString string];

    [report appendFormat:@"Controller: %@\n",
        NSStringFromClass(controller.class)];
    [report appendFormat:@"Bundle: %@\n",
        NSBundle.mainBundle.bundleIdentifier ?: @"unknown"];
    [report appendFormat:@"Screen: %@\n",
        NSStringFromCGRect(controller.view.bounds)];

    KDUDescribeViewTree(controller.view, 0, report);

    NSString *path =
        [NSTemporaryDirectory() stringByAppendingPathComponent:
            @"KDU-Home-ViewTree.txt"];

    NSError *error = nil;
    BOOL written =
        [report writeToFile:path
                 atomically:YES
                   encoding:NSUTF8StringEncoding
                      error:&error];

    if (written) {
        NSLog(@"[KDU] View diagnostic written: %@", path);
    } else {
        NSLog(@"[KDU] View diagnostic failed: %@", error);
    }
}

#pragma mark - Initialization

%ctor {
    @autoreleasepool {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[KDUConfigManager shared] loadDefaultsIfNeeded];
            [[KDUFeatureRegistry shared] registerBuiltInFeatures];
            [[KDUCompatibility shared] refreshDiagnostics];
            [KDUSettingsIntegration installHooks];
            [[KDUFloatingLauncher shared] installIfNeeded];
        });
    }
}

#pragma mark - Controller View Hook

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    dispatch_async(dispatch_get_main_queue(), ^{
        KDUWriteHomeDiagnostics(self);
    });
}

%end
