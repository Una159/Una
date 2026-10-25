#import "KDUFloatingLauncher.h"
#import "KDUSettingsController.h"
#import <UIKit/UIKit.h>

static NSInteger const KDUFloatingTag = 0x4B445531;

@implementation KDUFloatingLauncher
+ (instancetype)shared {
    static KDUFloatingLauncher *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [KDUFloatingLauncher new]; });
    return instance;
}
- (UIWindow *)activeWindow {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive || ![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) if (window.isKeyWindow) return window;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return UIApplication.sharedApplication.keyWindow;
#pragma clang diagnostic pop
}
- (void)installIfNeeded {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self installIfNeeded]; });
        return;
    }
    UIWindow *window = [self activeWindow];
    if (!window || [window viewWithTag:KDUFloatingTag]) return;
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tag = KDUFloatingTag;
    button.frame = CGRectMake(MAX(12, window.bounds.size.width - 62), window.bounds.size.height * 0.62, 48, 48);
    button.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
    if (@available(iOS 13.0, *)) {
        button.backgroundColor =
            [UIColor.secondarySystemBackgroundColor colorWithAlphaComponent:0.78];
        button.layer.borderColor =
            [UIColor.separatorColor colorWithAlphaComponent:0.65].CGColor;
    } else {
        button.backgroundColor =
            [UIColor colorWithWhite:0.16 alpha:0.92];
        button.layer.borderColor =
            [UIColor colorWithWhite:1 alpha:0.35].CGColor;
    }
    button.layer.cornerRadius = 24;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.layer.borderWidth = 1;
    button.layer.shadowColor = UIColor.blackColor.CGColor;
    button.layer.shadowOpacity = 0.12;
    button.layer.shadowRadius = 12;
    button.layer.shadowOffset = CGSizeMake(0, 4);
    [button setTitle:@"K" forState:UIControlStateNormal];
    [button setTitleColor:UIColor.labelColor forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    button.accessibilityLabel = @"打开 K-Douyin Ultra 设置";
    [button addTarget:self action:@selector(openSettings) forControlEvents:UIControlEventTouchUpInside];
    [window addSubview:button];
}
- (UIViewController *)topController:(UIViewController *)controller {
    UIViewController *current = controller;
    while (current.presentedViewController) current = current.presentedViewController;
    if ([current isKindOfClass:UINavigationController.class]) return [self topController:((UINavigationController *)current).visibleViewController];
    if ([current isKindOfClass:UITabBarController.class]) return [self topController:((UITabBarController *)current).selectedViewController];
    return current;
}
- (void)openSettings {
    UIWindow *window = [self activeWindow];
    UIViewController *root = window.rootViewController;
    if (!root) return;
    UIViewController *top = [self topController:root];
    if ([top isKindOfClass:KDUSettingsController.class]) return;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:[KDUSettingsController new]];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    [top presentViewController:nav animated:YES completion:nil];
}
@end
