#import "KDUSettingsController.h"
#import "KDUFeatureRegistry.h"
#import "KDUConfigManager.h"
#import "KDUCompatibility.h"
#import <QuartzCore/QuartzCore.h>

#pragma mark - Glass Feature Cell

@interface KDUFeatureTableCell : UITableViewCell

@property (nonatomic, assign) BOOL glassEnabled;

@end

@implementation KDUFeatureTableCell {
    UIVisualEffectView *_glassView;
    UIView *_fallbackBackground;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:UITableViewCellStyleSubtitle
                reuseIdentifier:reuseIdentifier];

    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = UIColor.clearColor;
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _fallbackBackground = [UIView new];
        _fallbackBackground.translatesAutoresizingMaskIntoConstraints = NO;
        _fallbackBackground.layer.cornerRadius = 16.0;
        _fallbackBackground.layer.cornerCurve =
            kCACornerCurveContinuous;
        _fallbackBackground.layer.borderWidth = 0.7;
        _fallbackBackground.userInteractionEnabled = NO;

        [self.contentView insertSubview:_fallbackBackground atIndex:0];

        _glassView = [[UIVisualEffectView alloc]
            initWithEffect:nil];

        _glassView.translatesAutoresizingMaskIntoConstraints = NO;
        _glassView.layer.cornerRadius = 16.0;
        _glassView.layer.cornerCurve = kCACornerCurveContinuous;
        _glassView.clipsToBounds = YES;
        _glassView.userInteractionEnabled = NO;

        [self.contentView insertSubview:_glassView atIndex:0];

        [NSLayoutConstraint activateConstraints:@[
            [_glassView.topAnchor
                constraintEqualToAnchor:self.contentView.topAnchor
                               constant:4.0],
            [_glassView.bottomAnchor
                constraintEqualToAnchor:self.contentView.bottomAnchor
                               constant:-4.0],
            [_glassView.leadingAnchor
                constraintEqualToAnchor:self.contentView.leadingAnchor
                               constant:12.0],
            [_glassView.trailingAnchor
                constraintEqualToAnchor:self.contentView.trailingAnchor
                               constant:-12.0],

            [_fallbackBackground.topAnchor
                constraintEqualToAnchor:self.contentView.topAnchor
                               constant:4.0],
            [_fallbackBackground.bottomAnchor
                constraintEqualToAnchor:self.contentView.bottomAnchor
                               constant:-4.0],
            [_fallbackBackground.leadingAnchor
                constraintEqualToAnchor:self.contentView.leadingAnchor
                               constant:12.0],
            [_fallbackBackground.trailingAnchor
                constraintEqualToAnchor:self.contentView.trailingAnchor
                               constant:-12.0]
        ]];

        self.textLabel.font =
            [UIFont systemFontOfSize:15
                              weight:UIFontWeightSemibold];

        self.detailTextLabel.font =
            [UIFont systemFontOfSize:12
                              weight:UIFontWeightRegular];

        self.detailTextLabel.numberOfLines = 2;
        self.detailTextLabel.textColor = UIColor.secondaryLabelColor;

        self.contentView.layoutMargins =
            UIEdgeInsetsMake(10, 14, 10, 14);

        [self updateGlassAppearance];
    }

    return self;
}

- (void)setGlassEnabled:(BOOL)glassEnabled {
    if (_glassEnabled == glassEnabled) {
        [self updateGlassAppearance];
        return;
    }

    _glassEnabled = glassEnabled;
    [self updateGlassAppearance];
}

- (void)updateGlassAppearance {
    if (!_glassView || !_fallbackBackground) {
        return;
    }

    if (@available(iOS 13.0, *)) {
        _fallbackBackground.backgroundColor =
            [UIColor.secondarySystemGroupedBackgroundColor
                colorWithAlphaComponent:
                    self.glassEnabled ? 0.28 : 0.92];

        _fallbackBackground.layer.borderColor =
            [UIColor.separatorColor
                colorWithAlphaComponent:
                    self.glassEnabled ? 0.40 : 0.20].CGColor;

        _glassView.effect = self.glassEnabled
            ? [UIBlurEffect effectWithStyle:
                UIBlurEffectStyleSystemThinMaterial]
            : nil;

        _glassView.layer.borderWidth =
            self.glassEnabled ? 0.7 : 0.0;

        _glassView.layer.borderColor =
            [UIColor.whiteColor
                colorWithAlphaComponent:0.35].CGColor;

        _glassView.hidden = !self.glassEnabled;

        self.contentView.layer.shadowColor =
            UIColor.blackColor.CGColor;

        self.contentView.layer.shadowOpacity =
            self.glassEnabled ? 0.10 : 0.0;

        self.contentView.layer.shadowRadius =
            self.glassEnabled ? 8.0 : 0.0;

        self.contentView.layer.shadowOffset =
            CGSizeMake(0, 3);

        self.textLabel.textColor = UIColor.labelColor;
        self.detailTextLabel.textColor =
            UIColor.secondaryLabelColor;
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.accessoryView = nil;
    self.accessoryType = UITableViewCellAccessoryNone;
}

@end

#pragma mark - Settings Controller

@interface KDUSettingsController () <UISearchResultsUpdating>

@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, copy) NSArray<KDUFeature *> *visibleFeatures;
@property (nonatomic, copy) NSArray<NSString *> *categories;
@property (nonatomic, copy) NSString *selectedCategory;

@end

@implementation KDUSettingsController

#pragma mark Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"K-Douyin Ultra";
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.contentInset = UIEdgeInsetsMake(6, 0, 18, 0);

    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 8.0;
    }

    self.navigationController.navigationBar.tintColor =
        UIColor.labelColor;

    if (@available(iOS 13.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = YES;

        UINavigationBarAppearance *appearance =
            [UINavigationBarAppearance new];

        [appearance configureWithDefaultBackground];

        appearance.backgroundEffect =
            [UIBlurEffect effectWithStyle:
                UIBlurEffectStyleSystemChromeMaterial];

        appearance.backgroundColor =
            [UIColor.systemBackgroundColor
                colorWithAlphaComponent:0.72];

        self.navigationController.navigationBar.standardAppearance =
            appearance;

        self.navigationController.navigationBar.scrollEdgeAppearance =
            appearance;

        self.navigationController.navigationBar.compactAppearance =
            appearance;
    }

    self.navigationItem.largeTitleDisplayMode =
        UINavigationItemLargeTitleDisplayModeAlways;

    self.navigationController.navigationBar.prefersLargeTitles = YES;

    self.categories = [[KDUFeatureRegistry shared] categories];
    self.selectedCategory = @"全部";

    self.visibleFeatures =
        [[KDUFeatureRegistry shared]
            featuresMatching:@""
                    category:self.selectedCategory];

    self.searchController =
        [[UISearchController alloc]
            initWithSearchResultsController:nil];

    self.searchController.searchResultsUpdater = self;
    self.searchController.searchBar.placeholder = @"搜索全部功能";
    self.searchController.searchBar.searchBarStyle =
        UISearchBarStyleMinimal;
    self.searchController.obscuresBackgroundDuringPresentation = NO;

    self.navigationItem.searchController = self.searchController;
    self.definesPresentationContext = YES;

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc]
            initWithTitle:@"工具"
                    style:UIBarButtonItemStylePlain
                   target:self
                   action:@selector(showTools)];

    [self.tableView registerClass:KDUFeatureTableCell.class
           forCellReuseIdentifier:@"FeatureCell"];

    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 82.0;
    self.tableView.keyboardDismissMode =
        UIScrollViewKeyboardDismissModeOnDrag;

    [self refreshVisible];
}

- (BOOL)isLiquidGlassEnabled {
    return [[KDUConfigManager shared]
        boolForKey:@"interface.liquidGlass"
          fallback:YES];
}

#pragma mark Search and Filtering

- (void)refreshVisible {
    NSString *keyword =
        self.searchController.searchBar.text ?: @"";

    self.visibleFeatures =
        [[KDUFeatureRegistry shared]
            featuresMatching:keyword
                    category:self.selectedCategory];

    [self.tableView reloadData];
}

- (void)updateSearchResultsForSearchController:
    (UISearchController *)searchController {
    [self refreshVisible];
}

#pragma mark Table Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? 1 : self.visibleFeatures.count;
}

- (NSString *)tableView:(UITableView *)tableView
 titleForHeaderInSection:(NSInteger)section {
    return section == 0
        ? @"功能分类"
        : @"功能列表 · 待实现项目暂不可用";
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    KDUFeatureTableCell *cell =
        [tableView dequeueReusableCellWithIdentifier:@"FeatureCell"
                                        forIndexPath:indexPath];

    cell.glassEnabled = [self isLiquidGlassEnabled];

    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;

    if (indexPath.section == 0) {
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;

        cell.textLabel.text =
            [NSString stringWithFormat:@"分类：%@",
                                       self.selectedCategory];

        cell.textLabel.textColor = UIColor.labelColor;
        cell.detailTextLabel.text = @"轻点选择分类";
        cell.accessoryType =
            UITableViewCellAccessoryDisclosureIndicator;

        return cell;
    }

    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    KDUFeature *feature = self.visibleFeatures[indexPath.row];

    cell.textLabel.text =
        [NSString stringWithFormat:@"%@ · %@",
            feature.title,
            feature.implemented ? @"已实现" : @"待实现"];

    cell.textLabel.textColor = feature.implemented
        ? UIColor.labelColor
        : UIColor.secondaryLabelColor;

    cell.detailTextLabel.text = feature.detail;

    UISwitch *toggle = [UISwitch new];

    toggle.on = [[KDUConfigManager shared]
        boolForKey:feature.configKey
          fallback:feature.defaultEnabled];

    toggle.enabled =
        feature.implemented ||
        [feature.identifier isEqualToString:@"interface.liquidGlass"];

    toggle.alpha = toggle.enabled ? 1.0 : 0.50;
    toggle.accessibilityLabel = feature.title;

    [toggle addTarget:self
               action:@selector(toggleChanged:)
     forControlEvents:UIControlEventValueChanged];

    cell.accessoryView = toggle;

    return cell;
}

#pragma mark Category Picker

- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    if (indexPath.section != 0 || self.categories.count == 0) {
        return;
    }

    UIAlertController *picker =
        [UIAlertController
            alertControllerWithTitle:@"选择功能分类"
                             message:nil
                      preferredStyle:UIAlertControllerStyleActionSheet];

    for (NSString *category in self.categories) {
        NSString *title =
            [category isEqualToString:self.selectedCategory]
                ? [NSString stringWithFormat:@"✓ %@", category]
                : category;

        [picker addAction:
            [UIAlertAction
                actionWithTitle:title
                          style:UIAlertActionStyleDefault
                        handler:^(__unused UIAlertAction *action) {

            self.selectedCategory = category;
            [self refreshVisible];
        }]];
    }

    [picker addAction:
        [UIAlertAction
            actionWithTitle:@"取消"
                      style:UIAlertActionStyleCancel
                    handler:nil]];

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        picker.popoverPresentationController.sourceView = tableView;
        picker.popoverPresentationController.sourceRect =
            [tableView rectForRowAtIndexPath:indexPath];
    }

    [self presentViewController:picker animated:YES completion:nil];

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark Feature Switches

- (void)toggleChanged:(UISwitch *)sender {
    NSIndexPath *indexPath = nil;

    CGPoint point = [sender convertPoint:CGPointZero
                                  toView:self.tableView];

    indexPath = [self.tableView indexPathForRowAtPoint:point];

    if (!indexPath || indexPath.section != 1 ||
        indexPath.row >= self.visibleFeatures.count) {
        return;
    }

    KDUFeature *feature = self.visibleFeatures[indexPath.row];

    if (!feature.implemented &&
        ![feature.identifier isEqualToString:@"interface.liquidGlass"]) {
        sender.on = NO;
        return;
    }

    [[KDUConfigManager shared] setBool:sender.isOn
                                forKey:feature.configKey];

    if ([feature.identifier isEqualToString:@"interface.liquidGlass"]) {
        [self.tableView reloadData];
    }
}

#pragma mark Tools

- (void)showTools {
    UIAlertController *alert =
        [UIAlertController
            alertControllerWithTitle:@"K-Douyin Ultra 工具"
                             message:@"请选择要执行的操作。"
                      preferredStyle:UIAlertControllerStyleActionSheet];

    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"导出配置 JSON"
                      style:UIAlertActionStyleDefault
                    handler:^(__unused UIAlertAction *action) {

        NSData *data =
            [[KDUConfigManager shared] exportFeatureConfigJSON];

        if (!data) {
            return;
        }

        NSString *path =
            [NSTemporaryDirectory()
                stringByAppendingPathComponent:
                    @"K-Douyin-Ultra-config.json"];

        if (![data writeToFile:path atomically:YES]) {
            return;
        }

        UIActivityViewController *share =
            [[UIActivityViewController alloc]
                initWithActivityItems:
                    @[[NSURL fileURLWithPath:path]]
                applicationActivities:nil];

        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            share.popoverPresentationController.barButtonItem =
                self.navigationItem.rightBarButtonItem;
        }

        [self presentViewController:share
                           animated:YES
                         completion:nil];
    }]];

    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"环境诊断"
                      style:UIAlertActionStyleDefault
                    handler:^(__unused UIAlertAction *action) {

        NSDictionary *d =
            [[KDUCompatibility shared] diagnostics];

        NSString *message =
            [NSString stringWithFormat:
                @"应用标识：%@\n"
                 "应用版本：%@ (%@)\n"
                 "iOS 版本：%@\n"
                 "状态：%@",
                d[@"bundleIdentifier"],
                d[@"appVersion"],
                d[@"appBuild"],
                d[@"systemVersion"],
                d[@"status"]];

        UIAlertController *diag =
            [UIAlertController
                alertControllerWithTitle:@"环境诊断"
                                 message:message
                          preferredStyle:UIAlertControllerStyleAlert];

        [diag addAction:
            [UIAlertAction
                actionWithTitle:@"关闭"
                          style:UIAlertActionStyleCancel
                        handler:nil]];

        [self presentViewController:diag
                           animated:YES
                         completion:nil];
    }]];

    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"重置全部开关"
                      style:UIAlertActionStyleDestructive
                    handler:^(__unused UIAlertAction *action) {

        [[KDUConfigManager shared] resetToDefaults];
        [self refreshVisible];
    }]];

    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"取消"
                      style:UIAlertActionStyleCancel
                    handler:nil]];

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.barButtonItem =
            self.navigationItem.rightBarButtonItem;
    }

    [self presentViewController:alert
                       animated:YES
                     completion:nil];
}

@end
