#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KDUSettingsIntegration : NSObject

+ (void)installHooks;
+ (void)scanForSettingsPage;

@end

NS_ASSUME_NONNULL_END