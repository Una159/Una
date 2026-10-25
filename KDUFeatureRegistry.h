#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface KDUFeature : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *detail;
@property (nonatomic, copy) NSString *category;
@property (nonatomic, copy) NSString *configKey;
@property (nonatomic, assign) BOOL defaultEnabled;
@property (nonatomic, assign) BOOL implemented;
@end

@interface KDUFeatureRegistry : NSObject
+ (instancetype)shared;
- (void)registerBuiltInFeatures;
- (NSArray<KDUFeature *> *)allFeatures;
- (NSArray<KDUFeature *> *)featuresMatching:(NSString *)query;
@end
NS_ASSUME_NONNULL_END
