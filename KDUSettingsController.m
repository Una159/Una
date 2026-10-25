#import "KDUSettingsController.h"
#import "../Core/KDUFeatureRegistry.h"
#import "../Core/KDUConfigManager.h"
#import "../Core/KDUCompatibility.h"

@interface KDUSettingsController () <UISearchResultsUpdating>
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, copy) NSArray<KDUFeature *> *visibleFeatures;
@end

@implementation KDUSettingsController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"K-Douyin Ultra";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
    self.navigationController.navigationBar.prefersLargeTitles = YES;

    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.navigationItem.searchController = self.searchController;
    self.definesPresentationContext = YES;

    self.visibleFeatures = [[KDUFeatureRegistry shared] allFeatures];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"诊断"
        style:UIBarButtonItemStylePlain target:self action:@selector(showDiagnostics)];
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"FeatureCell"];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    self.visibleFeatures = [[KDUFeatureRegistry shared] featuresMatching:searchController.searchBar.text ?: @""];
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.visibleFeatures.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"FeatureCell" forIndexPath:indexPath];
    KDUFeature *feature = self.visibleFeatures[indexPath.row];
    cell.textLabel.text = feature.title;
    cell.textLabel.numberOfLines = 1;
    cell.detailTextLabel.text = nil;
    cell.accessoryView = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    UISwitch *toggle = [UISwitch new];
    toggle.on = [[KDUConfigManager shared] boolForKey:feature.configKey fallback:feature.defaultEnabled];
    toggle.accessibilityLabel = feature.title;
    toggle.tag = indexPath.row;
    [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle;

    cell.textLabel.text = [NSString stringWithFormat:@"%@  ·  %@", feature.title, feature.implemented ? @"已实现" : @"待实现"];
    cell.textLabel.textColor = feature.implemented ? UIColor.labelColor : UIColor.secondaryLabelColor;
    cell.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    return cell;
}

- (void)toggleChanged:(UISwitch *)sender {
    if (sender.tag < 0 || sender.tag >= self.visibleFeatures.count) return;
    KDUFeature *feature = self.visibleFeatures[sender.tag];
    [[KDUConfigManager shared] setBool:sender.isOn forKey:feature.configKey];
    // Placeholder features intentionally only persist settings until their implementation is added.
}

- (void)showDiagnostics {
    NSDictionary *d = [[KDUCompatibility shared] diagnostics];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"环境诊断"
        message:[NSString stringWithFormat:@"Bundle: %@\nApp: %@ (%@)\niOS: %@\n状态: %@",
                 d[@"bundleIdentifier"], d[@"appVersion"], d[@"appBuild"], d[@"systemVersion"], d[@"status"]]
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"重置配置" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *a) {
        [[KDUConfigManager shared] resetToDefaults];
        [self.tableView reloadData];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end
