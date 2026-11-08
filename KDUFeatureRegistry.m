
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
                @"detail": @"界面元素控制待实现，不修改视频文件。",
                @"category": @"视频",
                @"implemented": @NO
            },
            @{
                @"id": @"download.enabled",
                @"title": @"视频保存模块",
                @"detail": @"下载流程待实现。",
                @"category": @"下载",
                @"implemented": @NO
            },
            @{
                @"id": @"interface.liquidGlass",
                @"title": @"液态玻璃主题",
                @"detail": @"控制插件设置页的玻璃模糊、透明卡片、边框和阴影。",
                @"category": @"界面",
                @"implemented": @YES
            },

            // 保留原有配置键，兼容此前保存的设置。
            @{
                @"id": @"interface.hideShopEntry",
                @"title": @"顶部导航标签",
                @"detail": @"计划支持隐藏非推荐标签并保留推荐。首页视图定位待验证。",
                @"category": @"首页元素",
                @"implemented": @NO
            },
            @{
                @"id": @"interface.hideHomeSearch",
                @"title": @"隐藏首页搜索入口",
                @"detail": @"独立隐藏首页右上角搜索入口；控件定位待验证。",
                @"category": @"首页元素",
                @"implemented": @NO
            },
            @{
                @"id": @"interface.hideHomeBottomBar",
                @"title": @"隐藏底部导航",
                @"detail": @"独立隐藏首页底部导航栏；页面识别与恢复逻辑待验证。",
                @"category": @"首页元素",
                @"implemented": @NO
            },
            @{
                @"id": @"interface.hideAuthorInfo",
                @"title": @"隐藏作者信息与文案",
                @"detail": @"计划控制作者名称、视频描述和话题标签；控件定位待验证。",
                @"category": @"首页元素",
                @"implemented": @NO
            },
            @{
                @"id": @"interface.hideMusicCollection",
                @"title": @"隐藏音乐与合集入口",
                @"detail": @"计划控制音乐信息、拍同款及合集入口；控件定位待验证。",
                @"category": @"首页元素",
                @"implemented": @NO
            },
            @{
                @"id": @"interface.hideVideoExtras",
                @"title": @"隐藏视频附加入口",
                @"detail": @"计划控制全屏观看及其他视频悬浮入口；控件定位待验证。",
                @"category": @"首页元素",
                @"implemented": @NO
            },
            @{
                @"id": @"interface.hideInteractionButtons",
                @"title": @"隐藏互动按钮",
                @"detail": @"计划控制点赞、评论、收藏和分享按钮；各按钮识别待验证。",
                @"category": @"首页元素",
                @"implemented": @NO
            },
            @{
                @"id": @"interface.hideAuthorAvatar",
                @"title": @"隐藏作者头像",
                @"detail": @"计划控制视频侧边作者头像及底部音乐头像；控件定位待验证。",
                @"category": @"首页元素",
                @"implemented": @NO
            },
            @{
                @"id": @"interface.hideHomeMenu",
                @"title": @"隐藏首页菜单按钮",
                @"detail": @"独立隐藏首页左上角菜单入口；控件定位待验证。",
                @"category": @"首页元素",
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
