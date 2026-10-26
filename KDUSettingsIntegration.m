
#import "KDUSettingsIntegration.h"
#import "KDUSettingsController.h"

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const NSInteger KDUSettingsEntryTag = 0x4B445532;
static const void *KDUEntryContainerKey = &KDUEntryContainerKey;

@interface UIViewController (KDUSettingsIntegration)
- (void)kdu_settings_viewDidAppear:(BOOL)animated;
@end

@interface KDUSettingsIntegration ()
+ (void)inspectVisibleController:(UIViewController *)controller;
+ (void)addEntryIfSettingsController:(UIViewController *)controller;
+ (void)collectTextFromView:(UIView *)view
                       into:(NSMutableString *)result
                      depth:(NSUInteger)depth;
+ (UITableView *)findTableView:(UIView *)view depth:(NSUInteger)depth;
+ (BOOL)isNativeSettingsController:(UIViewController *)controller
                              text:(NSString *)text;
+ (void)openPluginSettings:(UIButton *)sender;
+ (UIViewController *)topController:(UIViewController *)controller;
@end

@implementation KDUSettingsIntegration

#pragma mark - Hook installation

+ (void)installHooks {
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        Class cls = UIViewController.class;

        Method original =
            class_getInstanceMethod(cls, @selector(viewDidAppear:));

        Method replacement =
            class_getInstanceMethod(
                cls,
                @selector(kdu_settings_viewDidAppear:)
            );

        if (original && replacement) {
            method_exchangeImplementations(original, replacement);
        }
    });
}

#pragma mark - Inspect only the controller that appeared

+ (void)inspectVisibleController:(UIViewController *)controller {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self inspectVisibleController:controller];
        });
        return;
    }

    if (!controller ||
        [controller isKindOfClass:KDUSettingsController.class] ||
        !controller.isViewLoaded ||
        !controller.view.window ||
        controller.isBeingDismissed ||
        controller.isMovingFromParentViewController) {
        return;
    }

    [self addEntryIfSettingsController:controller];

    // 只检查当前控制器正在显示的子控制器，不扫描所有窗口。
    UIViewController *visibleChild = nil;

    if ([controller isKindOfClass:UINavigationController.class]) {
        visibleChild =
            ((UINavigationController *)controller).visibleViewController;
    } else if ([controller isKindOfClass:UITabBarController.class]) {
        visibleChild =
            ((UITabBarController *)controller).selectedViewController;
    }

    if (visibleChild &&
        visibleChild != controller &&
        visibleChild.isViewLoaded &&
        visibleChild.view.window) {
        [self addEntryIfSettingsController:visibleChild];
    }
}

#pragma mark - Strict native Settings page detection

+ (BOOL)isNativeSettingsController:(UIViewController *)controller
                              text:(NSString *)text {
    if (!controller || text.length == 0) {
        return NO;
    }

    NSString *title = controller.title ?: @"";
    NSString *navigationTitle =
        controller.navigationItem.title ?: @"";

    BOOL titleLooksLikeSettings =
        [title isEqualToString:@"设置"] ||
        [navigationTitle isEqualToString:@"设置"];

    // 不把“设置”单独作为识别依据，避免误匹配其他页面。
    NSArray<NSString *> *strongMarkers = @[
        @"账号与安全",
        @"个人信息管理",
        @"隐私政策",
        @"用户协议",
        @"应用权限",
        @"个人信息收集清单",
        @"第三方信息共享清单"
    ];

    NSUInteger matchedCount = 0;

    for (NSString *marker in strongMarkers) {
        if ([text containsString:marker]) {
            matchedCount++;
        }
    }

    // 有明确原生标题时至少匹配两个设置专属项目；
    // 没有明确标题时要求至少三个专属项目。
    if (titleLooksLikeSettings) {
        return matchedCount >= 2;
    }

    return matchedCount >= 3;
}

#pragma mark - Add entry

+ (void)addEntryIfSettingsController:(UIViewController *)controller {
    if (!controller ||
        [controller isKindOfClass:KDUSettingsController.class] ||
        !controller.isViewLoaded ||
        !controller.view.window) {
        return;
    }

    NSMutableString *visibleText = [NSMutableString string];

    [self collectTextFromView:controller.view
                         into:visibleText
                        depth:0];

    if (![self isNativeSettingsController:controller
                                     text:visibleText]) {
        return;
    }

    UITableView *table =
        [self findTableView:controller.view depth:0];

    if (!table || table.hidden || table.alpha < 0.05) {
        return;
    }

    UIView *oldHeader = table.tableHeaderView;

    // 入口已经存在时不重复包装表头。
    if (oldHeader &&
        (oldHeader.tag == KDUSettingsEntryTag ||
         [oldHeader viewWithTag:KDUSettingsEntryTag])) {
        return;
    }

    CGFloat tableWidth = CGRectGetWidth(table.bounds);

    if (tableWidth <= 0) {
        tableWidth = CGRectGetWidth(controller.view.bounds);
    }

    if (tableWidth <= 0) {
        return;
    }

    CGFloat oldHeight = 0;

    if (oldHeader) {
        oldHeight = CGRectGetHeight(oldHeader.frame);

        if (!isfinite(oldHeight) || oldHeight < 0) {
            oldHeight = 0;
        }
    }

    CGFloat entryHeight = 62.0;

    UIView *container = [[UIView alloc]
        initWithFrame:CGRectMake(
            0,
            0,
            tableWidth,
            entryHeight + oldHeight
        )];

    container.backgroundColor = UIColor.clearColor;
    container.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    container.tag = KDUSettingsEntryTag;

    UIButton *entry =
        [UIButton buttonWithType:UIButtonTypeSystem];

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

    if (oldHeader) {
        oldHeader.frame = CGRectMake(
            0,
            entryHeight,
            tableWidth,
            oldHeight
        );

        oldHeader.autoresizingMask |=
            UIViewAutoresizingFlexibleWidth;

        [container addSubview:oldHeader];
    }

    // 仅在确认属于原生设置页后修改表头。
    table.tableHeaderView = container;

    objc_setAssociatedObject(
        table,
        KDUEntryContainerKey,
        container,
        OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );
}

#pragma mark - View traversal

+ (void)collectTextFromView:(UIView *)view
                       into:(NSMutableString *)result
                      depth:(NSUInteger)depth {
    if (!view ||
        depth > 10 ||
        view.hidden ||
        view.alpha < 0.05) {
        return;
    }

    if ([view isKindOfClass:UILabel.class]) {
        NSString *value = ((UILabel *)view).text;

        if (value.length > 0) {
            [result appendFormat:@" %@", value];
        }
    } else if ([view isKindOfClass:UIButton.class]) {
        UIButton *button = (UIButton *)view;

        NSString *value = button.currentTitle;

        if (value.length > 0) {
            [result appendFormat:@" %@", value];
        }

        NSString *accessibilityLabel = button.accessibilityLabel;

        if (accessibilityLabel.length > 0) {
            [result appendFormat:@" %@", accessibilityLabel];
        }
    }

    for (UIView *child in view.subviews) {
        [self collectTextFromView:child
                             into:result
                            depth:depth + 1];
    }
}

+ (UITableView *)findTableView:(UIView *)view
                         depth:(NSUInteger)depth {
    if (!view || depth > 10) {
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

#pragma mark - Open plugin settings

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
        top.isBeingPresented ||
        top.presentedViewController) {
        return;
    }

    KDUSettingsController *settings =
        [KDUSettingsController new];

    UINavigationController *navigation =
        [[UINavigationController alloc]
            initWithRootViewController:settings];

    navigation.modalPresentationStyle =
        UIModalPresentationPageSheet;

    [top presentViewController:navigation
                      animated:YES
                    completion:nil];
}

+ (UIViewController *)topController:(UIViewController *)controller {
    if (!controller) {
        return nil;
    }

    if (controller.presentedViewController) {
        return [self topController:controller.presentedViewController];
    }

    if ([controller isKindOfClass:UINavigationController.class]) {
        UINavigationController *nav =
            (UINavigationController *)controller;

        return [self topController:nav.visibleViewController];
    }

    if ([controller isKindOfClass:UITabBarController.class]) {
        UITabBarController *tabs =
            (UITabBarController *)controller;

        return [self topController:tabs.selectedViewController];
    }

    return controller;
}

@end

@implementation UIViewController (KDUSettingsIntegration)

- (void)kdu_settings_viewDidAppear:(BOOL)animated {
    // 调用交换后的原始 viewDidAppear:。
    [self kdu_settings_viewDidAppear:animated];

    // 不在当前生命周期调用栈内扫描或修改视图层级。
    __weak UIViewController *weakSelf = self;

    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *strongSelf = weakSelf;

        if (!strongSelf) {
            return;
        }

        [KDUSettingsIntegration
            inspectVisibleController:strongSelf];
    });
}

@end
