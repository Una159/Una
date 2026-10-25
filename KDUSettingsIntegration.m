#import "KDUSettingsIntegration.h"
#import "KDUSettingsController.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const NSInteger KDUSettingsEntryTag = 0x4B445532;

@interface UIViewController (KDUSettingsIntegration)
- (void)kdu_viewDidAppear:(BOOL)animated;
@end

@interface KDUSettingsIntegration ()
+ (void)inspectController:(UIViewController *)controller;
+ (void)addEntryIfSettingsController:(UIViewController *)controller;
+ (void)collectTextFromView:(UIView *)view into:(NSMutableString *)result depth:(NSUInteger)depth;
+ (UITableView *)findTableView:(UIView *)view depth:(NSUInteger)depth;
+ (void)openPluginSettings:(UIButton *)sender;
+ (UIViewController *)topController:(UIViewController *)controller;
@end

@implementation KDUSettingsIntegration

+ (void)installHooks {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original = class_getInstanceMethod(UIViewController.class, @selector(viewDidAppear:));
        Method replacement = class_getInstanceMethod(UIViewController.class, @selector(kdu_viewDidAppear:));
        if (original && replacement) {
            method_exchangeImplementations(original, replacement);
        }
    });

    // One initial scan handles a settings page that is already visible at injection time.
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

    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class] ||
            scene.activationState != UISceneActivationStateForegroundActive) continue;

        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.hidden || window.alpha < 0.01 || !window.rootViewController) continue;
            [self inspectController:window.rootViewController];
        }
    }
}

+ (void)inspectController:(UIViewController *)controller {
    if (!controller) return;
    [self addEntryIfSettingsController:controller];

    // Visit each controller once per initial scan. Avoid scanning the same navigation/tab
    // children twice through both childViewControllers and container-specific arrays.
    if ([controller isKindOfClass:UINavigationController.class]) {
        for (UIViewController *child in ((UINavigationController *)controller).viewControllers) {
            [self inspectController:child];
        }
    } else if ([controller isKindOfClass:UITabBarController.class]) {
        for (UIViewController *child in ((UITabBarController *)controller).viewControllers) {
            [self inspectController:child];
        }
    } else {
        for (UIViewController *child in controller.childViewControllers) {
            [self inspectController:child];
        }
    }

    if (controller.presentedViewController) {
        [self inspectController:controller.presentedViewController];
    }
}

+ (void)addEntryIfSettingsController:(UIViewController *)controller {
    if ([controller isKindOfClass:KDUSettingsController.class] ||
        !controller.isViewLoaded || !controller.view.window) return;

    // Fast path: once our entry is in the table header, don't traverse the view again.
    UITableView *table = [self findTableView:controller.view depth:0];
    if (!table || [table.tableHeaderView viewWithTag:KDUSettingsEntryTag]) return;

    NSMutableString *visibleText = [NSMutableString string];
    [self collectTextFromView:controller.view into:visibleText depth:0];
    NSArray<NSString *> *markers = @[
        @"è´¦å·ä¸å®å¨",
        @"éç¨è®¾ç½®",
        @"éç§æ¿ç­",
        @"åºç¨æé",
        @"ä¸ªäººä¿¡æ¯ç®¡ç",
        @"ç¨æ·åè®®",
        @"ä¸ªäººä¿¡æ¯æ¶éæ¸å",
        @"ç¬¬ä¸æ¹ä¿¡æ¯å±äº«æ¸å"
    ];

    BOOL matched = NO;
    for (NSString *marker in markers) {
        if ([visibleText containsString:marker]) {
            matched = YES;
            break;
        }
    }
    if (!matched) return;

    UIView *oldHeader = table.tableHeaderView;
    CGFloat oldHeight = oldHeader ? MAX(1.0, CGRectGetHeight(oldHeader.frame)) : 0.0;
    CGFloat tableWidth = CGRectGetWidth(table.bounds);
    if (tableWidth <= 0) tableWidth = CGRectGetWidth(controller.view.bounds);
    if (tableWidth <= 0) return;

    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableWidth, 62.0 + oldHeight)];
    container.backgroundColor = UIColor.clearColor;

    UIButton *entry = [UIButton buttonWithType:UIButtonTypeSystem];
    entry.tag = KDUSettingsEntryTag;
    entry.frame = CGRectMake(16, 7, MAX(0, tableWidth - 32), 48);
    entry.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    entry.backgroundColor = [UIColor secondarySystemBackgroundColor];
    entry.layer.cornerRadius = 12;
    entry.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    entry.contentEdgeInsets = UIEdgeInsetsMake(0, 16, 0, 16);
    [entry setTitle:@"K-Douyin Ultra" forState:UIControlStateNormal];
    [entry setTitleColor:UIColor.labelColor forState:UIControlStateNormal];
    entry.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [entry addTarget:self action:@selector(openPluginSettings:) forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:entry];

    if (oldHeader) {
        oldHeader.frame = CGRectMake(0, 62.0, tableWidth, oldHeight);
        oldHeader.autoresizingMask |= UIViewAutoresizingFlexibleWidth;
        [container addSubview:oldHeader];
    }

    table.tableHeaderView = container;
}

+ (void)collectTextFromView:(UIView *)view into:(NSMutableString *)result depth:(NSUInteger)depth {
    if (!view || depth > 12 || view.hidden || view.alpha < 0.05) return;

    if ([view isKindOfClass:UILabel.class]) {
        NSString *text = ((UILabel *)view).text;
        if (text.length) [result appendFormat:@" %@", text];
    } else if ([view isKindOfClass:UIButton.class]) {
        NSString *text = ((UIButton *)view).currentTitle;
        if (text.length) [result appendFormat:@" %@", text];
    }

    for (UIView *child in view.subviews) {
        [self collectTextFromView:child into:result depth:depth + 1];
    }
}

+ (UITableView *)findTableView:(UIView *)view depth:(NSUInteger)depth {
    if (!view || depth > 12) return nil;
    if ([view isKindOfClass:UITableView.class]) return (UITableView *)view;

    for (UIView *child in view.subviews) {
        UITableView *found = [self findTableView:child depth:depth + 1];
        if (found) return found;
    }
    return nil;
}

+ (void)openPluginSettings:(UIButton *)sender {
    UIWindow *window = sender.window;
    UIViewController *top = [self topController:window.rootViewController];
    if (!top || [top isKindOfClass:KDUSettingsController.class] || top.presentedViewController) return;

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:[KDUSettingsController new]];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    [top presentViewController:nav animated:YES completion:nil];
}

+ (UIViewController *)topController:(UIViewController *)controller {
    if (!controller) return nil;
    if (controller.presentedViewController) return [self topController:controller.presentedViewController];
    if ([controller isKindOfClass:UINavigationController.class]) {
        return [self topController:((UINavigationController *)controller).visibleViewController];
    }
    if ([controller isKindOfClass:UITabBarController.class]) {
        return [self topController:((UITabBarController *)controller).selectedViewController];
    }
    return controller;
}

@end

@implementation UIViewController (KDUSettingsIntegration)
- (void)kdu_viewDidAppear:(BOOL)animated {
    // Swizzled implementation calls the original implementation first.
    [self kdu_viewDidAppear:animated];

    // Only inspect the controller that just appeared. Do not recursively scan every window
    // after every viewDidAppear; that repeated whole-app traversal caused avoidable lag.
    dispatch_async(dispatch_get_main_queue(), ^{
        [KDUSettingsIntegration addEntryIfSettingsController:self];
    });
}
@end
