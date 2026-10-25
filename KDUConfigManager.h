#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface KDUConfigManager : NSObject
+ (instancetype)shared;
- (void)loadDefaultsIfNeeded;
- (BOOL)boolForKey:(NSString *)key fallback:(BOOL)fallback;
- (void)setBool:(BOOL)value forKey:(NSString *)key;
- (NSDictionary<NSString *, id> *)allValues;
- (void)resetToDefaults;
@end
NS_ASSUME_NONNULL_END
