#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
@class NWDockView;
@protocol NWDockViewDelegate <NSObject>
- (void)dockView:(NWDockView *)dockView didSelectItemAtIndex:(NSInteger)index;
@end
/// Standalone host-agnostic dock surface; it does not replace the host app tab bar.
@interface NWDockView : UIView
@property (nonatomic, weak, nullable) id<NWDockViewDelegate> delegate;
@property (nonatomic, copy, readonly) NSArray<NSDictionary<NSString *, id> *> *items;
@property (nonatomic, assign, readonly) NSInteger selectedIndex;
@property (nonatomic, assign, getter=isGlassEnabled) BOOL glassEnabled;
@property (nonatomic, assign) CGFloat surfaceOpacity;
- (void)setItems:(NSArray<NSDictionary<NSString *, id> *> *)items selectedIndex:(NSInteger)selectedIndex;
- (void)setSelectedIndex:(NSInteger)selectedIndex animated:(BOOL)animated;
@end
NS_ASSUME_NONNULL_END
