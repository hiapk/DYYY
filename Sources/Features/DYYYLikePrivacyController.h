#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// 喜欢页保护：遮挡层挂在自己主页的分页滚动视图里，随喜欢页一起滑动，不覆盖侧栏、设置与底栏。
@interface DYYYLikePrivacyController : NSObject
+ (instancetype)shared;
- (void)start;
- (void)refresh;
- (void)homeDidLayout:(UIViewController *)home;
- (void)homeDidAppear:(UIViewController *)home;
- (void)homeDidDisappear:(UIViewController *)home;
- (void)pageDidLayout:(UIViewController *)page;
- (void)pageDidScroll:(UIViewController *)page;
- (void)pageSelectionDidChange:(UIViewController *)page;
- (void)tabListContentDidScroll:(UIViewController *)tabList;
- (void)accountDidChange;
- (BOOL)handleShakeInWindow:(nullable UIWindow *)window;
- (void)showProtectionSettingsWithCompletion:(nullable void (^)(void))completion;
- (void)showPasswordSettingsWithCompletion:(nullable void (^)(void))completion;
- (NSString *)protectionStatus;
@end

NS_ASSUME_NONNULL_END
