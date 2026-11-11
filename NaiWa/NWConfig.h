#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NWConfig : NSObject
+ (NSUserDefaults *)defaults;
+ (BOOL)boolForKey:(NSString *)key fallback:(BOOL)fallback;
+ (NSInteger)integerForKey:(NSString *)key fallback:(NSInteger)fallback;
+ (double)doubleForKey:(NSString *)key fallback:(double)fallback;
+ (nullable id)objectForKey:(NSString *)key;
+ (void)setObject:(nullable id)value forKey:(NSString *)key;
+ (void)resetKey:(NSString *)key;
@end

NS_ASSUME_NONNULL_END
