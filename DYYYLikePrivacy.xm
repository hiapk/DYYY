#import "AwemeHeaders.h"
#import "DYYYLikePrivacyController.h"

// 抖音 39.8.0 自己主页的“喜欢”标签由 AWERLTabListViewController 分页承载，列表控制器类名随版本变化，
// 因此按主页标签序号定位喜欢页，遮挡层挂在分页滚动视图内，随页面一起横滑。

%group DYYYLikePrivacyProfile
%hook AWEUserHomeViewControllerV2
- (void)viewDidLayoutSubviews {
    %orig;
    [[DYYYLikePrivacyController shared] homeDidLayout:self];
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    [[DYYYLikePrivacyController shared] homeDidAppear:self];
}
- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    [[DYYYLikePrivacyController shared] homeDidDisappear:self];
}
- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    if (motion == UIEventSubtypeMotionShake && [[DYYYLikePrivacyController shared] handleShakeInWindow:self.viewIfLoaded.window]) return;
    %orig;
}
%end

%hook AWERLPageViewController
- (void)viewDidLayoutSubviews {
    %orig;
    [[DYYYLikePrivacyController shared] pageDidLayout:self];
}
- (void)setSelectedIndex:(NSInteger)selectedIndex {
    %orig;
    [[DYYYLikePrivacyController shared] pageSelectionDidChange:self];
}
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    %orig;
    [[DYYYLikePrivacyController shared] pageDidScroll:self];
}
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    %orig;
    if (!decelerate) [[DYYYLikePrivacyController shared] pageSelectionDidChange:self];
}
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    %orig;
    [[DYYYLikePrivacyController shared] pageSelectionDidChange:self];
}
- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    %orig;
    [[DYYYLikePrivacyController shared] pageSelectionDidChange:self];
}
%end

%hook AWERLTabListViewController
- (void)onViewControllerDidScroll:(UIViewController *)controller contentOffset:(CGPoint)contentOffset {
    %orig;
    [[DYYYLikePrivacyController shared] tabListContentDidScroll:self];
}
- (void)onViewControllerDidScroll:(UIViewController *)controller scrollView:(UIScrollView *)scrollView {
    %orig;
    [[DYYYLikePrivacyController shared] tabListContentDidScroll:self];
}
%end
%end

%group DYYYLikePrivacyLogin
%hook AWEUserServiceListener
- (void)didFinishLoginWithUid:(NSString *)userID {
    [[DYYYLikePrivacyController shared] accountDidChange];
    %orig;
}
%end
%end

%group DYYYLikePrivacyLogout
%hook AWEUserServiceListener
- (void)didFinishLogoutWithUid:(NSString *)userID {
    [[DYYYLikePrivacyController shared] accountDidChange];
    %orig;
}
%end
%end

%ctor {
    Class home = objc_getClass("AWEUserHomeViewControllerV2");
    Class page = objc_getClass("AWERLPageViewController");
    Class tabList = objc_getClass("AWERLTabListViewController");
    if (home && page && tabList && class_getInstanceMethod(home, @selector(tabListViewController)) &&
        class_getInstanceMethod(tabList, @selector(pageViewController)) && class_getInstanceMethod(page, @selector(scrollView))) {
        %init(DYYYLikePrivacyProfile);
    } else {
        NSLog(@"[DYYY] 喜欢页保护：当前抖音版本缺少主页分页接口，未启用");
    }
    Class listener = objc_getClass("AWEUserServiceListener");
    if (listener && class_getInstanceMethod(listener, @selector(didFinishLoginWithUid:))) {
        %init(DYYYLikePrivacyLogin);
    }
    if (listener && class_getInstanceMethod(listener, @selector(didFinishLogoutWithUid:))) {
        %init(DYYYLikePrivacyLogout);
    }
    dispatch_async(dispatch_get_main_queue(), ^{ [[DYYYLikePrivacyController shared] start]; });
}
