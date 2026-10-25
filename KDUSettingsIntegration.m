#import "KDUSettingsIntegration.h"
#import "KDUSettingsController.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const NSInteger KDUSettingsEntryTag = 0x4B445532;

@interface UIViewController (KDUSettingsIntegration)
- (void)kdu_viewDidAppear:(BOOL)animated;
@end

@interface KDUSettingsIntegration ()
+ (void)scanForSettingsPage;
+ (void)inspectController:(UIViewController *)controller;
+ (void)addEntryIfSettingsController:(UIViewController *)controller;
+ (void)collectTextFromView:(UIView *)view
                      into:(NSMutableString *)result
                     depth:(NSUInteger)depth;
+ (UITableView *)findTableView:(UIView *)view depth:(NSUInteger)depth;
+ (void)openPluginSettings:(UIButton *)sender;
+ (UIViewController *)topController:(UIViewController *)controller;
@end

@implementation KDUSettingsIntegration

+ (void)installHooks {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method original =
            class_getInstanceMethod(UIViewController.class,
                                    @selector(viewDidAppear:));
        Method replacement =
            class_getInstanceMethod(UIViewController.class,
                                    @selector(kdu_viewDidAppear:));

        if (original && replacement) {
            method_exchangeImplementations(original, replacement);
        }
    });

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
            scene.activationState != UISceneActivationStateForegroundActive) {
            continue;
        }

        UIWindowScene *windowScene = (UIWindowScene *)scene;

        for (UIWindow *window in windowScene.windows) {
            if (window.hidden ||
                window.alpha < 0.01 ||
                !window.rootViewController) {
                continue;
            }

            [self inspectController:window.rootViewController];
        }
    }
}

+ (void)inspectController:(UIViewController *)controller {
    if (!controller) return;

    [self addEntryIfSettingsController:controller];

    if ([controller isKindOfClass:UINavigationController.class]) {
        UINavigationController *nav = (UINavigationController *)controller;

        for (UIViewController *child in nav.viewControllers) {
            [self inspectController:child];
        }
    } else if ([controller isKindOfClass:UITabBarController.class]) {
        UITabBarController *tabs = (UITabBarController *)controller;

        for (UIViewController *child in tabs.viewControllers) {
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
        !controller.isViewLoaded ||
        !controller.view.window) {
        return;
    }

    UITableView *table = [self findTableView:controller.view depth:0];
    if (!table) return;

    UIView *existingEntry = [table.tableHeaderView viewWithTag:KDUSettingsEntryTag];
    if (existingEntry) return;

    NSMutableString *visibleText = [NSMutableString string];
    [self collectTextFromView:controller.view
                         into:visibleText
                        depth:0];

    // 使用正常 UTF-8 中文字符串，避免源代码中的乱码导致匹配失败。
    NSArray<NSString *> *markers = @[
        @"账号与安全",
        @"通用设置",
        @"隐私政策",
        @"应用权限",
        @"个人信息管理",
        @"用户协议",
        @"个人信息收集清单",
        @"第三方信息共享清单",
        @"设置"
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
    CGFloat oldHeight = oldHeader
        ? MAX(1.0, CGRectGetHeight(oldHeader.frame))
        : 0.0;

    CGFloat tableWidth = CGRectGetWidth(table.bounds);

    if (tableWidth <= 0) {
        tableWidth = CGRectGetWidth(controller.view.bounds);
    }

    if (tableWidth <= 0) return;

    UIView *container = [[UIView alloc]
        initWithFrame:CGRectMake(0, 0, tableWidth, 62.0 + oldHeight)];

    container.backgroundColor = UIColor.clearColor;

    UIButton *entry = [UIButton buttonWithType:UIButtonTypeSystem];
    entry.tag = KDUSettingsEntryTag;
    entry.frame = CGRectMake(16, 7, MAX(0, tableWidth - 32), 48);
    entry.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    entry.backgroundColor = UIColor.secondarySystemBackgroundColor;
    entry.layer.cornerRadius = 12.0;
    entry.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    entry.contentEdgeInsets = UIEdgeInsetsMake(0, 16, 0, 16);

    [entry setTitle:@"K-Douyin Ultra" forState:UIControlStateNormal];
    [entry setTitleColor:UIColor.labelColor forState:UIControlStateNormal];

    entry.titleLabel.font =
        [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];

    [entry addTarget:self
              action:@selector(openPluginSettings:)
    forControlEvents:UIControlEventTouchUpInside];

    [container addSubview:entry];

    if (oldHeader) {
        oldHeader.frame = CGRectMake(0, 62.0, tableWidth, oldHeight);
        oldHeader.autoresizingMask |= UIViewAutoresizingFlexibleWidth;
        [container addSubview:oldHeader];
    }

    table.tableHeaderView = container;
}

+ (void)collectTextFromView:(UIView *)view
                       into:(NSMutableString *)result
                      depth:(NSUInteger)depth {
    if (!view || depth > 12 || view.hidden || view.alpha < 0.05) {
        return;
    }

    if ([view isKindOfClass:UILabel.class]) {
        NSString *text = ((UILabel *)view).text;

        if (text.length) {
            [result appendFormat:@" %@", text];
        }
    } else if ([view isKindOfClass:UIButton.class]) {
        NSString *text = ((UIButton *)view).currentTitle;

        if (text.length) {
            [result appendFormat:@" %@", text];
        }
    }

    for (UIView *child in view.subviews) {
        [self collectTextFromView:child
                             into:result
                            depth:depth + 1];
    }
}

+ (UITableView *)findTableView:(UIView *)view depth:(NSUInteger)depth {
    if (!view || depth > 12) return nil;

    if ([view isKindOfClass:UITableView.class]) {
        return (UITableView *)view;
    }

    for (UIView *child in view.subviews) {
        UITableView *found = [self findTableView:child depth:depth + 1];

        if (found) return found;
    }

    return nil;
}

+ (void)openPluginSettings:(UIButton *)sender {
    UIWindow *window = sender.window;
    if (!window.rootViewController) return;

    UIViewController *top =
        [self topController:window.rootViewController];

    if (!top ||
        [top isKindOfClass:KDUSettingsController.class] ||
        top.presentedViewController) {
        return;
    }

    UINavigationController *nav =
        [[UINavigationController alloc]
            initWithRootViewController:[KDUSettingsController new]];

    nav.modalPresentationStyle = UIModalPresentationPageSheet;

    [top presentViewController:nav animated:YES completion:nil];
}

+ (UIViewController *)topController:(UIViewController *)controller {
    if (!controller) return nil;

    if (controller.presentedViewController) {
        return [self topController:controller.presentedViewController];
    }

    if ([controller isKindOfClass:UINavigationController.class]) {
        UINavigationController *nav = (UINavigationController *)controller;
        return [self topController:nav.visibleViewController];
    }

    if ([controller isKindOfClass:UITabBarController.class]) {
        UITabBarController *tabs = (UITabBarController *)controller;
        return [self topController:tabs.selectedViewController];
    }

    return controller;
}

@end

@implementation UIViewController (KDUSettingsIntegration)

- (void)kdu_viewDidAppear:(BOOL)animated {
    [self kdu_viewDidAppear:animated];

    dispatch_async(dispatch_get_main_queue(), ^{
        [KDUSettingsIntegration scanForSettingsPage];
    });
}

@end
