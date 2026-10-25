
#import "KDUSettingsIntegration.h"
#import "KDUSettingsController.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@implementation KDUSettingsIntegration



+ (void)installHooks {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self scanForSettingsPage];
    });
}

+ (void)scanForSettingsPage {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self scanForSettingsPage];
        });
        return;
    }

    // 仅扫描当前已显示的设置页面，不修改未知的抖音内部类。
    for (UIWindow *window in UIApplication.sharedApplication.windows) {
        UIViewController *root = window.rootViewController;
        [self inspectController:root];
    }
}

+ (void)inspectController:(UIViewController *)controller {
    if (!controller) return;

    if ([controller isKindOfClass:UINavigationController.class]) {
        UINavigationController *nav = (UINavigationController *)controller;
        for (UIViewController *child in nav.viewControllers) {
            [self inspectController:child];
        }
    }

    for (UIViewController *child in controller.childViewControllers) {
        [self inspectController:child];
    }

    if ([controller isKindOfClass:UITabBarController.class]) {
        UITabBarController *tab = (UITabBarController *)controller;
        for (UIViewController *child in tab.viewControllers) {
            [self inspectController:child];
        }
    }

    // 暂不猜测抖音私有类名，避免误改其他页面。
}

@end
