#import <UIKit/UIKit.h>
#import "KDUConfigManager.h"
#import "KDUFeatureRegistry.h"
#import "KDUCompatibility.h"
#import "KDUFloatingLauncher.h"

static void KDUInstallLauncher(void) {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{
            KDUInstallLauncher();
        });
        return;
    }

    [[KDUConfigManager shared] loadDefaultsIfNeeded];
    [[KDUFeatureRegistry shared] registerBuiltInFeatures];
    [[KDUCompatibility shared] refreshDiagnostics];

    // 多次尝试，等待抖音窗口完成初始化
    [KDUFloatingLauncher.shared installIfNeeded];
}

%ctor {
    @autoreleasepool {
        // 监听应用进入前台，不再依赖错误的 UIApplication 方法钩子
        [[NSNotificationCenter defaultCenter]
            addObserverForName:UIApplicationDidBecomeActiveNotification
            object:nil
            queue:[NSOperationQueue mainQueue]
            usingBlock:^(NSNotification *notification) {
                KDUInstallLauncher();

                dispatch_after(
                    dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)),
                    dispatch_get_main_queue(), ^{
                        KDUInstallLauncher();
                    });

                dispatch_after(
                    dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)),
                    dispatch_get_main_queue(), ^{
                        KDUInstallLauncher();
                    });
            }];

        // 兼容通知注册时应用已经处于前台的情况
        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)),
            dispatch_get_main_queue(), ^{
                KDUInstallLauncher();
            });
    }
}