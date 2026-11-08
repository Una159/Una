
#import "KDUSettingsController.h"
#import "KDUFeatureRegistry.h"
#import "KDUConfigManager.h"
#import "KDUCompatibility.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>

#pragma mark - Feature Cell

@interface KDUFeatureTableCell : UITableViewCell

@property (nonatomic, assign) BOOL glassEnabled;
@property (nonatomic, strong) UIVisualEffectView *glassView;
@property (nonatomic, strong) UIView *fallbackView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *detailLabel;

- (void)applyGlassStyle:(BOOL)enabled;

@end

@implementation KDUFeatureTableCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:UITableViewCellStyleDefault
                reuseIdentifier:reuseIdentifier];
    if (!self) return nil;

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.selectionStyle = UITableViewCellSelectionStyleNone;

    _fallbackView = [UIView new];
    _fallbackView.translatesAutoresizingMaskIntoConstraints = NO;
    _fallbackView.layer.cornerRadius = 18.0;
    _fallbackView.layer.cornerCurve = kCACornerCurveContinuous;
    _fallbackView.layer.borderWidth = 0.7;
    _fallbackView.userInteractionEnabled = NO;
    [self.contentView insertSubview:_fallbackView atIndex:0];

    _glassView = [[UIVisualEffectView alloc] initWithEffect:nil];
    _glassView.translatesAutoresizingMaskIntoConstraints = NO;
    _glassView.layer.cornerRadius = 18.0;
    _glassView.layer.cornerCurve = kCACornerCurveContinuous;
    _glassView.clipsToBounds = YES;
    _glassView.userInteractionEnabled = NO;
    [self.contentView insertSubview:_glassView aboveSubview:_fallbackView];

    [NSLayoutConstraint activateConstraints:@[
        [_fallbackView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:5.0],
        [_fallbackView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-5.0],
        [_fallbackView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12.0],
        [_fallbackView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12.0],

        [_glassView.topAnchor constraintEqualToAnchor:_fallbackView.topAnchor],
        [_glassView.bottomAnchor constraintEqualToAnchor:_fallbackView.bottomAnchor],
        [_glassView.leadingAnchor constraintEqualToAnchor:_fallbackView.leadingAnchor],
        [_glassView.trailingAnchor constraintEqualToAnchor:_fallbackView.trailingAnchor]
    ]];

    _titleLabel = [UILabel new];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.font = [UIFont systemFontOfSize:15.5 weight:UIFontWeightSemibold];
    _titleLabel.numberOfLines = 0;
    _titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    _titleLabel.textColor = UIColor.labelColor;

    _detailLabel = [UILabel new];
    _detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _detailLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightRegular];
    _detailLabel.numberOfLines = 0;
    _detailLabel.lineBreakMode = NSLineBreakByWordWrapping;
    _detailLabel.textColor = UIColor.secondaryLabelColor;

    [self.contentView addSubview:_titleLabel];
    [self.contentView addSubview:_detailLabel];

    [NSLayoutConstraint activateConstraints:@[
        [_titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:16.0],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:30.0],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-92.0],

        [_detailLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:5.0],
        [_detailLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_detailLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-92.0],
        [_detailLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-16.0]
    ]];

    [self applyGlassStyle:NO];
    return self;
}

- (void)applyGlassStyle:(BOOL)enabled {
    _glassEnabled = enabled;

    if (@available(iOS 13.0, *)) {
        _fallbackView.backgroundColor =
            [UIColor.secondarySystemGroupedBackgroundColor
                colorWithAlphaComponent:enabled ? 0.24 : 0.94];

        _fallbackView.layer.borderColor =
            [[UIColor.separatorColor
                colorWithAlphaComponent:enabled ? 0.38 : 0.18] CGColor];

        _glassView.effect = enabled
            ? [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial]
            : nil;

        _glassView.hidden = !enabled;
        _glassView.layer.borderWidth = enabled ? 0.6 : 0.0;
        _glassView.layer.borderColor =
            [[UIColor.whiteColor colorWithAlphaComponent:0.35] CGColor];

        _titleLabel.textColor = UIColor.labelColor;
        _detailLabel.textColor = UIColor.secondaryLabelColor;
    }

    self.contentView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.contentView.layer.shadowOpacity = enabled ? 0.07 : 0.0;
    self.contentView.layer.shadowRadius = enabled ? 8.0 : 0.0;
    self.contentView.layer.shadowOffset = CGSizeMake(0, 3);
    self.contentView.layer.masksToBounds = NO;
}

- (void)prepareForReuse {
    [super prepareForReuse];

    self.accessoryView = nil;
    self.accessoryType = UITableViewCellAccessoryNone;
    self.selectionStyle = UITableViewCellSelectionStyleNone;

    _titleLabel.text = nil;
    _detailLabel.text = nil;
}

@end

#pragma mark - Feature Detail Controller

@interface KDUFeatureDetailController : UIViewController
@property (nonatomic, strong) KDUFeature *feature;
@end

@implementation KDUFeatureDetailController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.feature.title ?: @"功能详情";
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;

    UIScrollView *scrollView = [UIScrollView new];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scrollView];

    UIView *content = [UIView new];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [scrollView addSubview:content];

    UILabel *status = [UILabel new];
    status.translatesAutoresizingMaskIntoConstraints = NO;
    status.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    status.text = self.feature.implemented ? @"已实现 · 可以使用" : @"开发中 · 暂不可用";
    status.textColor = self.feature.implemented ? UIColor.systemGreenColor : UIColor.secondaryLabelColor;

    UILabel *title = [UILabel new];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.font = [UIFont systemFontOfSize:23 weight:UIFontWeightBold];
    title.textColor = UIColor.labelColor;
    title.numberOfLines = 0;
    title.text = self.feature.title ?: @"未命名功能";

    UILabel *category = [UILabel new];
    category.translatesAutoresizingMaskIntoConstraints = NO;
    category.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    category.textColor = UIColor.secondaryLabelColor;
    category.text = [NSString stringWithFormat:@"分类  %@", self.feature.category ?: @"未分类"];

    UIView *card = [UIView new];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    card.layer.cornerRadius = 18.0;
    card.layer.cornerCurve = kCACornerCurveContinuous;

    UILabel *description = [UILabel new];
    description.translatesAutoresizingMaskIntoConstraints = NO;
    description.font = [UIFont systemFontOfSize:15];
    description.textColor = UIColor.secondaryLabelColor;
    description.numberOfLines = 0;
    description.text = self.feature.detail ?: @"暂无功能说明。";

    [content addSubview:card];
    [card addSubview:description];

    [content addSubview:status];
    [content addSubview:title];
    [content addSubview:category];

    NSMutableArray<NSLayoutConstraint *> *constraints = [NSMutableArray arrayWithArray:@[
        [scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        [content.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor constant:28],
        [content.leadingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.leadingAnchor constant:22],
        [content.trailingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.trailingAnchor constant:-22],
        [content.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor constant:-24],
        [content.widthAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.widthAnchor constant:-44],
        [status.topAnchor constraintEqualToAnchor:content.topAnchor],
        [status.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [title.topAnchor constraintEqualToAnchor:status.bottomAnchor constant:12],
        [title.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [title.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [category.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:10],
        [category.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [card.topAnchor constraintEqualToAnchor:category.bottomAnchor constant:24],
        [card.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [card.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [description.topAnchor constraintEqualToAnchor:card.topAnchor constant:18],
        [description.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18],
        [description.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],
        [description.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-18],

    ]];

    if (self.feature.implemented) {
        UIView *settingRow = [UIView new];
        settingRow.translatesAutoresizingMaskIntoConstraints = NO;
        settingRow.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
        settingRow.layer.cornerRadius = 16.0;

        UILabel *settingTitle = [UILabel new];
        settingTitle.translatesAutoresizingMaskIntoConstraints = NO;
        settingTitle.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        settingTitle.textColor = UIColor.labelColor;
        settingTitle.text = @"启用此功能";

        UISwitch *toggle = [UISwitch new];
        toggle.translatesAutoresizingMaskIntoConstraints = NO;
        toggle.on = [[KDUConfigManager shared] boolForKey:self.feature.configKey fallback:self.feature.defaultEnabled];
        toggle.onTintColor = UIColor.systemGreenColor;
        toggle.accessibilityIdentifier = self.feature.configKey;
        [toggle addTarget:self action:@selector(featureToggleChanged:) forControlEvents:UIControlEventValueChanged];

        [content addSubview:settingRow];
        [settingRow addSubview:settingTitle];
        [settingRow addSubview:toggle];
        [constraints addObjectsFromArray:@[
            [settingRow.topAnchor constraintEqualToAnchor:card.bottomAnchor constant:16],
            [settingRow.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
            [settingRow.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
            [settingRow.heightAnchor constraintEqualToConstant:64],
            [settingTitle.leadingAnchor constraintEqualToAnchor:settingRow.leadingAnchor constant:16],
            [settingTitle.centerYAnchor constraintEqualToAnchor:settingRow.centerYAnchor],
            [toggle.trailingAnchor constraintEqualToAnchor:settingRow.trailingAnchor constant:-14],
            [toggle.centerYAnchor constraintEqualToAnchor:settingRow.centerYAnchor],
            [settingRow.bottomAnchor constraintEqualToAnchor:content.bottomAnchor]
        ]];

    } else {
        UILabel *notice = [UILabel new];
        notice.translatesAutoresizingMaskIntoConstraints = NO;
        notice.font = [UIFont systemFontOfSize:13];
        notice.textColor = UIColor.secondaryLabelColor;
        notice.numberOfLines = 0;
        notice.text = @"此功能尚未完成，因此不会显示可操作的开关。待适配并通过验证后才会开放。";
        [content addSubview:notice];
        [constraints addObjectsFromArray:@[
            [notice.topAnchor constraintEqualToAnchor:card.bottomAnchor constant:14],
            [notice.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
            [notice.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
            [notice.bottomAnchor constraintEqualToAnchor:content.bottomAnchor]
        ]];

    }

    [NSLayoutConstraint activateConstraints:constraints];
}

- (void)featureToggleChanged:(UISwitch *)sender {
    if (!self.feature.implemented) {
        sender.on = NO;
        return;
    }
    [[KDUConfigManager shared] setBool:sender.isOn forKey:self.feature.configKey];
}

@end

#pragma mark - Settings Controller

@interface KDUSettingsController () <UITextFieldDelegate>

@property (nonatomic, strong) UIView *bottomSearchContainer;
@property (nonatomic, strong) UIView *searchCapsule;
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, strong) UIButton *clearSearchButton;
@property (nonatomic, strong) NSLayoutConstraint *searchBottomConstraint;

@property (nonatomic, copy) NSArray<KDUFeature *> *visibleFeatures;
@property (nonatomic, copy) NSArray<NSString *> *categories;
@property (nonatomic, copy) NSString *selectedCategory;
@property (nonatomic, assign) BOOL liquidGlassEnabled;

- (void)showMessage:(NSString *)title message:(NSString *)message;
- (void)updateNavigationAppearance;
- (void)updateSearchAppearance;
- (void)updateEmptyState;
- (void)refreshVisible;
- (void)setupBottomSearchBar;
- (void)registerKeyboardNotifications;
- (void)searchTextChanged:(UITextField *)sender;
- (void)clearSearch;
- (void)keyboardWillChangeFrame:(NSNotification *)notification;
- (void)keyboardWillHide:(NSNotification *)notification;
- (void)toggleChanged:(UISwitch *)sender;
- (void)showTools;

@end

@implementation KDUSettingsController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"K-Douyin Ultra";
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;

    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.contentInsetAdjustmentBehavior =
        UIScrollViewContentInsetAdjustmentAutomatic;
    self.tableView.keyboardDismissMode =
        UIScrollViewKeyboardDismissModeOnDrag;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 96.0;

    self.liquidGlassEnabled =
        [[KDUConfigManager shared] boolForKey:@"interface.liquidGlass"
                                     fallback:YES];

    NSArray<NSString *> *registeredCategories =
        [[KDUFeatureRegistry shared] categories] ?: @[];

    if ([registeredCategories containsObject:@"全部"]) {
        self.categories = registeredCategories;
    } else {
        self.categories =
            [@[@"全部"] arrayByAddingObjectsFromArray:registeredCategories];
    }

    self.selectedCategory = @"全部";

    self.navigationItem.largeTitleDisplayMode =
        UINavigationItemLargeTitleDisplayModeAlways;

    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.navigationController.navigationBar.tintColor = UIColor.labelColor;

    [self updateNavigationAppearance];

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"工具"
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(showTools)];

    [self.tableView registerClass:KDUFeatureTableCell.class
           forCellReuseIdentifier:@"FeatureCell"];

    [self setupBottomSearchBar];
    [self registerKeyboardNotifications];
    [self refreshVisible];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    self.liquidGlassEnabled =
        [[KDUConfigManager shared] boolForKey:@"interface.liquidGlass"
                                     fallback:YES];

    [self updateNavigationAppearance];
    [self.tableView reloadData];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    if (self.tableView.tableFooterView) {
        UIView *footer = self.tableView.tableFooterView;

        if (fabs(footer.frame.size.width - self.tableView.bounds.size.width) > 0.5) {
            CGRect frame = footer.frame;
            frame.size.width = self.tableView.bounds.size.width;
            footer.frame = frame;
            self.tableView.tableFooterView = footer;
        }
    }
}

- (BOOL)isLiquidGlassEnabled {
    return [[KDUConfigManager shared] boolForKey:@"interface.liquidGlass"
                                         fallback:YES];
}

#pragma mark - Appearance

- (void)updateNavigationAppearance {
    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *appearance = [UINavigationBarAppearance new];
        [appearance configureWithDefaultBackground];

        appearance.backgroundEffect = self.liquidGlassEnabled
            ? [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial]
            : nil;

        appearance.backgroundColor = self.liquidGlassEnabled
            ? [UIColor.systemBackgroundColor colorWithAlphaComponent:0.55]
            : UIColor.systemBackgroundColor;

        self.navigationController.navigationBar.standardAppearance = appearance;
        self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
        self.navigationController.navigationBar.compactAppearance = appearance;
    }

    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.tableView.backgroundColor = UIColor.clearColor;

    [self updateSearchAppearance];
}

- (void)updateSearchAppearance {
    if (!self.searchCapsule) return;

    BOOL enabled = [self isLiquidGlassEnabled];

    self.searchCapsule.backgroundColor =
        [UIColor.secondarySystemGroupedBackgroundColor
            colorWithAlphaComponent:enabled ? 0.45 : 0.96];

    self.searchCapsule.layer.borderColor =
        [[UIColor.separatorColor
            colorWithAlphaComponent:enabled ? 0.30 : 0.18] CGColor];

    UIView *searchBlur = [self.searchCapsule viewWithTag:0x4B445533];
    if ([searchBlur isKindOfClass:UIVisualEffectView.class]) {
        searchBlur.hidden = !enabled;
    }
}

#pragma mark - Bottom Search Bar

- (void)setupBottomSearchBar {
    self.bottomSearchContainer = [UIView new];
    self.bottomSearchContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.bottomSearchContainer.backgroundColor = UIColor.clearColor;
    self.bottomSearchContainer.clipsToBounds = NO;

    [self.view addSubview:self.bottomSearchContainer];

    self.searchCapsule = [UIView new];
    self.searchCapsule.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchCapsule.layer.cornerRadius = 27.0;
    self.searchCapsule.layer.cornerCurve = kCACornerCurveContinuous;
    self.searchCapsule.clipsToBounds = YES;

    if (@available(iOS 13.0, *)) {
        self.searchCapsule.backgroundColor =
            [UIColor.secondarySystemGroupedBackgroundColor
                colorWithAlphaComponent:0.45];
    }

    self.searchCapsule.layer.borderWidth = 0.6;
    self.searchCapsule.layer.borderColor =
        [[UIColor.separatorColor colorWithAlphaComponent:0.25] CGColor];

    UIVisualEffectView *searchBlur =
        [[UIVisualEffectView alloc]
            initWithEffect:[UIBlurEffect effectWithStyle:
                UIBlurEffectStyleSystemThinMaterial]];
    searchBlur.translatesAutoresizingMaskIntoConstraints = NO;
    searchBlur.userInteractionEnabled = NO;
    searchBlur.clipsToBounds = YES;
    searchBlur.layer.cornerRadius = 27.0;
    searchBlur.layer.cornerCurve = kCACornerCurveContinuous;
    searchBlur.tag = 0x4B445533;
    searchBlur.hidden = ![self isLiquidGlassEnabled];
    [self.searchCapsule addSubview:searchBlur];

    [NSLayoutConstraint activateConstraints:@[
        [searchBlur.topAnchor constraintEqualToAnchor:self.searchCapsule.topAnchor],
        [searchBlur.bottomAnchor constraintEqualToAnchor:self.searchCapsule.bottomAnchor],
        [searchBlur.leadingAnchor constraintEqualToAnchor:self.searchCapsule.leadingAnchor],
        [searchBlur.trailingAnchor constraintEqualToAnchor:self.searchCapsule.trailingAnchor]
    ]];

    [self.bottomSearchContainer addSubview:self.searchCapsule];

    UIImageView *searchIcon =
        [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"magnifyingglass"]];

    searchIcon.translatesAutoresizingMaskIntoConstraints = NO;
    searchIcon.tintColor = UIColor.labelColor;
    searchIcon.contentMode = UIViewContentModeScaleAspectFit;
    [self.searchCapsule addSubview:searchIcon];

    self.searchField = [UITextField new];
    self.searchField.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchField.placeholder = @"搜索全部功能";
    self.searchField.font = [UIFont systemFontOfSize:16.0];
    self.searchField.textColor = UIColor.labelColor;
    self.searchField.clearButtonMode = UITextFieldViewModeNever;
    self.searchField.returnKeyType = UIReturnKeySearch;
    self.searchField.delegate = self;
    self.searchField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.searchField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.searchField.accessibilityLabel = @"搜索全部功能";

    [self.searchField addTarget:self
                         action:@selector(searchTextChanged:)
               forControlEvents:UIControlEventEditingChanged];

    [self.searchCapsule addSubview:self.searchField];

    self.clearSearchButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.clearSearchButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.clearSearchButton setImage:[UIImage systemImageNamed:@"xmark.circle.fill"]
                            forState:UIControlStateNormal];
    self.clearSearchButton.tintColor = UIColor.tertiaryLabelColor;
    self.clearSearchButton.hidden = YES;
    self.clearSearchButton.accessibilityLabel = @"清除搜索";

    [self.clearSearchButton addTarget:self
                               action:@selector(clearSearch)
                     forControlEvents:UIControlEventTouchUpInside];

    [self.searchCapsule addSubview:self.clearSearchButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.bottomSearchContainer.leadingAnchor
            constraintEqualToAnchor:self.view.leadingAnchor constant:20.0],
        [self.bottomSearchContainer.trailingAnchor
            constraintEqualToAnchor:self.view.trailingAnchor constant:-20.0],

        [self.searchCapsule.topAnchor
            constraintEqualToAnchor:self.bottomSearchContainer.topAnchor],
        [self.searchCapsule.bottomAnchor
            constraintEqualToAnchor:self.bottomSearchContainer.bottomAnchor],
        [self.searchCapsule.leadingAnchor
            constraintEqualToAnchor:self.bottomSearchContainer.leadingAnchor],
        [self.searchCapsule.trailingAnchor
            constraintEqualToAnchor:self.bottomSearchContainer.trailingAnchor],
        [self.searchCapsule.heightAnchor constraintEqualToConstant:54.0],

        [searchIcon.leadingAnchor
            constraintEqualToAnchor:self.searchCapsule.leadingAnchor constant:18.0],
        [searchIcon.centerYAnchor
            constraintEqualToAnchor:self.searchCapsule.centerYAnchor],
        [searchIcon.widthAnchor constraintEqualToConstant:23.0],
        [searchIcon.heightAnchor constraintEqualToConstant:23.0],

        [self.searchField.leadingAnchor
            constraintEqualToAnchor:searchIcon.trailingAnchor constant:12.0],
        [self.searchField.centerYAnchor
            constraintEqualToAnchor:self.searchCapsule.centerYAnchor],
        [self.searchField.topAnchor
            constraintGreaterThanOrEqualToAnchor:self.searchCapsule.topAnchor constant:8.0],
        [self.searchField.bottomAnchor
            constraintLessThanOrEqualToAnchor:self.searchCapsule.bottomAnchor constant:-8.0],

        [self.clearSearchButton.leadingAnchor
            constraintEqualToAnchor:self.searchField.trailingAnchor constant:4.0],
        [self.clearSearchButton.trailingAnchor
            constraintEqualToAnchor:self.searchCapsule.trailingAnchor constant:-14.0],
        [self.clearSearchButton.centerYAnchor
            constraintEqualToAnchor:self.searchCapsule.centerYAnchor],
        [self.clearSearchButton.widthAnchor constraintEqualToConstant:28.0],
        [self.clearSearchButton.heightAnchor constraintEqualToConstant:28.0]
    ]];

    self.searchBottomConstraint =
        [self.bottomSearchContainer.bottomAnchor
            constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor
                           constant:-12.0];

    self.searchBottomConstraint.active = YES;

    self.tableView.contentInset = UIEdgeInsetsMake(6.0, 0.0, 84.0, 0.0);
    self.tableView.scrollIndicatorInsets = self.tableView.contentInset;
}

- (void)searchTextChanged:(UITextField *)sender {
    self.clearSearchButton.hidden = sender.text.length == 0;
    [self refreshVisible];
}

- (void)clearSearch {
    self.searchField.text = @"";
    self.clearSearchButton.hidden = YES;
    [self refreshVisible];
    [self.searchField becomeFirstResponder];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - Keyboard

- (void)registerKeyboardNotifications {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

    [center addObserver:self
               selector:@selector(keyboardWillChangeFrame:)
                   name:UIKeyboardWillChangeFrameNotification
                 object:nil];

    [center addObserver:self
               selector:@selector(keyboardWillHide:)
                   name:UIKeyboardWillHideNotification
                 object:nil];
}

- (void)keyboardWillChangeFrame:(NSNotification *)notification {
    if (!self.searchBottomConstraint) return;

    NSDictionary *info = notification.userInfo;
    CGRect keyboardFrame = [info[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect localFrame = [self.view convertRect:keyboardFrame fromView:nil];

    CGFloat safeBottom =
        CGRectGetMaxY(self.view.bounds) - self.view.safeAreaInsets.bottom;

    CGFloat overlap = MAX(0.0, safeBottom - CGRectGetMinY(localFrame));

    self.searchBottomConstraint.constant =
        overlap > 0.0 ? -(overlap + 8.0) : -12.0;

    NSTimeInterval duration =
        [info[UIKeyboardAnimationDurationUserInfoKey] doubleValue];

    UIViewAnimationCurve curve =
        (UIViewAnimationCurve)[info[UIKeyboardAnimationCurveUserInfoKey] integerValue];

    [UIView animateWithDuration:duration
                          delay:0
                        options:(UIViewAnimationOptions)(curve << 16)
                     animations:^{
        [self.view layoutIfNeeded];
    } completion:nil];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    if (!self.searchBottomConstraint) return;

    NSTimeInterval duration =
        [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];

    self.searchBottomConstraint.constant = -12.0;

    [UIView animateWithDuration:duration animations:^{
        [self.view layoutIfNeeded];
    }];
}

#pragma mark - Search and Filtering

- (void)refreshVisible {
    NSString *keyword = self.searchField.text ?: @"";

    self.visibleFeatures =
        [[KDUFeatureRegistry shared]
            featuresMatching:keyword
                    category:self.selectedCategory] ?: @[];

    [self.tableView reloadData];
    [self updateEmptyState];
}

- (void)updateEmptyState {
    if (self.visibleFeatures.count > 0) {
        self.tableView.tableFooterView = [UIView new];
        return;
    }

    UILabel *emptyLabel = [UILabel new];
    emptyLabel.frame = CGRectMake(0, 0, self.tableView.bounds.size.width, 110.0);
    emptyLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    emptyLabel.text = self.searchField.text.length > 0
        ? @"没有找到匹配的功能"
        : @"当前分类暂无功能";
    emptyLabel.textColor = UIColor.secondaryLabelColor;
    emptyLabel.textAlignment = NSTextAlignmentCenter;
    emptyLabel.font = [UIFont systemFontOfSize:14.0];
    emptyLabel.numberOfLines = 0;

    self.tableView.tableFooterView = emptyLabel;
}

#pragma mark - Table Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? 1 : self.visibleFeatures.count;
}

- (NSString *)tableView:(UITableView *)tableView
 titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"功能分类" : @"功能列表";
}

- (UIView *)tableView:(UITableView *)tableView
 viewForHeaderInSection:(NSInteger)section {
    UILabel *label = [UILabel new];
    label.text = [self tableView:tableView titleForHeaderInSection:section];
    label.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    label.textColor = UIColor.secondaryLabelColor;
    label.backgroundColor = UIColor.clearColor;

    UIView *container = [UIView new];
    container.backgroundColor = UIColor.clearColor;
    [container addSubview:label];

    label.translatesAutoresizingMaskIntoConstraints = NO;

    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:18.0],
        [label.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-18.0],
        [label.topAnchor constraintEqualToAnchor:container.topAnchor constant:8.0],
        [label.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-5.0]
    ]];

    return container;
}

- (CGFloat)tableView:(UITableView *)tableView
 heightForHeaderInSection:(NSInteger)section {
    return 36.0;
}

- (CGFloat)tableView:(UITableView *)tableView
 estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 0 ? 76.0 : 96.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    KDUFeatureTableCell *cell =
        [tableView dequeueReusableCellWithIdentifier:@"FeatureCell"
                                        forIndexPath:indexPath];

    [cell applyGlassStyle:[self isLiquidGlassEnabled]];
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;

    if (indexPath.section == 0) {
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        cell.titleLabel.text =
            [NSString stringWithFormat:@"分类：%@", self.selectedCategory ?: @"全部"];
        cell.titleLabel.textColor = UIColor.labelColor;
        cell.detailLabel.text = @"轻点选择功能分类";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }

    cell.selectionStyle = UITableViewCellSelectionStyleDefault;

    KDUFeature *feature = self.visibleFeatures[indexPath.row];

    cell.titleLabel.text =
        [NSString stringWithFormat:@"%@ · %@",
            feature.title ?: @"未命名功能",
            feature.implemented ? @"已实现" : @"开发中"];

    cell.titleLabel.textColor = feature.implemented
        ? UIColor.labelColor
        : UIColor.secondaryLabelColor;

    BOOL currentValue = [[KDUConfigManager shared]
        boolForKey:feature.configKey
          fallback:feature.defaultEnabled];
    NSString *state = feature.implemented
        ? (currentValue ? @"当前已开启" : @"当前已关闭")
        : @"尚未开放";
    cell.detailLabel.text = [NSString stringWithFormat:@"%@\n%@", state, feature.detail ?: @""];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

#pragma mark - Category Picker

- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 1) {
        if (indexPath.row >= self.visibleFeatures.count) return;
        [self.searchField resignFirstResponder];
        KDUFeatureDetailController *detail = [KDUFeatureDetailController new];
        detail.feature = self.visibleFeatures[indexPath.row];
        [self.navigationController pushViewController:detail animated:YES];
        return;
    }

    if (self.categories.count == 0) return;

    [self.searchField resignFirstResponder];

    UIAlertController *picker =
        [UIAlertController alertControllerWithTitle:@"选择功能分类"
                                            message:nil
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    __weak typeof(self) weakSelf = self;

    for (NSString *category in self.categories) {
        NSString *title = [category isEqualToString:self.selectedCategory]
            ? [NSString stringWithFormat:@"✓ %@", category]
            : category;

        [picker addAction:
            [UIAlertAction actionWithTitle:title
                                     style:UIAlertActionStyleDefault
                                   handler:^(__unused UIAlertAction *action) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;

            self.selectedCategory = category;
            [self refreshVisible];
        }]];
    }

    [picker addAction:
        [UIAlertAction actionWithTitle:@"取消"
                                 style:UIAlertActionStyleCancel
                               handler:nil]];

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        picker.popoverPresentationController.sourceView = tableView;
        picker.popoverPresentationController.sourceRect =
            [tableView rectForRowAtIndexPath:indexPath];
    }

    [self presentViewController:picker animated:YES completion:nil];
}

#pragma mark - Feature Switches

- (void)toggleChanged:(UISwitch *)sender {
    NSString *configKey = sender.accessibilityIdentifier;
    if (configKey.length == 0) return;

    KDUFeature *matchedFeature = nil;

    for (KDUFeature *feature in [[KDUFeatureRegistry shared] allFeatures]) {
        if ([feature.configKey isEqualToString:configKey] ||
            [feature.identifier isEqualToString:configKey]) {
            matchedFeature = feature;
            break;
        }
    }

    if (!matchedFeature) {
        sender.on = NO;
        return;
    }

    BOOL isGlassSetting =
        [matchedFeature.identifier isEqualToString:@"interface.liquidGlass"];

    if (!matchedFeature.implemented && !isGlassSetting) {
        sender.on = NO;
        return;
    }

    [[KDUConfigManager shared] setBool:sender.isOn
                                forKey:matchedFeature.configKey];

    if (isGlassSetting) {
        self.liquidGlassEnabled = sender.isOn;
        [self updateNavigationAppearance];
        [self.tableView reloadData];
    }
}

#pragma mark - Tools

- (void)showTools {
    [self.searchField resignFirstResponder];

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"K-Douyin Ultra 工具"
                                            message:@"请选择要执行的操作。"
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    __weak typeof(self) weakSelf = self;

    [alert addAction:
        [UIAlertAction actionWithTitle:@"导出配置 JSON"
                                 style:UIAlertActionStyleDefault
                               handler:^(__unused UIAlertAction *action) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        NSData *data = [[KDUConfigManager shared] exportFeatureConfigJSON];

        if (!data) {
            [self showMessage:@"导出失败" message:@"无法生成配置文件。"];
            return;
        }

        NSString *path =
            [NSTemporaryDirectory() stringByAppendingPathComponent:
                @"K-Douyin-Ultra-config.json"];

        if (![data writeToFile:path atomically:YES]) {
            [self showMessage:@"导出失败" message:@"无法写入临时配置文件。"];
            return;
        }

        UIActivityViewController *share =
            [[UIActivityViewController alloc]
                initWithActivityItems:@[[NSURL fileURLWithPath:path]]
                applicationActivities:nil];

        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            share.popoverPresentationController.barButtonItem =
                self.navigationItem.rightBarButtonItem;
        }

        [self presentViewController:share animated:YES completion:nil];
    }]];

    [alert addAction:
        [UIAlertAction actionWithTitle:@"环境诊断"
                                 style:UIAlertActionStyleDefault
                               handler:^(__unused UIAlertAction *action) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        NSDictionary *d = [[KDUCompatibility shared] diagnostics] ?: @{};

        NSString *message =
            [NSString stringWithFormat:
                @"应用标识：%@\n应用版本：%@ (%@)\niOS 版本：%@\n状态：%@",
                d[@"bundleIdentifier"] ?: @"未知",
                d[@"appVersion"] ?: @"未知",
                d[@"appBuild"] ?: @"未知",
                d[@"systemVersion"] ?: @"未知",
                d[@"status"] ?: @"未知"];

        UIAlertController *diag =
            [UIAlertController alertControllerWithTitle:@"环境诊断"
                                                message:message
                                         preferredStyle:UIAlertControllerStyleAlert];

        [diag addAction:
            [UIAlertAction actionWithTitle:@"关闭"
                                     style:UIAlertActionStyleCancel
                                   handler:nil]];

        [self presentViewController:diag animated:YES completion:nil];
    }]];

    [alert addAction:
        [UIAlertAction actionWithTitle:@"重置全部开关"
                                 style:UIAlertActionStyleDestructive
                               handler:^(__unused UIAlertAction *action) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        [[KDUConfigManager shared] resetToDefaults];

        self.liquidGlassEnabled =
            [[KDUConfigManager shared] boolForKey:@"interface.liquidGlass"
                                         fallback:YES];

        [self updateNavigationAppearance];
        [self refreshVisible];
    }]];

    [alert addAction:
        [UIAlertAction actionWithTitle:@"取消"
                                 style:UIAlertActionStyleCancel
                               handler:nil]];

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.barButtonItem =
            self.navigationItem.rightBarButtonItem;
    }

    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Message

- (void)showMessage:(NSString *)title message:(NSString *)message {
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:title
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:
        [UIAlertAction actionWithTitle:@"确定"
                                 style:UIAlertActionStyleCancel
                               handler:nil]];

    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Cleanup

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
