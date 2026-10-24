#import "DYYYLongPressPanelFilter.h"

// 抖音 39.8.0 中各项目由对应工厂类 +longPressPanelViewModel 创建（alloc/init/configVM），实例即为该类。
static NSString *const kDYYYPanelRecommendClass = @"AWELongPressPanelFamiliarRecommendViewModel";
static NSString *const kDYYYPanelTeenRecommendClass = @"AWELongPressPanelTeenRecommendViewModel";
static NSString *const kDYYYPanelDislikeClass = @"AWELongPressPanelDisLikeViewModel";
static NSString *const kDYYYPanelDislikeDispatchClass = @"AWELongPressPanelDislikeDispatchItemViewModel";
static NSString *const kDYYYPanelInTodayPublishClass = @"AWELongPressPanelInTodayPublishViewModel";

static NSUInteger const kDYYYPanelLogLimit = 64;

@implementation DYYYLongPressPanelFilter

#pragma mark - 规则

+ (NSSet<NSString *> *)hideTextRulesFromString:(NSString *)string {
    NSMutableSet<NSString *> *rules = [NSMutableSet set];
    if (![string isKindOfClass:NSString.class] || string.length == 0) return rules;
    // 支持中英文逗号分隔
    NSString *normalized = [string stringByReplacingOccurrencesOfString:@"，" withString:@","];
    for (NSString *item in [normalized componentsSeparatedByString:@","]) {
        NSString *trimmed = [item stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (trimmed.length > 0) [rules addObject:trimmed.lowercaseString];
    }
    return rules;
}

+ (BOOL)text:(NSString *)text matchesRules:(NSSet<NSString *> *)rules {
    if (text.length == 0 || rules.count == 0) return NO;
    if ([rules containsObject:text]) return YES;
    // 部分匹配，兼容“举报”匹配“举报视频”等文案
    for (NSString *rule in rules) {
        if ([text containsString:rule] || [rule containsString:text]) return YES;
    }
    return NO;
}

+ (BOOL)shouldHideItemWithClassName:(NSString *)className
                        describeText:(NSString *)text
                           textRules:(NSSet<NSString *> *)textRules
                       hideRecommend:(BOOL)hideRecommend
                      hideShareDaily:(BOOL)hideShareDaily
                         hideDislike:(BOOL)hideDislike {
    NSString *normalized = [[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString] ?: @"";

    if (hideRecommend) {
        if ([className isEqualToString:kDYYYPanelRecommendClass] || [className isEqualToString:kDYYYPanelTeenRecommendClass]) return YES;
        if ([@[ @"推荐", @"已推荐", @"取消推荐" ] containsObject:normalized]) return YES;
    }
    if (hideShareDaily) {
        if ([className isEqualToString:kDYYYPanelInTodayPublishClass]) return YES;
        if ([normalized containsString:@"日常"]) return YES;
    }
    if (hideDislike) {
        if ([className isEqualToString:kDYYYPanelDislikeClass] || [className isEqualToString:kDYYYPanelDislikeDispatchClass]) return YES;
        if ([normalized containsString:@"不感兴趣"]) return YES;
    }
    return [self text:normalized matchesRules:textRules];
}

#pragma mark - 宿主分组

+ (NSString *)describeTextForItem:(id)item {
    if (![item respondsToSelector:@selector(describeString)]) return nil;
    id text = [item valueForKey:@"describeString"];
    if ([text isKindOfClass:NSAttributedString.class]) return [(NSAttributedString *)text string];
    return [text isKindOfClass:NSString.class] ? text : nil;
}

+ (void)logGroups:(NSArray *)groups {
    // 输出宿主实际的项目类名与文案，便于新版本适配；相同面板结构只记录一次。
    static NSMutableSet<NSString *> *logged;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ logged = [NSMutableSet set]; });
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (id group in groups) {
        if (![group respondsToSelector:@selector(groupArr)]) continue;
        NSMutableArray<NSString *> *items = [NSMutableArray array];
        for (id item in [group valueForKey:@"groupArr"]) {
            [items addObject:[NSString stringWithFormat:@"%@:%@", NSStringFromClass([item class]), [self describeTextForItem:item] ?: @"-"]];
        }
        [parts addObject:[NSString stringWithFormat:@"[type=%@ %@]", [group valueForKey:@"groupType"], [items componentsJoinedByString:@", "]]];
    }
    NSString *signature = [parts componentsJoinedByString:@" "];
    @synchronized(logged) {
        if (logged.count >= kDYYYPanelLogLimit || [logged containsObject:signature]) return;
        [logged addObject:signature];
    }
    NSLog(@"[DYYY] 长按面板原生项目：%@", signature);
}

+ (NSArray *)filteredGroups:(NSArray *)groups groupClass:(Class)groupClass {
    if (![groups isKindOfClass:NSArray.class] || groups.count == 0) return groups;
    [self logGroups:groups];

    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSSet<NSString *> *textRules = [self hideTextRulesFromString:[defaults stringForKey:@"DYYYHidePanelItems"]];
    BOOL hideRecommend = [defaults boolForKey:@"DYYYHidePanelRecommend"];
    BOOL hideShareDaily = [defaults boolForKey:@"DYYYHidePanelShareDaily"];
    BOOL hideDislike = [defaults boolForKey:@"DYYYHidePanelDislike"];
    if (textRules.count == 0 && !hideRecommend && !hideShareDaily && !hideDislike) return groups;

    NSMutableArray *result = [NSMutableArray arrayWithCapacity:groups.count];
    for (id group in groups) {
        if (!groupClass || ![group isKindOfClass:groupClass]) {
            [result addObject:group];
            continue;
        }
        NSArray *items = [group valueForKey:@"groupArr"];
        NSMutableArray *kept = [NSMutableArray arrayWithCapacity:items.count];
        for (id item in items) {
            BOOL hide = [self shouldHideItemWithClassName:NSStringFromClass([item class])
                                             describeText:[self describeTextForItem:item]
                                                textRules:textRules
                                            hideRecommend:hideRecommend
                                           hideShareDaily:hideShareDaily
                                              hideDislike:hideDislike];
            if (!hide) [kept addObject:item];
        }
        if (kept.count == items.count) {
            [result addObject:group];
            continue;
        }
        if (kept.count == 0) continue;
        // 新建分组而不修改宿主对象；setGroupArr: 内部依赖 groupType，需先设置类型。
        // cellHeight 是宿主按项目重新计算的值，不复制。
        id filtered = [[groupClass alloc] init];
        [filtered setValue:[group valueForKey:@"groupType"] forKey:@"groupType"];
        [filtered setValue:[group valueForKey:@"isModern"] forKey:@"isModern"];
        [filtered setValue:[group valueForKey:@"hasMore"] forKey:@"hasMore"];
        [filtered setValue:kept forKey:@"groupArr"];
        [result addObject:filtered];
    }
    return result;
}

@end
