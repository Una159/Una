
#import "KDUFeatureRegistry.h"
#import "KDUConfigManager.h"

@implementation KDUFeature
@end

@implementation KDUFeatureRegistry {
    NSMutableArray<KDUFeature *> *_features;
    BOOL _registered;
}

+ (instancetype)shared {
    static KDUFeatureRegistry *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [KDUFeatureRegistry new];
    });
    return instance;
}

- (void)registerBuiltInFeatures {
    @synchronized (self) {
        if (_registered) return;

        _registered = YES;
        _features = [NSMutableArray array];

        NSArray<NSDictionary *> *items = @[
            @{
                @"id": @"video.hideWatermarkButton",
                @"title": @"隐藏水印按钮",
                @"detail": @"界面元素开关占位，不会修改视频文件。",
                @"category": @"视频",
                @"implemented": @NO
            },
            @{
                @"id": @"download.enabled",
                @"title": @"视频保存模块",
                @"detail": @"下载流程待实现；当前只保存设置。",
                @"category": @"下载",
                @"implemented": @NO
            },
            @{
                @"id": @"interface.liquidGlass",
                @"title": @"液态玻璃主题",
                @"detail": @"控制设置页的玻璃模糊、透明卡片、边框和阴影效果。",
                @"category": @"界面",
                @"implemented": @YES
            },
            @{
                @"id": @"interface.hideShopEntry",
                @"title": @"仅保留推荐",
                @"detail": @"隐藏首页顶部除推荐以外的导航标签，保留推荐入口。需要实机验证。",
                @"category": @"界面",
                @"implemented": @NO
            },
            @{
                @"id": @"interface.hideHomeSearch",
                @"title": @"隐藏首页搜索入口",
                @"detail": @"独立控制首页顶部搜索入口的显示，需要实机验证。",
                @"category": @"界面",
                @"implemented": @NO
            },
            @{
                @"id": @"privacy.reduceTrackingUI",
                @"title": @"减少干扰界面",
                @"detail": @"当前为配置占位，不会拦截网络请求。",
                @"category": @"隐私",
                @"implemented": @NO
            },
            @{
                @"id": @"comments.localAudioPicker",
                @"title": @"评论本地音频选择",
                @"detail": @"本地音频选择与发送流程待实现。",
                @"category": @"评论",
                @"implemented": @NO
            },
            @{
                @"id": @"messages.quickReply",
                @"title": @"私信快捷回复",
                @"detail": @"快捷回复流程待实现。",
                @"category": @"私信",
                @"implemented": @NO
            },
            @{
                @"id": @"live.compactControls",
                @"title": @"直播紧凑控件",
                @"detail": @"直播页面适配待实现。",
                @"category": @"直播",
                @"implemented": @NO
            }
        ];

        for (NSDictionary *item in items) {
            KDUFeature *feature = [KDUFeature new];

            feature.identifier = item[@"id"];
            // 保留原有配置键，兼容已保存的设置。
            feature.configKey = item[@"id"];
            feature.title = item[@"title"];
            feature.detail = item[@"detail"];
            feature.category = item[@"category"];
            feature.defaultEnabled = NO;
            feature.implemented = [item[@"implemented"] boolValue];

            [_features addObject:feature];
        }

        [[KDUConfigManager shared] loadDefaultsIfNeeded];
    }
}

- (NSArray<KDUFeature *> *)allFeatures {
    [self registerBuiltInFeatures];

    @synchronized (self) {
        return [_features copy] ?: @[];
    }
}

- (NSArray<NSString *> *)categories {
    NSMutableOrderedSet *set =
        [NSMutableOrderedSet orderedSetWithObject:@"全部"];

    for (KDUFeature *feature in [self allFeatures]) {
        if (feature.category.length > 0) {
            [set addObject:feature.category];
        }
    }

    return set.array;
}

- (NSArray<KDUFeature *> *)featuresMatching:(NSString *)query
                                   category:(NSString *)category {
    NSString *keyword =
        [(query ?: @"") stringByTrimmingCharactersInSet:
            NSCharacterSet.whitespaceAndNewlineCharacterSet];

    NSMutableArray<KDUFeature *> *matches = [NSMutableArray array];

    for (KDUFeature *feature in [self allFeatures]) {
        BOOL categoryMatches =
            !category.length ||
            [category isEqualToString:@"全部"] ||
            [feature.category isEqualToString:category];

        BOOL queryMatches =
            !keyword.length ||
            [feature.title rangeOfString:keyword
                                 options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [feature.detail rangeOfString:keyword
                                  options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [feature.category rangeOfString:keyword
                                     options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [feature.identifier rangeOfString:keyword
                                      options:NSCaseInsensitiveSearch].location != NSNotFound;

        if (categoryMatches && queryMatches) {
            [matches addObject:feature];
        }
    }

    return matches;
}

@end
