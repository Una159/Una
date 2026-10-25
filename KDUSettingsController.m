#import "KDUSettingsController.h"
#import "KDUFeatureRegistry.h"
#import "KDUConfigManager.h"
#import "KDUCompatibility.h"

@interface KDUFeatureTableCell : UITableViewCell
@end

@implementation KDUFeatureTableCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor = [UIColor.secondarySystemGroupedBackgroundColor colorWithAlphaComponent:0.78];
        self.contentView.layer.cornerRadius = 14.0;
        self.contentView.layer.cornerCurve = kCACornerCurveContinuous;
        self.contentView.layer.masksToBounds = YES;
        self.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        self.detailTextLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
        self.detailTextLabel.textColor = UIColor.secondaryLabelColor;
        self.detailTextLabel.numberOfLines = 2;
    }
    return self;
}
@end

@interface KDUSettingsController () <UISearchResultsUpdating>
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, copy) NSArray<KDUFeature *> *visibleFeatures;
@property (nonatomic, copy) NSArray<NSString *> *categories;
@property (nonatomic, copy) NSString *selectedCategory;
@end

@implementation KDUSettingsController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"K-Douyin Ultra";
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.contentInset = UIEdgeInsetsMake(6, 0, 18, 0);
    self.tableView.sectionHeaderTopPadding = 8.0;
    self.navigationController.navigationBar.tintColor = UIColor.labelColor;
    if (@available(iOS 13.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = YES;
        UINavigationBarAppearance *appearance = [UINavigationBarAppearance new];
        [appearance configureWithDefaultBackground];
        appearance.backgroundEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
        appearance.backgroundColor = [UIColor.systemBackgroundColor colorWithAlphaComponent:0.72];
        self.navigationController.navigationBar.standardAppearance = appearance;
        self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
        self.navigationController.navigationBar.compactAppearance = appearance;
    }
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
    self.navigationController.navigationBar.prefersLargeTitles = YES;

    self.categories = [[KDUFeatureRegistry shared] categories];
    self.selectedCategory = @"å¨é¨";
    self.visibleFeatures = [[KDUFeatureRegistry shared] featuresMatching:@"" category:self.selectedCategory];

    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.navigationItem.searchController = self.searchController;
    self.definesPresentationContext = YES;

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"å·¥å·"
        style:UIBarButtonItemStylePlain target:self action:@selector(showTools)];
    [self.tableView registerClass:KDUFeatureTableCell.class forCellReuseIdentifier:@"FeatureCell"];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 74;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
}
- (void)refreshVisible {
    self.visibleFeatures = [[KDUFeatureRegistry shared] featuresMatching:self.searchController.searchBar.text ?: @""
        category:self.selectedCategory];
    [self.tableView reloadData];
}
- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    [self refreshVisible];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? 1 : self.visibleFeatures.count;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"åè½åç±»" : @"åè½åè¡¨ Â· æ è®°ä¸ºâå¾å®ç°âçé¡¹ç®å½åä»ä¿å­å¼å³";
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"FeatureCell" forIndexPath:indexPath];
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = indexPath.section == 0 ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
    cell.contentView.layoutMargins = UIEdgeInsetsMake(10, 14, 10, 14);
    if (indexPath.section == 0) {
        cell.textLabel.text = [NSString stringWithFormat:@"åç±»ï¼%@", self.selectedCategory];
        cell.textLabel.textColor = UIColor.labelColor;
        cell.detailTextLabel.text = @"è½»ç¹åæ¢åè½åç±»";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }
    KDUFeature *feature = self.visibleFeatures[indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"%@  Â·  %@", feature.title, feature.implemented ? @"å·²å®ç°" : @"å¾å®ç°"];
    cell.textLabel.textColor = feature.implemented ? UIColor.labelColor : UIColor.secondaryLabelColor;
    cell.detailTextLabel.text = feature.detail;
    UISwitch *toggle = [UISwitch new];
    toggle.on = [[KDUConfigManager shared] boolForKey:feature.configKey fallback:feature.defaultEnabled];
    toggle.accessibilityLabel = feature.title;
    toggle.tag = indexPath.row;
    [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section != 0) return;
    if (self.categories.count == 0) return;
    NSUInteger current = [self.categories indexOfObject:self.selectedCategory];
    NSUInteger next = (current == NSNotFound ? 0 : (current + 1) % self.categories.count);
    self.selectedCategory = self.categories[next];
    [self refreshVisible];
}
- (void)toggleChanged:(UISwitch *)sender {
    if (sender.tag < 0 || sender.tag >= self.visibleFeatures.count) return;
    KDUFeature *feature = self.visibleFeatures[sender.tag];
    [[KDUConfigManager shared] setBool:sender.isOn forKey:feature.configKey];
}
- (void)showTools {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"K-Douyin Ultra å·¥å·"
        message:@"éæ©å¯¼åºå½åéç½®ãæ¥çè¯æ­æéç½®è®¾ç½®ã" preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:@"å¯¼åºéç½® JSON" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) {
        NSData *data = [[KDUConfigManager shared] exportFeatureConfigJSON];
        if (!data) return;
        NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"K-Douyin-Ultra-config.json"];
        if (![data writeToFile:path atomically:YES]) return;
        UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:path]] applicationActivities:nil];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            share.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
        }
        [self presentViewController:share animated:YES completion:nil];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"ç¯å¢è¯æ­" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) {
        NSDictionary *d = [[KDUCompatibility shared] diagnostics];
        NSString *message = [NSString stringWithFormat:@"Bundle: %@\nApp: %@ (%@)\niOS: %@\nç¶æ: %@",
            d[@"bundleIdentifier"], d[@"appVersion"], d[@"appBuild"], d[@"systemVersion"], d[@"status"]];
        UIAlertController *diag = [UIAlertController alertControllerWithTitle:@"ç¯å¢è¯æ­" message:message preferredStyle:UIAlertControllerStyleAlert];
        [diag addAction:[UIAlertAction actionWithTitle:@"å³é­" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:diag animated:YES completion:nil];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"éç½®å¨é¨å¼å³" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *a) {
        [[KDUConfigManager shared] resetToDefaults];
        [self refreshVisible];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"åæ¶" style:UIAlertActionStyleCancel handler:nil]];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
    }
    [self presentViewController:alert animated:YES completion:nil];
}
@end
