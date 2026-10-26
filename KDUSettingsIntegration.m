
#import "KDUSettingsIntegration.h"
#import "KDUSettingsController.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const NSInteger KDUSettingsEntryTag = 0x4B445532;

@interface UIViewController (KDUSettingsIntegration)
- (void)kdu_viewWillAppear:(BOOL)animated;
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

#pragma mark - Hook Installation

+ (void)installHooks {
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        Class cls = UIViewController.class;

        Method originalWill =
            class_getInstanceMethod(cls, @selector(viewWillAppear:));
        Method replacementWill =
            class_getInstanceMethod(cls, @selector(kdu_viewWillAppear:));

        if (originalWill && replacementWill) {
            method_exchangeImplementations(originalWill, replacementWill);
        }

        Method originalDid =
            class_getInstanceMethod(cls, @selector(viewDidAppear:));
        Method replacementDid =
            class_getInstanceMethod(cls, @selector(kdu_viewDidAppear:));

        if (originalDid && replacementDid) {
            method_exchangeImplementations(originalDid, replacementDid);
        }
    });

    // 首次安装时扫描一次；后续主要在页面即将出现时检查。
    if (NSThread.isMainThread) {
        [self scanForSettingsPage];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self scanForSettingsPage];
        });
    }
}

#pragma mark - Scene Scanning

+ (void)scanForSettingsPage {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self scanForSettingsPage];
        });
        return;
    }

    UIApplication *app = UIApplication.sharedApplication;

    for (UIScene *scene in app.connectedScenes) {
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

#pragma mark - Settings Page Detection

+ (void)addEntryIfSettingsController:(UIViewController *)controller {
    if (!controller ||
        [controller isKindOfClass:KDUSettingsController.class] ||
        !controller.isViewLoaded ||
        !controller.view.window) {
        return;
    }

    UITableView *table = [self findTableView:controller.view depth:0];
    if (!table) return;

    // 同一张表只添加一次。
    if ([table viewWithTag:KDUSettingsEntryTag]) return;

    NSMutableString *visibleText = [NSMutableString string];

    [self collectTextFromView:controller.view
                         into:visibleText
                        depth:0];

    NSArray<NSString *> *markers = @[
        @"账号与安全",
        @"通用设置",
        @"隐私政策",
        @"应用权限",
        @"个人信息管理",
        @"用户协议",
        @"个人信息收集清单",
        @"第三方信息共享清单"
    ];

    NSUInteger matchedMarkerCount = 0;

    for (NSString *marker in markers) {
        if ([visibleText containsString:marker]) {
            matchedMarkerCount++;
        }
    }

    // 避免把插件入口插入无关页面。
    if (matchedMarkerCount < 2) return;

    CGFloat tableWidth = CGRectGetWidth(table.bounds);

    if (tableWidth <= 0) {
        tableWidth = CGRectGetWidth(controller.view.bounds);
    }

    if (tableWidth <= 0) return;

    UIView *oldHeader = table.tableHeaderView;

    CGFloat oldHeight = oldHeader
        ? MAX(1.0, CGRectGetHeight(oldHeader.frame))
        : 0.0;

    UIView *container = [[UIView alloc]
        initWithFrame:CGRectMake(0, 0, tableWidth, 62.0 + oldHeight)];

    container.backgroundColor = UIColor.clearColor;
    container.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    UIButton *entry = [UIButton buttonWithType:UIButtonTypeSystem];

    entry.tag = KDUSettingsEntryTag;
    entry.frame = CGRectMake(16, 7, MAX(0, tableWidth - 32), 48);
    entry.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    entry.backgroundColor = UIColor.secondarySystemBackgroundColor;
    entry.layer.cornerRadius = 12.0;
    entry.clipsToBounds = YES;
    entry.contentHorizontalAlignment =
        UIControlContentHorizontalAlignmentLeft;
    entry.contentEdgeInsets = UIEdgeInsetsMake(0, 16, 0, 16);

    [entry setTitle:@"K-Douyin Ultra"
           forState:UIControlStateNormal];

    [entry setTitleColor:UIColor.labelColor
                forState:UIControlStateNormal];

    entry.titleLabel.font =
        [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];

    [entry addTarget:self
              action:@selector(openPluginSettings:)
    forControlEvents:UIControlEventTouchUpInside];

    [container addSubview:entry];

    // 保留原有 Header 内容，避免覆盖原生设置页已有内容。
    if (oldHeader) {
        oldHeader.frame = CGRectMake(0, 62.0, tableWidth, oldHeight);
        oldHeader.autoresizingMask |= UIViewAutoresizingFlexibleWidth;
        [container addSubview:oldHeader];
    }

    table.tableHeaderView = container;
}

#pragma mark - Text Collection

+ (void)collectTextFromView:(UIView *)view
                       into:(NSMutableString *)result
                      depth:(NSUInteger)depth {
    if (!view || depth > 12 || view.hidden || view.alpha < 0.05) {
        return;
    }

    if ([view isKindOfClass:UILabel.class]) {
        NSString *text = ((UILabel *)view).text;

        if (text.length > 0) {
            [result appendFormat:@" %@", text];
        }
    } else if ([view isKindOfClass:UIButton.class]) {
        NSString *text = ((UIButton *)view).currentTitle;

        if (text.length > 0) {
            [result appendFormat:@" %@", text];
        }
    }

    for (UIView *child in view.subviews) {
        [self collectTextFromView:child
                             into:result
                            depth:depth + 1];
    }
}

#pragma mark - Table View Lookup

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

#pragma mark - Open Plugin Settings

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

#pragma mark - View Controller Hooks

@implementation UIViewController (KDUSettingsIntegration)

- (void)kdu_viewWillAppear:(BOOL)animated {
    // 调用原始 viewWillAppear:。
    [self kdu_viewWillAppear:animated];

    // 在页面即将显示时开始检查，减少入口出现延迟。
    if (NSThread.isMainThread) {
        [KDUSettingsIntegration scanForSettingsPage];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [KDUSettingsIntegration scanForSettingsPage];
        });
    }
}

- (void)kdu_viewDidAppear:(BOOL)animated {
    // 调用原始 viewDidAppear:。
    [self kdu_viewDidAppear:animated];

    // 作为后备检查，处理 viewWillAppear 时视图尚未挂到 window 的情况。
    if (NSThread.isMainThread) {
        [KDUSettingsIntegration scanForSettingsPage];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [KDUSettingsIntegration scanForSettingsPage];
        });
    }
}

@end
