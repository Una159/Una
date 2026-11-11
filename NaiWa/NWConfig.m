#import "NWConfig.h"

@implementation NWConfig

+ (NSUserDefaults *)defaults {
    return NSUserDefaults.standardUserDefaults;
}

+ (BOOL)boolForKey:(NSString *)key fallback:(BOOL)fallback {
    id value = [self.defaults objectForKey:key];
    return value ? [value boolValue] : fallback;
}

+ (NSInteger)integerForKey:(NSString *)key fallback:(NSInteger)fallback {
    id value = [self.defaults objectForKey:key];
    return value ? [value integerValue] : fallback;
}

+ (double)doubleForKey:(NSString *)key fallback:(double)fallback {
    id value = [self.defaults objectForKey:key];
    return value ? [value doubleValue] : fallback;
}

+ (id)objectForKey:(NSString *)key {
    return [self.defaults objectForKey:key];
}

+ (void)setObject:(id)value forKey:(NSString *)key {
    if (value) [self.defaults setObject:value forKey:key];
    else [self.defaults removeObjectForKey:key];
}

+ (void)resetKey:(NSString *)key {
    [self.defaults removeObjectForKey:key];
}

@end
