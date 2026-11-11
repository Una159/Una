#import "NWHookRegistry.h"

@implementation NWHookRegistry

+ (Method)ownInstanceMethodForClass:(Class)targetClass selector:(SEL)selector {
    unsigned int count = 0;
    Method *methods = class_copyMethodList(targetClass, &count);
    Method found = NULL;
    for (unsigned int index = 0; index < count; index++) {
        if (method_getName(methods[index]) == selector) {
            found = methods[index];
            break;
        }
    }
    free(methods);
    return found;
}

+ (BOOL)replaceInstanceMethodOnClass:(Class)targetClass
                            selector:(SEL)selector
                      replacementIMP:(IMP)replacement
                         originalIMP:(IMP *)originalIMP {
    if (!targetClass || !selector || !replacement) return NO;

    // class_getInstanceMethod may return a superclass method. Never mutate
    // that shared implementation when the target class inherits the selector.
    Method inheritedOrOwn = class_getInstanceMethod(targetClass, selector);
    if (!inheritedOrOwn) return NO;

    IMP previous = method_getImplementation(inheritedOrOwn);
    const char *types = method_getTypeEncoding(inheritedOrOwn);
    if (!previous || !types) return NO;

    Method own = [self ownInstanceMethodForClass:targetClass selector:selector];
    if (own) {
        method_setImplementation(own, replacement);
    } else if (!class_addMethod(targetClass, selector, replacement, types)) {
        return NO;
    }

    if (originalIMP) *originalIMP = previous;
    return YES;
}

+ (BOOL)restoreInstanceMethodOnClass:(Class)targetClass
                            selector:(SEL)selector
                          originalIMP:(IMP)originalIMP {
    if (!targetClass || !selector || !originalIMP) return NO;

    Method current = [self ownInstanceMethodForClass:targetClass selector:selector];
    if (!current) return NO;

    const char *types = method_getTypeEncoding(current);
    if (!types) return NO;

    // Restoring through class_replaceMethod is safe for both methods that
    // originally belonged to the class and methods shadowed from a superclass.
    class_replaceMethod(targetClass, selector, originalIMP, types);
    return YES;
}

@end
