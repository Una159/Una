#import "KDUSettingsController.h"
#import "KDUFeatureRegistry.h"
#import "KDUConfigManager.h"
#import "KDUCompatibility.h"

@interface KDUFeatureTableCell : UITableViewCell
@end

@implementation KDUFeatureTableCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:UITableViewCellStyleSubtitle
                reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.contentView.backgroundColor =
            [UIColor.secondarySystemGroupedBackgroundColor
                colorWithAlphaComponent:0.62];

        self.contentView.layer.cornerRadius = 18.0;
        self.contentView.layer.cornerCurve = kCACornerCurveContinuous;
        self.contentView.layer.borderWidth = 0.7;
        self.contentView.layer.borderColor =
            [UIColor.separatorColor colorWithAlphaComponent:0.32].CGColor;
        self.contentView.layer.masksToBounds = YES;

        self.textLabel.font =
            [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];

        self.detailTextLabel.font =
            [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];

        self.detailTextLabel.textColor = UIColor.secondaryLabelColor;
        self.detailTextLabel.numberOfLines = 2;
    }
    return self;
}

@end

@interface KDUSettingsController () <
    UISearchResultsUpdating,
    UIImagePickerControllerDelegate,
    UINavigationControllerDelegate
>

@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, copy) NSArray<KDUFeature *> *visibleFeatures;
@property (nonatomic, copy) NSArray<NSString *> *categories;
@property (nonatomic, copy) NSString *selectedCategory;
@property (nonatomic, strong) UIImageView *profileAvatarView;
@property (nonatomic, strong) UILabel *profileNoteLabel;

@end

@implementation KDUSettingsController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"K-Douyin Ultra";
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.contentInset = UIEdgeInsetsMake(2, 0, 18, 0);

    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 8.0;
    }

    self.navigationController.navigationBar.tintColor = UIColor.labelColor;

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
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchBar.placeholder = @"搜索全部功能";

    if (@available(iOS 13.0, *)) {
        self.searchController.searchBar.searchBarStyle =
            UISearchBarStyleMinimal;
    }

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
    self.tableView.estimatedRowHeight = 74.0;
    self.tableView.keyboardDismissMode =
        UIScrollViewKeyboardDismissModeOnDrag;

    [self installProfileHeader];
}

#pragma mark - Profile Header

- (void)installProfileHeader {
    CGFloat width = CGRectGetWidth(self.tableView.bounds);

    UIView *header =
        [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 116)];

    header.backgroundColor = UIColor.clearColor;

    UIView *glassPanel =
        [[UIView alloc] initWithFrame:
            CGRectMake(16, 10, width - 32, 96)];

    glassPanel.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    glassPanel.backgroundColor =
        [UIColor.secondarySystemGroupedBackgroundColor
            colorWithAlphaComponent:0.58];

    glassPanel.layer.cornerRadius = 24.0;
    glassPanel.layer.cornerCurve = kCACornerCurveContinuous;
    glassPanel.layer.borderWidth = 0.8;

    glassPanel.layer.borderColor =
        [UIColor.separatorColor
            colorWithAlphaComponent:0.35].CGColor;

    glassPanel.layer.shadowColor = UIColor.blackColor.CGColor;
    glassPanel.layer.shadowOpacity = 0.08;
    glassPanel.layer.shadowRadius = 12.0;
    glassPanel.layer.shadowOffset = CGSizeMake(0, 4);

    [header addSubview:glassPanel];

    UIImageView *avatar =
        [[UIImageView alloc]
            initWithFrame:CGRectMake(30, 28, 58, 58)];

    avatar.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
    avatar.image = [UIImage imageNamed:@"KDUProfileAvatar"];

    if (!avatar.image) {
        avatar.image =
            [UIImage systemImageNamed:@"person.crop.circle.fill"];
    }

    NSData *savedAvatar =
        [[NSUserDefaults standardUserDefaults]
            dataForKey:@"KDUProfileAvatarData"];

    UIImage *customAvatar =
        savedAvatar ? [UIImage imageWithData:savedAvatar] : nil;

    if (customAvatar) {
        avatar.image = customAvatar;
    }

    avatar.tintColor = UIColor.secondaryLabelColor;
    avatar.contentMode = UIViewContentModeScaleAspectFill;
    avatar.clipsToBounds = YES;
    avatar.layer.cornerRadius = 29.0;
    avatar.layer.borderWidth = 1.0;

    avatar.layer.borderColor =
        [UIColor.separatorColor
            colorWithAlphaComponent:0.5].CGColor;

    avatar.userInteractionEnabled = YES;

    [avatar addGestureRecognizer:
        [[UITapGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(changeProfileAvatar)]];

    self.profileAvatarView = avatar;
    [glassPanel addSubview:avatar];

    UILabel *name =
        [[UILabel alloc]
            initWithFrame:CGRectMake(102, 24, width - 170, 26)];

    name.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    name.text = @"K-Douyin Ultra";
    name.textColor = UIColor.labelColor;
    name.font = [UIFont systemFontOfSize:18
                                  weight:UIFontWeightBold];

    [glassPanel addSubview:name];

    UILabel *note =
        [[UILabel alloc]
            initWithFrame:CGRectMake(102, 52, width - 170, 28)];

    note.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    note.text =
        [[NSUserDefaults standardUserDefaults]
            stringForKey:@"KDUProfileNote"]
        ?: @"轻点这里，添加你的自定义备注";

    note.textColor = UIColor.secondaryLabelColor;
    note.font = [UIFont systemFontOfSize:13
                                  weight:UIFontWeightRegular];

    note.numberOfLines = 1;
    note.lineBreakMode = NSLineBreakByTruncatingTail;
    note.userInteractionEnabled = YES;

    [note addGestureRecognizer:
        [[UITapGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(editProfileNote)]];

    self.profileNoteLabel = note;
    [glassPanel addSubview:note];

    self.tableView.tableHeaderView = header;
}

- (void)changeProfileAvatar {
    if (![UIImagePickerController
            isSourceTypeAvailable:
                UIImagePickerControllerSourceTypePhotoLibrary]) {
        return;
    }

    UIImagePickerController *picker =
        [UIImagePickerController new];

    picker.sourceType =
        UIImagePickerControllerSourceTypePhotoLibrary;

    picker.delegate = self;

    [self presentViewController:picker
                       animated:YES
                     completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker
 didFinishPickingMediaWithInfo:
    (NSDictionary<UIImagePickerControllerInfoKey, id> *)info {

    UIImage *image =
        info[UIImagePickerControllerOriginalImage];

    if (image) {
        self.profileAvatarView.image = image;

        NSData *data =
            UIImageJPEGRepresentation(image, 0.82);

        if (data) {
            [[NSUserDefaults standardUserDefaults]
                setObject:data
                   forKey:@"KDUProfileAvatarData"];
        }
    }

    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:
    (UIImagePickerController *)picker {

    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)editProfileNote {
    UIAlertController *alert =
        [UIAlertController
            alertControllerWithTitle:@"自定义备注"
                             message:@"输入显示在头像下方的文字。"
                      preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"例如：我的专属工具箱";
        field.text = self.profileNoteLabel.text;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];

    [alert addAction:
        [UIAlertAction actionWithTitle:@"取消"
                                 style:UIAlertActionStyleCancel
                               handler:nil]];

    [alert addAction:
        [UIAlertAction actionWithTitle:@"保存"
                                 style:UIAlertActionStyleDefault
                               handler:^(__unused UIAlertAction *action) {

        NSString *value =
            [alert.textFields.firstObject.text
                stringByTrimmingCharactersInSet:
                    NSCharacterSet.whitespaceAndNewlineCharacterSet];

        if (value.length == 0) {
            value = @"轻点这里，添加你的自定义备注";
        }

        self.profileNoteLabel.text = value;

        [[NSUserDefaults standardUserDefaults]
            setObject:value
               forKey:@"KDUProfileNote"];
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Search

- (void)refreshVisible {
    self.visibleFeatures =
        [[KDUFeatureRegistry shared]
            featuresMatching:
                self.searchController.searchBar.text ?: @""
                    category:self.selectedCategory];

    [self.tableView reloadData];
}

- (void)updateSearchResultsForSearchController:
    (UISearchController *)searchController {

    [self refreshVisible];
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:
    (UITableView *)tableView {

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
        : @"功能列表 · 标记为“待实现”的项目当前仅保存开关";
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    UITableViewCell *cell =
        [tableView dequeueReusableCellWithIdentifier:@"FeatureCell"
                                        forIndexPath:indexPath];

    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;

    cell.selectionStyle =
        indexPath.section == 0
        ? UITableViewCellSelectionStyleDefault
        : UITableViewCellSelectionStyleNone;

    cell.contentView.layoutMargins =
        UIEdgeInsetsMake(12, 16, 12, 16);

    if (indexPath.section == 0) {
        cell.textLabel.text =
            [NSString stringWithFormat:
                @"分类：%@", self.selectedCategory];

        cell.textLabel.textColor = UIColor.labelColor;
        cell.detailTextLabel.text = @"轻点切换功能分类";
        cell.accessoryType =
            UITableViewCellAccessoryDisclosureIndicator;

        return cell;
    }

    KDUFeature *feature = self.visibleFeatures[indexPath.row];

    cell.textLabel.text =
        [NSString stringWithFormat:@"%@ · %@",
            feature.title,
            feature.implemented ? @"已实现" : @"待实现"];

    cell.textLabel.textColor = UIColor.labelColor;
    cell.detailTextLabel.text = feature.detail;

    UISwitch *toggle = [UISwitch new];

    toggle.on =
        [[KDUConfigManager shared]
            boolForKey:feature.configKey
              fallback:feature.defaultEnabled];

    toggle.onTintColor = UIColor.systemBlueColor;
    toggle.enabled = feature.implemented;
    toggle.alpha = feature.implemented ? 1.0 : 0.62;
    toggle.accessibilityLabel = feature.title;
    toggle.tag = indexPath.row;

    [toggle addTarget:self
               action:@selector(toggleChanged:)
     forControlEvents:UIControlEventValueChanged];

    cell.accessoryView = toggle;

    return cell;
}

- (void)tableView:(UITableView *)tableView
    willDisplayCell:(UITableViewCell *)cell
 forRowAtIndexPath:(NSIndexPath *)indexPath {

    cell.backgroundColor = UIColor.clearColor;

    cell.contentView.layer.shadowColor =
        UIColor.blackColor.CGColor;

    cell.contentView.layer.shadowOpacity = 0.035;
    cell.contentView.layer.shadowRadius = 5.0;
    cell.contentView.layer.shadowOffset = CGSizeMake(0, 2);
}

- (CGFloat)tableView:(UITableView *)tableView
 heightForRowAtIndexPath:(NSIndexPath *)indexPath {

    return indexPath.section == 0
        ? 82.0
        : UITableViewAutomaticDimension;
}

- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    if (indexPath.section != 0 || self.categories.count == 0) {
        return;
    }

    NSUInteger current =
        [self.categories indexOfObject:self.selectedCategory];

    NSUInteger next =
        (current == NSNotFound
            ? 0
            : (current + 1) % self.categories.count);

    self.selectedCategory = self.categories[next];

    [self refreshVisible];

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - Feature Switches

- (void)toggleChanged:(UISwitch *)sender {
    if (sender.tag < 0 ||
        sender.tag >= self.visibleFeatures.count) {
        return;
    }

    KDUFeature *feature = self.visibleFeatures[sender.tag];

    [[KDUConfigManager shared]
        setBool:sender.isOn
         forKey:feature.configKey];
}

#pragma mark - Tools

- (void)showTools {
    UIAlertController *alert =
        [UIAlertController
            alertControllerWithTitle:@"K-Douyin Ultra 工具"
                             message:@"请选择要执行的操作。"
                      preferredStyle:UIAlertControllerStyleActionSheet];

    [alert addAction:
        [UIAlertAction actionWithTitle:@"导出配置 JSON"
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
        [UIAlertAction actionWithTitle:@"环境诊断"
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
            [UIAlertAction actionWithTitle:@"关闭"
                                     style:UIAlertActionStyleCancel
                                   handler:nil]];

        [self presentViewController:diag
                           animated:YES
                         completion:nil];
    }]];

    [alert addAction:
        [UIAlertAction actionWithTitle:@"重置全部开关"
                                 style:UIAlertActionStyleDestructive
                               handler:^(__unused UIAlertAction *action) {

        [[KDUConfigManager shared] resetToDefaults];
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

    [self presentViewController:alert
                       animated:YES
                     completion:nil];
}

@end
