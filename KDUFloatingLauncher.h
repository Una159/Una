#import <Foundation/Foundation.h>
@interface KDUFloatingLauncher : NSObject
+ (instancetype)shared;
- (void)installIfNeeded;
@end
