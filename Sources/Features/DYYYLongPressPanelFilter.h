#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 视频长按面板的原生项目过滤：文本规则（DYYYHidePanelItems）与固定开关共同生效。
// 固定开关同时按宿主类名与文案匹配，避免文案灰度或本地化变化导致失效。
@interface DYYYLongPressPanelFilter : NSObject

// groups 为宿主 dataArray 中的分组；groupClass 为 AWELongPressPanelViewGroupModel。
+ (NSArray *)filteredGroups:(NSArray *)groups groupClass:(nullable Class)groupClass;

// 以下方法不依赖宿主类，便于在 macOS 上单独测试。
+ (NSSet<NSString *> *)hideTextRulesFromString:(nullable NSString *)string;
+ (BOOL)shouldHideItemWithClassName:(nullable NSString *)className
                        describeText:(nullable NSString *)text
                           textRules:(NSSet<NSString *> *)textRules
                       hideRecommend:(BOOL)hideRecommend
                      hideShareDaily:(BOOL)hideShareDaily
                         hideDislike:(BOOL)hideDislike;

@end

NS_ASSUME_NONNULL_END
