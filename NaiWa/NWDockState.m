#import "NWDockState.h"
@implementation NWDockState
- (instancetype)initWithItems:(NSArray<NSDictionary<NSString *,id> *> *)items selectedIndex:(NSInteger)selectedIndex mediaActive:(BOOL)mediaActive {
    self = [super init];
    if (!self) return nil;
    _items = [items copy] ?: @[];
    _selectedIndex = (selectedIndex >= 0 && selectedIndex < (NSInteger)_items.count) ? selectedIndex : NSNotFound;
    _mediaActive = mediaActive;
    return self;
}
- (id)copyWithZone:(NSZone *)zone { return self; }
@end
