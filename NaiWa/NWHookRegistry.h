#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

// Explicit, reversible runtime method replacement helper.
// No host methods are installed by the reconstruction scaffold itself.
@interface NWHookRegistry : NSObject
+ (BOOL)replaceInstanceMethodOnClass:(Class)targetClass
                            selector:(SEL)selector
                       replacementIMP:(IMP)replacement
                         originalIMP:(IMP _Nullable * _Nullable)originalIMP;
+ (BOOL)restoreInstanceMethodOnClass:(Class)targetClass
                            selector:(SEL)selector
                          originalIMP:(IMP)originalIMP;
@end

NS_ASSUME_NONNULL_END
