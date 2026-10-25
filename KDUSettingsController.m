#import "KDUSettingsController.h"
#import "KDUFeatureRegistry.h"
#import "KDUConfigManager.h"
#import "KDUCompatibility.h"

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
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
    self.navigationController.navigationBar.prefersLargeTitles = YES;

    self.categories = [[KDUFeatureRegistry shared] categories];
    self.selectedCategory = @"全部";
    self.visibleFeatures = [[KDUFeatureRegistry shared] featuresMatching:@"" category:self.selectedCategory];

    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.navigationItem.searchController = self.searchController;
    self.definesPresentationContext = YES;

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"工具"
        style:UIBarButtonItemStylePlain target:self action:@selector(showTools)];
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"FeatureCell"];
    self.tableView.rowHeight = 62;
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
    return section == 0 ? @"功能分类" : @"功能列表 · 标记为“待实现”的项目当前仅保存开关";
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"FeatureCell" forIndexPath:indexPath];
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    if (indexPath.section == 0) {
        cell.textLabel.text = [NSString stringWithFormat:@"分类：%@（点击切换）", self.selectedCategory];
        cell.textLabel.textColor = UIColor.labelColor;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.detailTextLabel.text = nil;
        return cell;
    }
    KDUFeature *feature = self.visibleFeatures[indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"%@  ·  %@", feature.title, feature.implemented ? @"已实现" : @"待实现"];
    cell.textLabel.textColor = feature.implemented ? UIColor.labelColor : UIColor.secondaryLabelColor;
    cell.textLabel.numberOfLines = 2;
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
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"K-Douyin Ultra 工具"
        message:@"选择导出当前配置、查看诊断或重置设置。" preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:@"导出配置 JSON" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) {
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
    [alert addAction:[UIAlertAction actionWithTitle:@"环境诊断" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) {
        NSDictionary *d = [[KDUCompatibility shared] diagnostics];
        NSString *message = [NSString stringWithFormat:@"Bundle: %@\nApp: %@ (%@)\niOS: %@\n状态: %@",
            d[@"bundleIdentifier"], d[@"appVersion"], d[@"appBuild"], d[@"systemVersion"], d[@"status"]];
        UIAlertController *diag = [UIAlertController alertControllerWithTitle:@"环境诊断" message:message preferredStyle:UIAlertControllerStyleAlert];
        [diag addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:diag animated:YES completion:nil];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"重置全部开关" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *a) {
        [[KDUConfigManager shared] resetToDefaults];
        [self refreshVisible];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
    }
    [self presentViewController:alert animated:YES completion:nil];
}
@end
