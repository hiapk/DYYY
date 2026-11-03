#import "AwemeHeaders.h"
#import "DYYYAdChapterSkipPolicy.h"

// 抖音 39.8.0 长视频广告章节：竖屏 AWEDPlayerComponentAdChapter 与横屏 AWELandscapeAdChapterAutoSkipController
// 在播放进度进入 adChapterAutoSkipIndexArray 中的章节时调用 skipAdChapterWithStartTime:endTime:completion:
// 开启后放开 AB 开关，把全部广告章节交给原生逻辑跳过，并隐藏专用跳过提示；手动拖回广告时原生逻辑不再跳过。

%group DYYYAdChapterSkipData
%hook AWECodeGenChapterDataModel
- (NSArray *)adChapterAutoSkipIndexArray {
    NSArray *original = %orig;
    if (![DYYYAdChapterSkipPolicy isEnabled]) return original;
    return [DYYYAdChapterSkipPolicy autoSkipIndexesWithOriginal:original allAdIndexes:self.adChapterIndexArray enabled:YES];
}
%end
%end

%group DYYYAdChapterSkipFeedAB
%hook AWEFeedABTestServiceObjc
+ (BOOL)enableAdChapterAutoSkip {
    return [DYYYAdChapterSkipPolicy isEnabled] ? YES : %orig;
}
%end
%end

%group DYYYAdChapterSkipContentVideoAB
%hook AWEContentVideoOfAWEFeedABTestServiceObjc
+ (BOOL)enableAdChapterAutoSkip {
    return [DYYYAdChapterSkipPolicy isEnabled] ? YES : %orig;
}
%end
%end

%group DYYYAdChapterSkipPlayerAB
%hook AWEDPlayerABTestConfig
- (BOOL)enableAdChapterPlugin {
    return [DYYYAdChapterSkipPolicy isEnabled] ? YES : %orig;
}
%end
%end

// 39.8.0 的三个入口只格式化时间并展示“根据您的观看习惯，已为您智能跳过…章节内容”。
// 只拦专用提示，不改变 seek、完成回调或其他 Toast；关闭现有广告章节开关即恢复原生展示。
%group DYYYAdChapterSkipComponentToast
%hook AWEDPlayerComponentAdChapter
- (void)showAdSkipChapterToastWithStartTime:(double)startTime endTime:(double)endTime {
    if ([DYYYAdChapterSkipPolicy isEnabled]) return;
    %orig;
}
%end
%end

%group DYYYAdChapterSkipPluginToast
%hook AWEDPlayerAdChapterPlugin
- (void)showAdSkipChapterToastWithStartTime:(double)startTime endTime:(double)endTime {
    if ([DYYYAdChapterSkipPolicy isEnabled]) return;
    %orig;
}
%end
%end

%group DYYYAdChapterSkipLandscapeToast
%hook AWELandscapeAdChapterAutoSkipController
- (void)showAdSkipChapterToastWithStartTime:(double)startTime endTime:(double)endTime {
    if ([DYYYAdChapterSkipPolicy isEnabled]) return;
    %orig;
}
%end
%end

%ctor {
    Class chapterData = objc_getClass("AWECodeGenChapterDataModel");
    if (!chapterData || !class_getInstanceMethod(chapterData, @selector(adChapterAutoSkipIndexArray)) ||
        !class_getInstanceMethod(chapterData, @selector(adChapterIndexArray))) {
        NSLog(@"[DYYY] 广告章节跳过：当前抖音版本缺少章节数据接口，未启用");
        return;
    }
    %init(DYYYAdChapterSkipData);

    Class feedAB = objc_getClass("AWEFeedABTestServiceObjc");
    if (feedAB && class_getClassMethod(feedAB, @selector(enableAdChapterAutoSkip))) {
        %init(DYYYAdChapterSkipFeedAB);
    }
    Class contentVideoAB = objc_getClass("AWEContentVideoOfAWEFeedABTestServiceObjc");
    if (contentVideoAB && class_getClassMethod(contentVideoAB, @selector(enableAdChapterAutoSkip))) {
        %init(DYYYAdChapterSkipContentVideoAB);
    }
    Class playerAB = objc_getClass("AWEDPlayerABTestConfig");
    if (playerAB && class_getInstanceMethod(playerAB, @selector(enableAdChapterPlugin))) {
        %init(DYYYAdChapterSkipPlayerAB);
    }

    if ([DYYYAdChapterSkipPolicy supportsSkipToastForClass:objc_getClass("AWEDPlayerComponentAdChapter")]) {
        %init(DYYYAdChapterSkipComponentToast);
    }
    if ([DYYYAdChapterSkipPolicy supportsSkipToastForClass:objc_getClass("AWEDPlayerAdChapterPlugin")]) {
        %init(DYYYAdChapterSkipPluginToast);
    }
    if ([DYYYAdChapterSkipPolicy supportsSkipToastForClass:objc_getClass("AWELandscapeAdChapterAutoSkipController")]) {
        %init(DYYYAdChapterSkipLandscapeToast);
    }
}
