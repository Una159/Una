#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
/// Immutable state snapshot for the reconstructed dock layer.
@interface NWDockState : NSObject <NSCopying>
@property (nonatomic, copy, readonly) NSArray<NSDictionary<NSString *, id> *> *items;
@property (nonatomic, assign, readonly) NSInteger selectedIndex;
@property (nonatomic, assign, readonly, getter=isMediaActive) BOOL mediaActive;
- (instancetype)initWithItems:(NSArray<NSDictionary<NSString *, id> *> *)items selectedIndex:(NSInteger)selectedIndex mediaActive:(BOOL)mediaActive NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end
NS_ASSUME_NONNULL_END
