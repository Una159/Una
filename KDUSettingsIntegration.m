#import "KDUSettingsIntegration.h"
#import "KDUSettingsController.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const NSInteger KDUSettingsEntryTag = 0x4B445532;
static const void *KDUOriginalHeaderKey = &KDUOriginalHeaderKey;

@interface UIViewController (KDUSettingsIntegration)
- (void)kdu_viewDidAppear:(BOOL)animated;
@end

@implementation KDUSettingsIntegration

+ (void)installHooks {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = UIViewController.class;
        SEL originalSEL = @selector(viewDidAppear:);
        SEL swizzledSEL = @selector(kdu_viewDidAppear:);
        Method original = class_getInstanceMethod(cls, originalSEL);
        Method swizzled = class_getInstanceMethod(cls, swizzledSEL);
        if (original && swizzled) method_exchangeImplementations(original, swizzled);
    });
    dispatch_async(dispatch_get_main_queue(), ^{ [self scanForSettingsPage]; });
}

+ (void)scanForSettingsPage {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self scanForSettingsPage]; });
        return;
    }
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class] || scene.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.hidden || window.alpha < 0.01) continue;
            [self inspectController:window.rootViewController];
        }
    }
}

+ (void)inspectController:(UIViewController *)controller {
    if (!controller) return;
    [self addEntryIfSettingsController:controller];
    for (UIViewController *child in controller.childViewControllers) [self inspectController:child];
    if ([controller isKindOfClass:UINavigationController.class]) {
        for (UIViewController *child in ((UINavigationController *)controller).viewControllers) [self inspectController:child];
    }
    if ([controller isKindOfClass:UITabBarController.class]) {
        for (UIViewController *child in ((UITabBarController *)controller).viewControllers) [self inspectController:child];
    }
    if (controller.presentedViewController) [self inspectController:controller.presentedViewController];
}

+ (void)addEntryIfSettingsController:(UIViewController *)controller {
    if ([controller isKindOfClass:KDUSettingsController.class] || !controller.isViewLoaded || !controller.view.window) return;
    NSMutableString *visibleText = [NSMutableString string];
    [self collectTextFromView:controller.view into:visibleText depth:0];
    NSArray<NSString *> *markers = @[@"è´¦å·ä¸å®å¨", @"éç¨è®¾ç½®", @"éç§æ¿ç­", @"åºç¨æé", @"ä¸ªäººä¿¡æ¯ç®¡ç", @"ç¨æ·åè®®", @"è®¾ç½®"];
    BOOL matched = NO;
    for (NSString *marker in markers) {
        if ([visibleText containsString:marker]) { matched = YES; break; }
    }
    if (!matched) return;
    UITableView *table = [self findTableView:controller.view depth:0];
    if (!table || [table viewWithTag:KDUSettingsEntryTag]) return;

    UIView *oldHeader = table.tableHeaderView;
    CGFloat oldHeight = oldHeader ? MAX(1, oldHeader.frame.size.height) : 0;
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, table.bounds.size.width, 62 + oldHeight)];
    container.backgroundColor = UIColor.clearColor;
    UIButton *entry = [UIButton buttonWithType:UIButtonTypeSystem];
    entry.tag = KDUSettingsEntryTag;
    entry.frame = CGRectMake(16, 7, MAX(0, table.bounds.size.width - 32), 48);
    entry.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    entry.backgroundColor = [UIColor secondarySystemBackgroundColor];
    entry.layer.cornerRadius = 12;
    entry.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    entry.contentEdgeInsets = UIEdgeInsetsMake(0, 16, 0, 16);
    [entry setTitle:@"K-Douyin Ultra    âº" forState:UIControlStateNormal];
    [entry setTitleColor:UIColor.labelColor forState:UIControlStateNormal];
    entry.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [entry addTarget:self action:@selector(openPluginSettings:) forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:entry];
    if (oldHeader) {
        objc_setAssociatedObject(container, KDUOriginalHeaderKey, oldHeader, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        oldHeader.frame = CGRectMake(0, 62, table.bounds.size.width, oldHeight);
        oldHeader.autoresizingMask = UIViewAutoresizingFlexibleWidth;
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
    for (UIView *child in view.subviews) [self collectTextFromView:child into:result depth:depth + 1];
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
    if (!top || [top isKindOfClass:KDUSettingsController.class]) return;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:[KDUSettingsController new]];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    [top presentViewController:nav animated:YES completion:nil];
}

+ (UIViewController *)topController:(UIViewController *)controller {
    if (!controller) return nil;
    if (controller.presentedViewController) return [self topController:controller.presentedViewController];
    if ([controller isKindOfClass:UINavigationController.class]) return [self topController:((UINavigationController *)controller).visibleViewController];
    if ([controller isKindOfClass:UITabBarController.class]) return [self topController:((UITabBarController *)controller).selectedViewController];
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