#import "NWHookRegistry.h"

@implementation NWHookRegistry

+ (BOOL)replaceInstanceMethodOnClass:(Class)targetClass
                            selector:(SEL)selector
                      replacementIMP:(IMP)replacement
                         originalIMP:(IMP *)originalIMP {
    if (!targetClass || !selector || !replacement) return NO;

    Method method = class_getInstanceMethod(targetClass, selector);
    if (!method) return NO;

    IMP previous = method_getImplementation(method);
    if (!previous) return NO;

    method_setImplementation(method, replacement);
    if (originalIMP) *originalIMP = previous;
    return YES;
}

+ (BOOL)restoreInstanceMethodOnClass:(Class)targetClass
                            selector:(SEL)selector
                          originalIMP:(IMP)originalIMP {
    if (!targetClass || !selector || !originalIMP) return NO;

    Method method = class_getInstanceMethod(targetClass, selector);
    if (!method) return NO;

    method_setImplementation(method, originalIMP);
    return YES;
}

@end
