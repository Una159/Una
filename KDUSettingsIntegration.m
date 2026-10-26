
#import "KDUSettingsIntegration.h"
#import "KDUSettingsController.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const NSInteger KDUSettingsEntryTag = 0x4B445532;

// 扫描状态只在主线程访问。
static BOOL KDUScanScheduled = NO;
static BOOL KDUScanInProgress = NO;

@interface UIViewController (KDUSettingsIntegration)
- (void)kdu_viewDidAppear:(BOOL)animated;
@end

@interface KDUSettingsIntegration ()
+ (void)requestScan;
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

#pragma mark - Install One Hook

+ (void)installHooks {
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        Class cls = UIViewController.class;

        Method original =
            class_getInstanceMethod(cls, @selector(viewDidAppear:));

        Method replacement =
            class_getInstanceMethod(cls, @selector(kdu_viewDidAppear:));

        if (original && replacement) {
            method_exchangeImplementations(original, replacement);
        }
    });

    [self requestScan];
}

#pragma mark - Coalesced Scan Request

+ (void)requestScan {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self requestScan];
        });
        return;
    }

    // 同一轮主线程事件只安排一次扫描。
    if (KDUScanScheduled || KDUScanInProgress) {
        return;
    }

    KDUScanScheduled = YES;

    dispatch_async(dispatch_get_main_queue(), ^{
        KDUScanScheduled = NO;

        if (KDUScanInProgress) {
            return;
        }

        KDUScanInProgress = YES;

        @try {
            [self scanForSettingsPage];
        } @finally {
            KDUScanInProgress = NO;
        }
    });
}

#pragma mark - Scan Active Windows

+ (void)scanForSettingsPage {
    if (!NSThread.isMainThread) {
        return;
    }

    UIApplication *application = UIApplication.sharedApplication;

    for (UIScene *scene in application.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) {
            continue;
        }

        if (scene.activationState !=
            UISceneActivationStateForegroundActive) {
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

#pragma mark - Controller Traversal

+ (void)inspectController:(UIViewController *)controller {
    if (!controller) {
        return;
    }

    [self addEntryIfSettingsController:controller];

    if ([controller isKindOfClass:UINavigationController.class]) {
        UINavigationController *navigationController =
            (UINavigationController *)controller;

        for (UIViewController *child
             in navigationController.viewControllers) {
            [self inspectController:child];
        }
    } else if ([controller isKindOfClass:UITabBarController.class]) {
        UITabBarController *tabController =
            (UITabBarController *)controller;

        for (UIViewController *child
             in tabController.viewControllers) {
            [self inspectController:child];
        }
    } else {
        for (UIViewController *child
             in controller.childViewControllers) {
            [self inspectController:child];
        }
    }

    UIViewController *presented =
        controller.presentedViewController;

    if (presented && presented != controller) {
        [self inspectController:presented];
    }
}

#pragma mark - Detect Native Settings Page

+ (void)addEntryIfSettingsController:(UIViewController *)controller {
    if (!controller ||
        [controller isKindOfClass:KDUSettingsController.class] ||
        !controller.isViewLoaded ||
        !controller.view.window) {
        return;
    }

    UITableView *table =
        [self findTableView:controller.view depth:0];

    if (!table) {
        return;
    }

    // 不重复插入同一个入口。
    if ([table.tableHeaderView viewWithTag:KDUSettingsEntryTag]) {
        return;
    }

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

    if (!matched) {
        return;
    }

    CGFloat tableWidth = CGRectGetWidth(table.bounds);

    if (tableWidth <= 0) {
        tableWidth = CGRectGetWidth(controller.view.bounds);
    }

    if (tableWidth <= 0) {
        return;
    }

    UIView *oldHeader = table.tableHeaderView;

    CGFloat oldHeight = oldHeader
        ? MAX(1.0, CGRectGetHeight(oldHeader.frame))
        : 0.0;

    UIView *container = [[UIView alloc]
        initWithFrame:CGRectMake(
            0,
            0,
            tableWidth,
            62.0 + oldHeight
        )];

    container.backgroundColor = UIColor.clearColor;
    container.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    container.tag = KDUSettingsEntryTag;

    UIButton *entry = [UIButton buttonWithType:UIButtonTypeSystem];

    entry.frame = CGRectMake(
        16,
        7,
        MAX(0, tableWidth - 32),
        48
    );

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
        [UIFont systemFontOfSize:16
                          weight:UIFontWeightSemibold];

    [entry addTarget:self
              action:@selector(openPluginSettings:)
    forControlEvents:UIControlEventTouchUpInside];

    [container addSubview:entry];

    // 保留原有 Header，不直接丢弃。
    if (oldHeader) {
        oldHeader.frame = CGRectMake(
            0,
            62.0,
            tableWidth,
            oldHeight
        );

        oldHeader.autoresizingMask |=
            UIViewAutoresizingFlexibleWidth;

        [container addSubview:oldHeader];
    }

    table.tableHeaderView = container;
}

#pragma mark - Collect Visible Text

+ (void)collectTextFromView:(UIView *)view
                       into:(NSMutableString *)result
                      depth:(NSUInteger)depth {
    if (!view ||
        depth > 12 ||
        view.hidden ||
        view.alpha < 0.05) {
        return;
    }

    if ([view isKindOfClass:UILabel.class]) {
        NSString *text = ((UILabel *)view).text;

        if (text.length > 0) {
            [result appendFormat:@" %@", text];
        }
    } else if ([view isKindOfClass:UIButton.class]) {
        NSString *text =
            ((UIButton *)view).currentTitle;

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

#pragma mark - Find Table View

+ (UITableView *)findTableView:(UIView *)view
                         depth:(NSUInteger)depth {
    if (!view || depth > 12) {
        return nil;
    }

    if ([view isKindOfClass:UITableView.class]) {
        return (UITableView *)view;
    }

    for (UIView *child in view.subviews) {
        UITableView *found =
            [self findTableView:child depth:depth + 1];

        if (found) {
            return found;
        }
    }

    return nil;
}

#pragma mark - Open Plugin Settings

+ (void)openPluginSettings:(UIButton *)sender {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self openPluginSettings:sender];
        });
        return;
    }

    UIWindow *window = sender.window;

    if (!window || !window.rootViewController) {
        return;
    }

    UIViewController *top =
        [self topController:window.rootViewController];

    if (!top ||
        [top isKindOfClass:KDUSettingsController.class] ||
        top.isBeingDismissed ||
        top.presentedViewController) {
        return;
    }

    KDUSettingsController *settingsController =
        [KDUSettingsController new];

    UINavigationController *navigationController =
        [[UINavigationController alloc]
            initWithRootViewController:settingsController];

    navigationController.modalPresentationStyle =
        UIModalPresentationPageSheet;

    [top presentViewController:navigationController
                      animated:YES
                    completion:nil];
}

#pragma mark - Resolve Top Controller

+ (UIViewController *)topController:(UIViewController *)controller {
    if (!controller) {
        return nil;
    }

    if (controller.presentedViewController) {
        return [self topController:
            controller.presentedViewController];
    }

    if ([controller isKindOfClass:UINavigationController.class]) {
        UINavigationController *navigationController =
            (UINavigationController *)controller;

        return [self topController:
            navigationController.visibleViewController];
    }

    if ([controller isKindOfClass:UITabBarController.class]) {
        UITabBarController *tabController =
            (UITabBarController *)controller;

        return [self topController:
            tabController.selectedViewController];
    }

    return controller;
}

@end

#pragma mark - Single Lifecycle Hook

@implementation UIViewController (KDUSettingsIntegration)

- (void)kdu_viewDidAppear:(BOOL)animated {
    // 交换实现后，此调用会进入 UIKit 原始的 viewDidAppear:。
    [self kdu_viewDidAppear:animated];

    [KDUSettingsIntegration requestScan];
}

@end
