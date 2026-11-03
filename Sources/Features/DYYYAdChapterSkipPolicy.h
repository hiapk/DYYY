#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 长视频广告章节自动跳过。
// 抖音 39.8.0 自带跳过逻辑（AWEDPlayerComponentAdChapter / AWELandscapeAdChapterAutoSkipController），
// 但只跳过服务端在 AWECodeGenChapterDataModel.adChapterAutoSkipIndexArray 中下发的章节，
// 且受 AB 实验 enableAdChapterAutoSkip / enableAdChapterPlugin 控制。

FOUNDATION_EXPORT NSString *const DYYYAutoSkipAdChapterKey;

@interface DYYYAdChapterSkipPolicy : NSObject

+ (BOOL)isEnabled;

// 专用 Toast 接口必须仍是 void(double, double)，避免版本变化时错误注册 Hook。
+ (BOOL)supportsSkipToastForClass:(nullable Class)cls;

// 宿主 setModel: 要求自动跳过序号是 adChapterIndexArray 的有序子序列，
// 因此开启时直接返回全部广告章节序号；无广告章节或关闭时保持原值。
+ (nullable NSArray *)autoSkipIndexesWithOriginal:(nullable NSArray *)original
                                     allAdIndexes:(nullable NSArray *)allAdIndexes
                                          enabled:(BOOL)enabled;

@end

NS_ASSUME_NONNULL_END
