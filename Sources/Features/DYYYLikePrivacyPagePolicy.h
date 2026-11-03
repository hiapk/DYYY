#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

// 主页标签与遮挡几何的纯判定，不依赖 UIKit，可在 macOS 上独立测试。
@interface DYYYLikePrivacyPagePolicy : NSObject
// 标题可为 NSString、NSAttributedString 或带 title/selectedTitle 的分段数据模型；找不到时返回 NSNotFound。
+ (NSInteger)likeTabIndexInTitles:(nullable NSArray *)titles;
// 遮挡从分段标签下沿开始，覆盖喜欢页剩余区域；标签与资料卡保持可见。
+ (CGRect)coverFrameForPageFrame:(CGRect)pageFrame contentTop:(CGFloat)contentTop;
@end

NS_ASSUME_NONNULL_END
