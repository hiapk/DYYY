#import <Foundation/Foundation.h>
#import "DYYYLongPressPanelFilter.h"

// 模拟宿主分组与项目；类名与抖音 39.8.0 一致，用于验证类名匹配。
@interface DYYYTestGroup : NSObject
@property(nonatomic) unsigned long long groupType;
@property(nonatomic, strong) NSArray *groupArr;
@property(nonatomic) BOOL hasMore;
@property(nonatomic) BOOL isModern;
@end
@implementation DYYYTestGroup
@end

@interface DYYYTestItem : NSObject
@property(nonatomic, copy) NSString *describeString;
@end
@implementation DYYYTestItem
@end
@interface AWELongPressPanelFamiliarRecommendViewModel : DYYYTestItem
@end
@implementation AWELongPressPanelFamiliarRecommendViewModel
@end
@interface AWELongPressPanelDisLikeViewModel : DYYYTestItem
@end
@implementation AWELongPressPanelDisLikeViewModel
@end

#define CHECK(...) NSCAssert((__VA_ARGS__), @"测试失败：%s", #__VA_ARGS__)

static DYYYTestItem *Item(Class cls, NSString *text) {
    DYYYTestItem *item = [cls new];
    item.describeString = text;
    return item;
}

static NSArray<NSString *> *Texts(NSArray *groups) {
    NSMutableArray *texts = [NSMutableArray array];
    for (DYYYTestGroup *group in groups) {
        if (![group isKindOfClass:DYYYTestGroup.class]) continue;
        for (DYYYTestItem *item in group.groupArr) [texts addObject:item.describeString ?: @"-"];
    }
    return texts;
}

static BOOL Hide(NSString *className, NSString *text, NSString *rules, BOOL recommend, BOOL daily, BOOL dislike) {
    return [DYYYLongPressPanelFilter shouldHideItemWithClassName:className
                                                    describeText:text
                                                       textRules:[DYYYLongPressPanelFilter hideTextRulesFromString:rules]
                                                   hideRecommend:recommend
                                                  hideShareDaily:daily
                                                     hideDislike:dislike];
}

int main(void) {
    @autoreleasepool {
        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        NSArray *keys = @[ @"DYYYHidePanelItems", @"DYYYHidePanelRecommend", @"DYYYHidePanelShareDaily", @"DYYYHidePanelDislike" ];
        for (NSString *key in keys) [defaults removeObjectForKey:key];

        // 文本规则：中英文逗号、空白与大小写。
        NSSet *rules = [DYYYLongPressPanelFilter hideTextRulesFromString:@" 举报，投屏 ,, TV "];
        CHECK([rules isEqualToSet:([NSSet setWithArray:@[ @"举报", @"投屏", @"tv" ]])]);
        CHECK([DYYYLongPressPanelFilter hideTextRulesFromString:nil].count == 0);

        // 固定开关：类名或文案任一命中即隐藏；未开启时不影响。
        CHECK(Hide(@"AWELongPressPanelFamiliarRecommendViewModel", nil, nil, YES, NO, NO));
        CHECK(Hide(@"Other", @" 已推荐 ", nil, YES, NO, NO));
        CHECK(!Hide(@"AWELongPressPanelFamiliarRecommendViewModel", @"推荐", nil, NO, NO, NO));
        CHECK(!Hide(@"Other", @"推荐给朋友", nil, YES, NO, NO));
        CHECK(Hide(@"AWELongPressPanelInTodayPublishViewModel", @"-", nil, NO, YES, NO));
        CHECK(Hide(@"Other", @"转发到日常", nil, NO, YES, NO));
        CHECK(Hide(@"AWELongPressPanelDisLikeViewModel", @"", nil, NO, NO, YES));
        CHECK(Hide(@"Other", @"不感兴趣", nil, NO, NO, YES));
        CHECK(!Hide(@"Other", @"举报", nil, YES, YES, YES));
        // 文本规则保持原有精确与部分匹配。
        CHECK(Hide(@"Other", @"举报视频", @"举报", NO, NO, NO));
        CHECK(Hide(@"Other", @"推荐", @"推荐,转发到日常,不感兴趣", NO, NO, NO));

        DYYYTestGroup *interactive = [DYYYTestGroup new];
        interactive.groupType = 11;
        interactive.isModern = YES;
        interactive.groupArr = @[ Item(AWELongPressPanelFamiliarRecommendViewModel.class, @"推荐"), Item(DYYYTestItem.class, @"转发到日常"),
                                  Item(AWELongPressPanelDisLikeViewModel.class, @"不感兴趣") ];
        DYYYTestGroup *list = [DYYYTestGroup new];
        list.groupType = 2;
        list.groupArr = @[ Item(DYYYTestItem.class, @"清屏"), Item(DYYYTestItem.class, @"举报") ];
        NSArray *groups = @[ interactive, list, @"非分组对象" ];

        // 无规则时原样返回。
        CHECK([DYYYLongPressPanelFilter filteredGroups:groups groupClass:DYYYTestGroup.class] == groups);

        // 三项全部隐藏时整组移除，未变化的分组保持原对象，非分组对象保留。
        [defaults setBool:YES forKey:@"DYYYHidePanelRecommend"];
        [defaults setBool:YES forKey:@"DYYYHidePanelShareDaily"];
        [defaults setBool:YES forKey:@"DYYYHidePanelDislike"];
        NSArray *result = [DYYYLongPressPanelFilter filteredGroups:groups groupClass:DYYYTestGroup.class];
        CHECK(result.count == 2 && result[0] == list && [result[1] isEqual:@"非分组对象"]);

        // 部分隐藏时新建分组并保留类型与样式，宿主原分组不被修改。
        [defaults setBool:NO forKey:@"DYYYHidePanelShareDaily"];
        [defaults setObject:@"举报" forKey:@"DYYYHidePanelItems"];
        result = [DYYYLongPressPanelFilter filteredGroups:groups groupClass:DYYYTestGroup.class];
        CHECK([Texts(result) isEqualToArray:(@[ @"转发到日常", @"清屏" ])]);
        DYYYTestGroup *rebuilt = result[0];
        CHECK(rebuilt != interactive && rebuilt.groupType == 11 && rebuilt.isModern);
        CHECK(interactive.groupArr.count == 3 && list.groupArr.count == 2);

        for (NSString *key in keys) [defaults removeObjectForKey:key];
        NSLog(@"长按面板过滤测试通过");
    }
    return 0;
}
