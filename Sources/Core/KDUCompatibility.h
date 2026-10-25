#import <Foundation/Foundation.h>
@interface KDUCompatibility : NSObject
+ (instancetype)shared;
- (void)refreshDiagnostics;
- (NSDictionary *)diagnostics;
@end
