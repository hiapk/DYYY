#import <UIKit/UIKit.h>

// 跟随抖音主题的空列表外观，同时接收系统摇动事件。
@interface DYYYLikePrivacyCoverView : UIView
@property(nonatomic, assign) BOOL showsEmptyState;
- (void)updateAppearanceWithBackgroundColor:(UIColor *)backgroundColor;
@end
