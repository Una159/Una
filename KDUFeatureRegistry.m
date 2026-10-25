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
    dispatch_once(&onceToken, ^{ instance = [KDUFeatureRegistry new]; });
    return instance;
}

- (void)registerBuiltInFeatures {
    @synchronized (self) {
        if (_registered) return;
        _registered = YES;
        _features = [NSMutableArray array];
        NSArray<NSDictionary *> *items = @[
          @{@"id":@"video.hideWatermarkButton",@"title":@"隐藏水印按钮",@"detail":@"界面元素占位开关；不修改视频文件本身。",@"category":@"视频",@"implemented":@NO},
          @{@"id":@"download.enabled",@"title":@"下载模块",@"detail":@"下载功能模块占位，尚未实现下载流程。",@"category":@"下载",@"implemented":@NO},
          @{@"id":@"interface.liquidGlass",@"title":@"液态玻璃界面",@"detail":@"主题模块占位，需逐个界面接入。",@"category":@"界面",@"implemented":@NO},
          @{@"id":@"interface.hideShopEntry",@"title":@"隐藏商城入口",@"detail":@"需针对当前抖音版本定位实际界面节点。",@"category":@"界面",@"implemented":@NO},
          @{@"id":@"privacy.reduceTrackingUI",@"title":@"减少干扰界面",@"detail":@"仅为设置占位；不会拦截网络请求。",@"category":@"隐私",@"implemented":@NO},
          @{@"id":@"comments.localAudioPicker",@"title":@"评论本地音频选择",@"detail":@"本地音频选择与发送流程尚未接入。",@"category":@"评论",@"implemented":@NO},
          @{@"id":@"messages.quickReply",@"title":@"快捷回复",@"detail":@"快捷回复模块占位。",@"category":@"私信",@"implemented":@NO},
          @{@"id":@"live.compactControls",@"title":@"直播紧凑控件",@"detail":@"需按实际直播页面版本适配。",@"category":@"直播",@"implemented":@NO}
        ];
        for (NSDictionary *item in items) {
            KDUFeature *f = [KDUFeature new];
            f.identifier = item[@"id"];
            f.configKey = item[@"id"];
            f.title = item[@"title"];
            f.detail = item[@"detail"];
            f.category = item[@"category"];
            f.defaultEnabled = NO;
            f.implemented = [item[@"implemented"] boolValue];
            [_features addObject:f];
        }
        [[KDUConfigManager shared] loadDefaultsIfNeeded];
    }
}

- (NSArray<KDUFeature *> *)allFeatures {
    [self registerBuiltInFeatures];
    @synchronized (self) { return [_features copy] ?: @[]; }
}

- (NSArray<KDUFeature *> *)featuresMatching:(NSString *)query {
    NSArray *all = [self allFeatures];
    NSString *q = [query stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (q.length == 0) return all;
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(KDUFeature *f, NSDictionary *bindings) {
        return [f.title.localizedCaseInsensitiveContainsString:q] ||
               [f.detail.localizedCaseInsensitiveContainsString:q] ||
               [f.category.localizedCaseInsensitiveContainsString:q] ||
               [f.identifier.localizedCaseInsensitiveContainsString:q];
    }];
    return [all filteredArrayUsingPredicate:predicate];
}
@end
