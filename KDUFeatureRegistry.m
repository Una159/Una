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
          @{@"id":@"video.hideWatermarkButton",@"title":@"隐藏水印按钮",@"detail":@"尚未接入抖音页面节点；当前不隐藏按钮。",@"category":@"视频",@"implemented":@NO},
          @{@"id":@"download.enabled",@"title":@"视频保存模块",@"detail":@"尚未接入视频下载流程；当前不保存媒体文件。",@"category":@"下载",@"implemented":@NO},
          @{@"id":@"interface.liquidGlass",@"title":@"液态玻璃主题",@"detail":@"设置页已有系统模糊材质；此开关尚未控制抖音页面主题。",@"category":@"界面",@"implemented":@NO},
          @{@"id":@"interface.hideShopEntry",@"title":@"隐藏商城入口",@"detail":@"尚未接入经过版本验证的商城入口识别逻辑。",@"category":@"界面",@"implemented":@NO},
          @{@"id":@"privacy.reduceTrackingUI",@"title":@"减少干扰界面",@"detail":@"当前不拦截网络请求，也不改变隐私或数据上报行为。",@"category":@"隐私",@"implemented":@NO},
          @{@"id":@"comments.localAudioPicker",@"title":@"评论本地音频选择",@"detail":@"尚未接入本地音频选择和评论发送流程。",@"category":@"评论",@"implemented":@NO},
          @{@"id":@"messages.quickReply",@"title":@"私信快捷回复",@"detail":@"尚未接入私信界面或快捷回复执行逻辑。",@"category":@"私信",@"implemented":@NO},
          @{@"id":@"live.compactControls",@"title":@"直播紧凑控件",@"detail":@"尚未接入直播页面控件或版本适配逻辑。",@"category":@"直播",@"implemented":@NO}
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
- (NSArray<NSString *> *)categories {
    NSMutableOrderedSet *set = [NSMutableOrderedSet orderedSetWithObject:@"全部"];
    for (KDUFeature *f in [self allFeatures]) [set addObject:f.category];
    return set.array;
}
- (NSArray<KDUFeature *> *)featuresMatching:(NSString *)query category:(NSString *)category {
    NSString *q = [query stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSMutableArray *matches = [NSMutableArray array];
    for (KDUFeature *f in [self allFeatures]) {
        BOOL categoryMatches = !category.length || [category isEqualToString:@"全部"] || [f.category isEqualToString:category];
        BOOL queryMatches = !q.length ||
    [f.title rangeOfString:q options:NSCaseInsensitiveSearch].location != NSNotFound ||
    [f.detail rangeOfString:q options:NSCaseInsensitiveSearch].location != NSNotFound ||
    [f.category rangeOfString:q options:NSCaseInsensitiveSearch].location != NSNotFound ||
        [f.identifier rangeOfString:q options:NSCaseInsensitiveSearch].location != NSNotFound; 
        if (categoryMatches && queryMatches) [matches addObject:f];
    }
    return matches;
}
@end
