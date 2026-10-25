#import "KDUConfigManager.h"

static NSString * const KDUDefaultsLoadedKey = @"kdu.defaults.loaded";

@implementation KDUConfigManager

+ (instancetype)shared {
    static KDUConfigManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [KDUConfigManager new]; });
    return instance;
}

- (void)loadDefaultsIfNeeded {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if ([defaults boolForKey:KDUDefaultsLoadedKey]) return;

    NSDictionary *initial = @{
        @"video.hideWatermarkButton": @NO,
        @"download.enabled": @NO,
        @"interface.liquidGlass": @NO,
        @"interface.hideShopEntry": @NO,
        @"privacy.reduceTrackingUI": @NO,
        @"comments.localAudioPicker": @NO,
        @"messages.quickReply": @NO,
        @"live.compactControls": @NO
    };
    [initial enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
        if ([defaults objectForKey:key] == nil) [defaults setObject:value forKey:key];
    }];
    [defaults setBool:YES forKey:KDUDefaultsLoadedKey];
    [defaults synchronize];
}

- (BOOL)boolForKey:(NSString *)key fallback:(BOOL)fallback {
    id value = [NSUserDefaults.standardUserDefaults objectForKey:key];
    return value ? [value boolValue] : fallback;
}

- (void)setBool:(BOOL)value forKey:(NSString *)key {
    [NSUserDefaults.standardUserDefaults setBool:value forKey:key];
}

- (NSDictionary<NSString *,id> *)allValues {
    return NSUserDefaults.standardUserDefaults.dictionaryRepresentation;
}

- (void)resetToDefaults {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSArray *keys = @[
        @"video.hideWatermarkButton", @"download.enabled",
        @"interface.liquidGlass", @"interface.hideShopEntry",
        @"privacy.reduceTrackingUI", @"comments.localAudioPicker",
        @"messages.quickReply", @"live.compactControls"
    ];
    for (NSString *key in keys) [defaults removeObjectForKey:key];
    [defaults removeObjectForKey:KDUDefaultsLoadedKey];
    [self loadDefaultsIfNeeded];
}
@end
