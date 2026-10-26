#import "KDUSettingsController.h"
#import "KDUFeatureRegistry.h"
#import "KDUConfigManager.h"
#import "KDUCompatibility.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - Glass Feature Cell

@interface KDUFeatureTableCell : UITableViewCell

@property (nonatomic, assign) BOOL glassEnabled;
@property (nonatomic, strong) UIVisualEffectView *glassView;
@property (nonatomic, strong) UIView *fallbackView;

- (void)applyGlassStyle:(BOOL)enabled;

@end

@implementation KDUFeatureTableCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:UITableViewCellStyleSubtitle
                reuseIdentifier:reuseIdentifier];
    if (!self) return nil;

    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.selectionStyle = UITableViewCellSelectionStyleNone;

    self.fallbackView = [UIView new];
    self.fallbackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.fallbackView.layer.cornerRadius = 18.0;
    self.fallbackView.layer.cornerCurve = kCACornerCurveContinuous;
    self.fallbackView.layer.borderWidth = 0.7;
    self.fallbackView.userInteractionEnabled = NO;

    [self.contentView insertSubview:self.fallbackView atIndex:0];

    self.glassView = [[UIVisualEffectView alloc] initWithEffect:nil];
    self.glassView.translatesAutoresizingMaskIntoConstraints = NO;
    self.glassView.layer.cornerRadius = 18.0;
    self.glassView.layer.cornerCurve = kCACornerCurveContinuous;
    self.glassView.clipsToBounds = YES;
    self.glassView.userInteractionEnabled = NO;

    [self.contentView insertSubview:self.glassView aboveSubview:self.fallbackView];

    [NSLayoutConstraint activateConstraints:@[
        [self.fallbackView.topAnchor
            constraintEqualToAnchor:self.contentView.topAnchor constant:5.0],
        [self.fallbackView.bottomAnchor
            constraintEqualToAnchor:self.contentView.bottomAnchor constant:-5.0],
        [self.fallbackView.leadingAnchor
            constraintEqualToAnchor:self.contentView.leadingAnchor constant:12.0],
        [self.fallbackView.trailingAnchor
            constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12.0],

        [self.glassView.topAnchor
            constraintEqualToAnchor:self.fallbackView.topAnchor],
        [self.glassView.bottomAnchor
            constraintEqualToAnchor:self.fallbackView.bottomAnchor],
        [self.glassView.leadingAnchor
            constraintEqualToAnchor:self.fallbackView.leadingAnchor],
        [self.glassView.trailingAnchor
            constraintEqualToAnchor:self.fallbackView.trailingAnchor]
    ]];

    self.textLabel.font =
        [UIFont systemFontOfSize:15.5 weight:UIFontWeightSemibold];
    self.textLabel.numberOfLines = 0;
    self.textLabel.lineBreakMode = NSLineBreakByWordWrapping;

    self.detailTextLabel.font =
        [UIFont systemFontOfSize:12.5 weight:UIFontWeightRegular];
    self.detailTextLabel.numberOfLines = 0;
    self.detailTextLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.detailTextLabel.textColor = UIColor.secondaryLabelColor;

    self.contentView.layoutMargins = UIEdgeInsetsMake(12, 16, 12, 16);

    [self applyGlassStyle:NO];
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    self.fallbackView.frame = self.contentView.bounds;
    self.glassView.frame = self.fallbackView.bounds;
}

- (void)applyGlassStyle:(BOOL)enabled {
    self.glassEnabled = enabled;

    self.fallbackView.backgroundColor =
        [UIColor.secondarySystemGroupedBackgroundColor
            colorWithAlphaComponent:enabled ? 0.24 : 0.94];

    self.fallbackView.layer.borderColor =
        [UIColor.separatorColor
            colorWithAlphaComponent:enabled ? 0.38 : 0.18].CGColor;

    self.glassView.effect = enabled
        ? [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial]
        : nil;
    self.glassView.hidden = !enabled;

    self.glassView.layer.borderWidth = enabled ? 0.6 : 0.0;
    self.glassView.layer.borderColor =
        [UIColor.whiteColor colorWithAlphaComponent:0.35].CGColor;

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
    self.textLabel.text = nil;
    self.detailTextLabel.text = nil;
}

@end

#pragma mark - Settings Controller

@interface KDUSettingsController () <UISearchResultsUpdating>

@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, copy) NSArray<KDUFeature *> *visibleFeatures;
@property (nonatomic, copy) NSArray<NSString *> *categories;
@property (nonatomic, copy) NSString *selectedCategory;
@property (nonatomic, assign) BOOL liquidGlassEnabled;

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
    self.tableView.contentInsetAdjustmentBehavior =
        UIScrollViewContentInsetAdjustmentAutomatic;
    self.tableView.keyboardDismissMode =
        UIScrollViewKeyboardDismissModeOnDrag;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 96.0;

    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 8.0;
    }

    self.liquidGlassEnabled = [[KDUConfigManager shared]
        boolForKey:@"interface.liquidGlass"
          fallback:YES];

    self.categories = [[KDUFeatureRegistry shared] categories];
    if (![self.categories containsObject:@"全部"]) {
        self.categories = [@[@"全部"] arrayByAddingObjectsFromArray:
                          self.categories ?: @[]];
    }
    self.selectedCategory = @"全部";

    self.navigationItem.largeTitleDisplayMode =
        UINavigationItemLargeTitleDisplayModeAlways;
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.navigationController.navigationBar.tintColor = UIColor.labelColor;

    [self updateNavigationAppearance];

    self.searchController =
        [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.searchBar.placeholder = @"搜索全部功能";
    self.searchController.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.hidesNavigationBarDuringPresentation = NO;

    self.navigationItem.searchController = self.searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.definesPresentationContext = YES;

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"工具"
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(showTools)];

    [self.tableView registerClass:KDUFeatureTableCell.class
           forCellReuseIdentifier:@"FeatureCell"];

    [self refreshVisible];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    self.liquidGlassEnabled = [[KDUConfigManager shared]
        boolForKey:@"interface.liquidGlass"
          fallback:YES];

    [self updateNavigationAppearance];
    [self.tableView reloadData];
}

- (BOOL)isLiquidGlassEnabled {
    return [[KDUConfigManager shared]
        boolForKey:@"interface.liquidGlass"
          fallback:YES];
}

#pragma mark Appearance

- (void)updateNavigationAppearance {
    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *appearance =
            [UINavigationBarAppearance new];

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
}

#pragma mark Search and Filtering

- (void)refreshVisible {
    NSString *keyword = self.searchController.searchBar.text ?: @"";

    self.visibleFeatures =
        [[KDUFeatureRegistry shared]
            featuresMatching:keyword
                    category:self.selectedCategory];

    [self.tableView reloadData];
    [self updateEmptyState];
}

- (void)updateEmptyState {
    if (self.visibleFeatures.count > 0) {
        self.tableView.tableFooterView = [UIView new];
        return;
    }

    UILabel *emptyLabel = [UILabel new];
    emptyLabel.frame = CGRectMake(0, 0, self.tableView.bounds.size.width, 110);
    emptyLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    emptyLabel.text = self.searchController.searchBar.text.length > 0
        ? @"没有找到匹配的功能"
        : @"当前分类暂无功能";
    emptyLabel.textColor = UIColor.secondaryLabelColor;
    emptyLabel.textAlignment = NSTextAlignmentCenter;
    emptyLabel.font = [UIFont systemFontOfSize:14.0];
    emptyLabel.numberOfLines = 0;

    self.tableView.tableFooterView = emptyLabel;
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
    if (section == 0) {
        return @"功能分类";
    }

    return @"功能列表";
}

- (UIView *)tableView:(UITableView *)tableView
 viewForHeaderInSection:(NSInteger)section {
    NSString *heading = [self tableView:tableView
                 titleForHeaderInSection:section];

    UILabel *label = [UILabel new];
    label.text = heading;
    label.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    label.textColor = UIColor.secondaryLabelColor;
    label.backgroundColor = UIColor.clearColor;

    UIView *container = [UIView new];
    container.backgroundColor = UIColor.clearColor;
    [container addSubview:label];
    label.translatesAutoresizingMaskIntoConstraints = NO;

    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:container.leadingAnchor
                                            constant:18.0],
        [label.trailingAnchor constraintEqualToAnchor:container.trailingAnchor
                                             constant:-18.0],
        [label.topAnchor constraintEqualToAnchor:container.topAnchor
                                        constant:8.0],
        [label.bottomAnchor constraintEqualToAnchor:container.bottomAnchor
                                           constant:-5.0]
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

    cell.glassEnabled = [self isLiquidGlassEnabled];
    [cell applyGlassStyle:cell.glassEnabled];

    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.textLabel.numberOfLines = 0;
    cell.detailTextLabel.numberOfLines = 0;
    cell.contentView.layoutMargins = UIEdgeInsetsMake(12, 16, 12, 16);

    if (indexPath.section == 0) {
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        cell.textLabel.text =
            [NSString stringWithFormat:@"分类：%@", self.selectedCategory ?: @"全部"];
        cell.textLabel.textColor = UIColor.labelColor;
        cell.detailTextLabel.text = @"轻点选择功能分类";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }

    KDUFeature *feature = self.visibleFeatures[indexPath.row];

    cell.textLabel.text =
        [NSString stringWithFormat:@"%@ · %@",
            feature.title ?: @"未命名功能",
            feature.implemented ? @"已实现" : @"待实现"];

    cell.textLabel.textColor = feature.implemented
        ? UIColor.labelColor
        : UIColor.secondaryLabelColor;

    cell.detailTextLabel.text = feature.detail ?: @"";

    UISwitch *toggle = [UISwitch new];
    toggle.on = [[KDUConfigManager shared]
        boolForKey:feature.configKey
          fallback:feature.defaultEnabled];

    BOOL isGlassSetting =
        [feature.identifier isEqualToString:@"interface.liquidGlass"];

    toggle.enabled = feature.implemented || isGlassSetting;
    toggle.alpha = toggle.enabled ? 1.0 : 0.45;
    toggle.accessibilityLabel = feature.title ?: @"功能开关";

    // 用配置键保存身份，避免搜索、分类切换和重用导致行号错配。
    toggle.accessibilityIdentifier = feature.configKey ?: feature.identifier;
    toggle.onTintColor = UIColor.systemGreenColor;

    [toggle addTarget:self
               action:@selector(toggleChanged:)
     forControlEvents:UIControlEventValueChanged];

    cell.accessoryView = toggle;
    return cell;
}

#pragma mark Category Picker

- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section != 0 || self.categories.count == 0) {
        return;
    }

    UIAlertController *picker =
        [UIAlertController alertControllerWithTitle:@"选择功能分类"
                                            message:nil
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    for (NSString *category in self.categories) {
        NSString *title = [category isEqualToString:self.selectedCategory]
            ? [NSString stringWithFormat:@"✓ %@", category]
            : category;

        [picker addAction:
            [UIAlertAction actionWithTitle:title
                                     style:UIAlertActionStyleDefault
                                   handler:^(__unused UIAlertAction *action) {
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

#pragma mark Feature Switches

- (void)toggleChanged:(UISwitch *)sender {
    NSString *configKey = sender.accessibilityIdentifier;
    if (configKey.length == 0) {
        return;
    }

    KDUFeature *matchedFeature = nil;

    for (KDUFeature *feature in self.visibleFeatures) {
        BOOL keyMatches = [feature.configKey isEqualToString:configKey];
        BOOL identifierMatches = [feature.identifier isEqualToString:configKey];

        if (keyMatches || identifierMatches) {
            matchedFeature = feature;
            break;
        }
    }

    // 当前搜索/分类可能已经变化；若可见列表中未找到，再到完整注册表查询。
    if (!matchedFeature) {
        NSArray<KDUFeature *> *allFeatures =
            [[KDUFeatureRegistry shared]
                featuresMatching:@""
                        category:@"全部"];

        for (KDUFeature *feature in allFeatures) {
            if ([feature.configKey isEqualToString:configKey] ||
                [feature.identifier isEqualToString:configKey]) {
                matchedFeature = feature;
                break;
            }
        }
    }

    if (!matchedFeature) {
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

#pragma mark Tools

- (void)showTools {
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

        NSData *data =
            [[KDUConfigManager shared] exportFeatureConfigJSON];

        if (!data) {
            [self showMessage:@"导出失败" message:@"无法生成配置文件。"];
            return;
        }

        NSString *path =
            [NSTemporaryDirectory()
                stringByAppendingPathComponent:@"K-Douyin-Ultra-config.json"];

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
                @"应用标识：%@\n"
                 "应用版本：%@ (%@)\n"
                 "iOS 版本：%@\n"
                 "状态：%@",
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
        self.liquidGlassEnabled = [[KDUConfigManager shared]
            boolForKey:@"interface.liquidGlass"
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

@end