#import "AwemeHeaders.h"
#import "DYYYAdChapterSkipPolicy.h"

// 运行实际 Logos Hook，模拟原生提示入口；不依赖 UIKit，也不连接抖音服务端。
static NSUInteger gDYYYNativeAdToastCalls = 0;
static double gDYYYNativeAdToastStart = 0;
static double gDYYYNativeAdToastEnd = 0;

@interface DYYYAdToastChangedSignature : NSObject
- (void)showAdSkipChapterToastWithStartTime:(id)startTime endTime:(id)endTime;
@end
@implementation DYYYAdToastChangedSignature
- (void)showAdSkipChapterToastWithStartTime:(id)startTime endTime:(id)endTime {}
@end

@implementation AWECodeGenChapterDataModel
@end

@implementation AWEDPlayerComponentAdChapter
- (void)showAdSkipChapterToastWithStartTime:(double)startTime endTime:(double)endTime {
    gDYYYNativeAdToastCalls++;
    gDYYYNativeAdToastStart = startTime;
    gDYYYNativeAdToastEnd = endTime;
}
@end

@implementation AWEDPlayerAdChapterPlugin
- (void)showAdSkipChapterToastWithStartTime:(double)startTime endTime:(double)endTime {
    gDYYYNativeAdToastCalls++;
    gDYYYNativeAdToastStart = startTime;
    gDYYYNativeAdToastEnd = endTime;
}
@end

@implementation AWELandscapeAdChapterAutoSkipController
- (void)showAdSkipChapterToastWithStartTime:(double)startTime endTime:(double)endTime {
    gDYYYNativeAdToastCalls++;
    gDYYYNativeAdToastStart = startTime;
    gDYYYNativeAdToastEnd = endTime;
}
@end

#define CHECK(...) NSCAssert((__VA_ARGS__), @"测试失败：%s", #__VA_ARGS__)

int main(void) {
    @autoreleasepool {
        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        id previousSetting = [defaults objectForKey:DYYYAutoSkipAdChapterKey];
        @try {
            CHECK(![DYYYAdChapterSkipPolicy supportsSkipToastForClass:Nil]);
            CHECK(![DYYYAdChapterSkipPolicy supportsSkipToastForClass:NSObject.class]);
            CHECK(![DYYYAdChapterSkipPolicy supportsSkipToastForClass:DYYYAdToastChangedSignature.class]);
            for (AWEDPlayerComponentAdChapter *player in @[[AWEDPlayerComponentAdChapter new], [AWEDPlayerAdChapterPlugin new], [AWELandscapeAdChapterAutoSkipController new]]) {
                CHECK([DYYYAdChapterSkipPolicy supportsSkipToastForClass:[player class]]);
                [defaults removeObjectForKey:DYYYAutoSkipAdChapterKey];
                NSUInteger originalCount = gDYYYNativeAdToastCalls;
                [player showAdSkipChapterToastWithStartTime:12.5 endTime:34.75];
                CHECK(gDYYYNativeAdToastCalls == originalCount + 1);
                CHECK(gDYYYNativeAdToastStart == 12.5 && gDYYYNativeAdToastEnd == 34.75);

                // 回归：开启后专用原生 Toast 不再展示；此前三个入口均仍会展示。
                [defaults setBool:YES forKey:DYYYAutoSkipAdChapterKey];
                [player showAdSkipChapterToastWithStartTime:40.25 endTime:60.5];
                CHECK(gDYYYNativeAdToastCalls == originalCount + 1);

                [defaults setBool:NO forKey:DYYYAutoSkipAdChapterKey];
                [player showAdSkipChapterToastWithStartTime:70.25 endTime:90.5];
                CHECK(gDYYYNativeAdToastCalls == originalCount + 2);
                CHECK(gDYYYNativeAdToastStart == 70.25 && gDYYYNativeAdToastEnd == 90.5);
            }
            // 静默提示后，实际章节数据 Hook 仍将全部广告章节交给原生跳过逻辑。
            AWECodeGenChapterDataModel *model = [AWECodeGenChapterDataModel new];
            model.adChapterIndexArray = @[@1, @3];
            model.adChapterAutoSkipIndexArray = @[@3];
            CHECK([model.adChapterAutoSkipIndexArray isEqualToArray:@[@3]]);
            [defaults setBool:YES forKey:DYYYAutoSkipAdChapterKey];
            CHECK([model.adChapterAutoSkipIndexArray isEqualToArray:@[@1, @3]]);
            NSLog(@"广告章节 Toast：竖屏组件、播放器插件、横屏入口的实际 Logos Hook 回归通过");
        } @finally {
            if (previousSetting) [defaults setObject:previousSetting forKey:DYYYAutoSkipAdChapterKey];
            else [defaults removeObjectForKey:DYYYAutoSkipAdChapterKey];
        }
    }
    return 0;
}
