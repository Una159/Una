#import "NWDockView.h"
@interface NWDockView ()
@property (nonatomic, strong) UIVisualEffectView *effectView;
@property (nonatomic, strong) UIStackView *stackView;
@property (nonatomic, copy, readwrite) NSArray<NSDictionary<NSString *, id> *> *items;
@property (nonatomic, assign, readwrite) NSInteger selectedIndex;
@property (nonatomic, strong) NSMutableArray<UIButton *> *itemButtons;
@end
@implementation NWDockView
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    _items = @[]; _selectedIndex = NSNotFound; _glassEnabled = YES; _surfaceOpacity = 0.82;
    _itemButtons = [NSMutableArray array];
    self.backgroundColor = UIColor.clearColor;
    self.layer.cornerRadius = 22.0;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    self.layer.masksToBounds = YES;
    _effectView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial]];
    _effectView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_effectView];
    [NSLayoutConstraint activateConstraints:@[
        [_effectView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_effectView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_effectView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [_effectView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
    ]];
    _stackView = [[UIStackView alloc] initWithArrangedSubviews:@[]];
    _stackView.translatesAutoresizingMaskIntoConstraints = NO;
    _stackView.axis = UILayoutConstraintAxisHorizontal;
    _stackView.alignment = UIStackViewAlignmentFill;
    _stackView.distribution = UIStackViewDistributionFillEqually;
    _stackView.spacing = 2.0;
    [_effectView.contentView addSubview:_stackView];
    [NSLayoutConstraint activateConstraints:@[
        [_stackView.leadingAnchor constraintEqualToAnchor:_effectView.contentView.leadingAnchor constant:8.0],
        [_stackView.trailingAnchor constraintEqualToAnchor:_effectView.contentView.trailingAnchor constant:-8.0],
        [_stackView.topAnchor constraintEqualToAnchor:_effectView.contentView.topAnchor constant:5.0],
        [_stackView.bottomAnchor constraintEqualToAnchor:_effectView.contentView.bottomAnchor constant:-5.0]
    ]];
    self.layer.borderWidth = 0.5;
    [self applySurfaceStyle];
    return self;
}
- (CGSize)intrinsicContentSize { return CGSizeMake(UIViewNoIntrinsicMetric, 58.0); }
- (void)setGlassEnabled:(BOOL)value { if (_glassEnabled == value) return; _glassEnabled = value; [self applySurfaceStyle]; }
- (void)setSurfaceOpacity:(CGFloat)value { _surfaceOpacity = MIN(1.0, MAX(0.0, value)); [self applySurfaceStyle]; }
- (void)applySurfaceStyle {
    self.effectView.hidden = !self.glassEnabled;
    self.backgroundColor = self.glassEnabled ? UIColor.clearColor : [UIColor.secondarySystemBackgroundColor colorWithAlphaComponent:self.surfaceOpacity];
    self.effectView.alpha = self.surfaceOpacity;
    self.layer.borderColor = [UIColor.separatorColor colorWithAlphaComponent:0.35].CGColor;
}
- (void)setItems:(NSArray<NSDictionary<NSString *,id> *> *)items selectedIndex:(NSInteger)selectedIndex {
    _items = [items copy] ?: @[];
    while (self.stackView.arrangedSubviews.count) {
        UIView *view = self.stackView.arrangedSubviews.lastObject;
        [self.stackView removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    [self.itemButtons removeAllObjects];
    [_items enumerateObjectsUsingBlock:^(NSDictionary<NSString *,id> *item, NSUInteger index, BOOL *stop) {
        NSString *title = [item[@"title"] isKindOfClass:NSString.class] ? item[@"title"] : @"";
        NSString *symbol = [item[@"symbol"] isKindOfClass:NSString.class] ? item[@"symbol"] : nil;
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.tag = (NSInteger)index;
        button.titleLabel.font = [UIFont systemFontOfSize:10.0 weight:UIFontWeightMedium];
        button.titleLabel.adjustsFontSizeToFitWidth = YES;
        button.titleLabel.minimumScaleFactor = 0.75;
        button.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [button setTitle:title forState:UIControlStateNormal];
        if (symbol.length) {
            [button setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal];
            button.imageView.contentMode = UIViewContentModeScaleAspectFit;
            button.titleEdgeInsets = UIEdgeInsetsMake(3.0, -14.0, -23.0, 0.0);
            button.imageEdgeInsets = UIEdgeInsetsMake(-13.0, 0.0, 8.0, -button.titleLabel.intrinsicContentSize.width);
        }
        button.accessibilityLabel = title;
        button.accessibilityTraits = UIAccessibilityTraitButton;
        [button addTarget:self action:@selector(itemPressed:) forControlEvents:UIControlEventTouchUpInside];
        [self.stackView addArrangedSubview:button];
        [self.itemButtons addObject:button];
    }];
    [self setSelectedIndex:selectedIndex animated:NO];
}
- (void)setSelectedIndex:(NSInteger)selectedIndex animated:(BOOL)animated {
    _selectedIndex = (selectedIndex >= 0 && selectedIndex < (NSInteger)self.itemButtons.count) ? selectedIndex : NSNotFound;
    [self.itemButtons enumerateObjectsUsingBlock:^(UIButton *button, NSUInteger index, BOOL *stop) {
        BOOL selected = ((NSInteger)index == self.selectedIndex);
        UIColor *color = selected ? UIColor.labelColor : UIColor.secondaryLabelColor;
        void (^changes)(void) = ^{
            button.tintColor = color;
            [button setTitleColor:color forState:UIControlStateNormal];
            button.alpha = selected ? 1.0 : 0.78;
            button.accessibilityTraits = UIAccessibilityTraitButton | (selected ? UIAccessibilityTraitSelected : 0);
        };
        if (animated) [UIView animateWithDuration:0.18 animations:changes]; else changes();
    }];
}
- (void)itemPressed:(UIButton *)sender {
    NSInteger index = sender.tag;
    if (index < 0 || index >= (NSInteger)self.items.count) return;
    [self setSelectedIndex:index animated:YES];
    [self.delegate dockView:self didSelectItemAtIndex:index];
}
@end
