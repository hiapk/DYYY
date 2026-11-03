#import "DYYYLikePrivacyController.h"
#import "AwemeHeaders.h"
#import "DYYYCustomInputView.h"
#import "DYYYLikePrivacyCoverView.h"
#import "DYYYLikePrivacyPagePolicy.h"
#import "DYYYLikePrivacyState.h"
#import "DYYYUtils.h"

@interface DYYYLikePrivacyController ()
@property(nonatomic, strong) DYYYLikePrivacyState *state;
@property(nonatomic, strong) NSMutableArray *observerTokens;
@property(nonatomic, strong) dispatch_queue_t passwordQueue;
@property(nonatomic, weak) AWEUserHomeViewControllerV2 *home;
@property(nonatomic, weak) AWERLPageViewController *page;
@property(nonatomic, assign) NSInteger likeIndex;
@property(nonatomic, strong) DYYYLikePrivacyCoverView *cover;
@property(nonatomic, strong) DYYYLikePrivacyCoverView *videoCover;
@property(nonatomic, weak) UIViewController *videoController;
@property(nonatomic, assign) BOOL videoSession;
@property(nonatomic, weak) DYYYCustomInputView *prompt;
@property(nonatomic, assign) BOOL busy;
@property(nonatomic, assign) BOOL unlockPrompt;
@property(nonatomic, assign) UIUserInterfaceStyle coverStyle;
@property(nonatomic, assign) BOOL refreshing;
@property(nonatomic, assign) BOOL reportedUnsupported;
@end

@implementation DYYYLikePrivacyController

+ (instancetype)shared {
    static DYYYLikePrivacyController *controller;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ controller = [[self alloc] init]; });
    return controller;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _state = [[DYYYLikePrivacyState alloc] init];
        _observerTokens = [NSMutableArray array];
        _passwordQueue = dispatch_queue_create("com.dyyy.likes-privacy.password", DISPATCH_QUEUE_SERIAL);
        _likeIndex = NSNotFound;
    }
    return self;
}

#pragma mark - 应用与账号生命周期

- (void)start {
    if (self.observerTokens.count) return;
    __weak typeof(self) weakSelf = self;
    // 只以真正进入后台作为锁定依据；键盘、控制中心等短暂失活不取消密码框。
    id background = [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *notification) {
        DYYYLikePrivacyController *controller = weakSelf;
        if (!controller) return;
        [controller.state lock];
        [controller cancelPromptWithReason:@"进入后台"];
        [controller refresh];
    }];
    [self.observerTokens addObject:background];
    for (NSString *name in @[UIApplicationDidBecomeActiveNotification, UIApplicationProtectedDataDidBecomeAvailable]) {
        id token = [NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *notification) {
            DYYYLikePrivacyController *controller = weakSelf;
            if (!controller) return;
            if (!controller.state.storageError) { [controller refresh]; return; }
            dispatch_async(controller.passwordQueue, ^{
                [controller.state reloadCredentialRecord];
                dispatch_async(dispatch_get_main_queue(), ^{ [controller refresh]; });
            });
        }];
        [self.observerTokens addObject:token];
    }
}

- (void)dealloc {
    for (id token in self.observerTokens) [NSNotificationCenter.defaultCenter removeObserver:token];
}

- (void)accountDidChange {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self accountDidChange]; });
        return;
    }
    [self leaveWithReason:@"账号变化"];
    [self refresh];
}

- (void)leaveWithReason:(NSString *)reason {
    [self.state updateContext:nil location:DYYYLikePrivacyLocationOutside];
    [self cancelPromptWithReason:reason];
    self.videoSession = NO;
    self.videoController = nil;
}

#pragma mark - 自己的主页与喜欢标签

- (NSString *)currentUserID {
    Class cls = NSClassFromString(@"AWEUserService");
    if (![cls respondsToSelector:@selector(sharedService)]) return nil;
    AWEUserService *service = [cls sharedService];
    if (![service respondsToSelector:@selector(userID)]) return nil;
    NSString *userID = [service userID];
    return [userID isKindOfClass:NSString.class] && userID.length ? userID : nil;
}

- (BOOL)isOwnHome:(UIViewController *)controller {
    Class cls = NSClassFromString(@"AWEUserHomeViewControllerV2");
    if (!controller || !cls || ![controller isKindOfClass:cls]) return NO;
    AWEUserHomeViewControllerV2 *home = (AWEUserHomeViewControllerV2 *)controller;
    if ([home respondsToSelector:@selector(isCurrentUserProfilePage)] && home.isCurrentUserProfilePage) return YES;
    NSString *current = [self currentUserID];
    NSString *userID = [home respondsToSelector:@selector(userModel)] ? home.userModel.userID : nil;
    return current.length && [userID isKindOfClass:NSString.class] && [current isEqualToString:userID];
}

- (NSString *)contextForHome:(AWEUserHomeViewControllerV2 *)home {
    if (!home) return nil;
    return [NSString stringWithFormat:@"%p:%@", home, [self currentUserID] ?: @"self"];
}

- (AWERLTabListViewController *)tabListForHome:(AWEUserHomeViewControllerV2 *)home {
    if (![home respondsToSelector:@selector(tabListViewController)]) return nil;
    AWERLTabListViewController *tabList = home.tabListViewController;
    Class cls = NSClassFromString(@"AWERLTabListViewController");
    return cls && [tabList isKindOfClass:cls] ? tabList : nil;
}

- (AWERLPageViewController *)pageForTabList:(AWERLTabListViewController *)tabList {
    if (![tabList respondsToSelector:@selector(pageViewController)]) return nil;
    AWERLPageViewController *page = tabList.pageViewController;
    if (![page respondsToSelector:@selector(scrollView)] || ![page respondsToSelector:@selector(selectedIndex)]) return nil;
    return [page.scrollView isKindOfClass:UIScrollView.class] ? page : nil;
}

- (NSArray *)tabTitlesForTabList:(AWERLTabListViewController *)tabList home:(AWEUserHomeViewControllerV2 *)home {
    // 分段控件的数据模型与分页序号一一对应，优先使用；标签助手作为兜底。
    UIView *segment = [tabList respondsToSelector:@selector(segmentView)] ? tabList.segmentView : nil;
    if ([segment respondsToSelector:@selector(itemModels)]) {
        NSArray *models = [(AWERLSegmentView *)segment itemModels];
        if ([models isKindOfClass:NSArray.class] && models.count) return models;
    }
    AWEUserProfileTabHelper *helper = [home respondsToSelector:@selector(tabHelper)] ? home.tabHelper : nil;
    NSArray *titles = [helper respondsToSelector:@selector(tabTitles)] ? helper.tabTitles : nil;
    return [titles isKindOfClass:NSArray.class] ? titles : nil;
}

- (BOOL)isPageScrolling:(AWERLPageViewController *)page {
    UIScrollView *scroll = page.scrollView;
    return scroll.isTracking || scroll.isDragging || scroll.isDecelerating;
}

- (void)reportUnsupportedIfNeeded {
    if (self.reportedUnsupported) return;
    self.reportedUnsupported = YES;
    NSLog(@"[DYYY] 喜欢页保护未找到主页标签结构");
    [DYYYUtils showToast:@"喜欢页保护未适配当前页面"];
}

- (void)adoptHome:(AWEUserHomeViewControllerV2 *)home {
    if (self.home == home) return;
    if (self.home) [self leaveWithReason:@"切换主页"];
    [self removeCover];
    self.home = home;
}

#pragma mark - 宿主回调

- (void)homeDidLayout:(UIViewController *)controller {
    if (controller != self.home) {
        if (!controller.viewIfLoaded.window || ![self isOwnHome:controller]) return;
        [self adoptHome:(AWEUserHomeViewControllerV2 *)controller];
    }
    [self refresh];
}

- (void)homeDidAppear:(UIViewController *)controller {
    if (![self isOwnHome:controller]) {
        // 从受保护视频进入他人主页视为离开。
        if (self.videoSession) [self leaveWithReason:@"进入其他主页"];
        [self refresh];
        return;
    }
    [self adoptHome:(AWEUserHomeViewControllerV2 *)controller];
    self.videoSession = NO;
    self.videoController = nil;
    [self refresh];
}

- (void)homeDidDisappear:(UIViewController *)controller {
    if (controller != self.home) return;
    AWEUserHomeViewControllerV2 *home = self.home;
    UIViewController *video = self.state.unlocked ? [self videoControllerAboveHome:home] : nil;
    if (video) {
        self.videoSession = YES;
        self.videoController = video;
        [self.state updateContext:[self contextForHome:home] location:DYYYLikePrivacyLocationVideo];
    } else {
        [self leaveWithReason:@"离开个人主页"];
    }
    [self refresh];
}

- (void)pageDidLayout:(UIViewController *)page {
    if (page != self.page || !self.cover.superview) return;
    [self layoutCover];
}

- (void)pageDidScroll:(UIViewController *)page {
    // 横滑时宿主可能懒加载新页面，保证遮挡层始终在喜欢页内容之上。
    if (page != self.page || !self.cover.superview) return;
    [self bringCoverToFrontIfNeeded];
}

- (void)pageSelectionDidChange:(UIViewController *)page {
    if (page == self.page) [self refresh];
}

- (void)tabListContentDidScroll:(UIViewController *)tabList {
    if (!self.cover.superview || tabList != [self tabListForHome:self.home]) return;
    [self layoutCover];
}

#pragma mark - 视频交接

- (BOOL)isVideoController:(UIViewController *)controller {
    for (NSString *name in @[@"AWEAwemeDetailTableViewController", @"AWEAwemePlayVideoViewController",
                             @"AWEDPlayerFeedPlayerViewController", @"AWEDPlayerViewController_Merge"]) {
        Class cls = NSClassFromString(name);
        if (cls && [controller isKindOfClass:cls]) return YES;
    }
    return NO;
}

- (UIViewController *)videoControllerIn:(UIViewController *)controller depth:(NSUInteger)depth {
    if (!controller || depth > 3) return nil;
    if ([self isVideoController:controller]) return controller;
    if ([controller isKindOfClass:UINavigationController.class]) {
        return [self videoControllerIn:((UINavigationController *)controller).topViewController depth:depth + 1];
    }
    for (UIViewController *child in controller.childViewControllers) {
        UIViewController *video = [self videoControllerIn:child depth:depth + 1];
        if (video) return video;
    }
    return nil;
}

- (UIViewController *)videoControllerAboveHome:(AWEUserHomeViewControllerV2 *)home {
    NSMutableArray<UIViewController *> *candidates = [NSMutableArray array];
    UINavigationController *navigation = home.navigationController;
    if (navigation.topViewController && navigation.topViewController != home) [candidates addObject:navigation.topViewController];
    for (UIViewController *presenter in @[home, navigation ?: home, home.tabBarController ?: home]) {
        if (presenter.presentedViewController) [candidates addObject:presenter.presentedViewController];
    }
    for (UIViewController *candidate in candidates) {
        UIViewController *video = [self videoControllerIn:candidate depth:0];
        if (video) return video;
    }
    return nil;
}

#pragma mark - 遮挡层

- (UIColor *)backgroundColorFromView:(UIView *)view {
    UIView *stop = self.home.viewIfLoaded;
    for (UIView *current = view; current && ![current isKindOfClass:UIWindow.class]; current = current.superview) {
        UIColor *color = [current.backgroundColor resolvedColorWithTraitCollection:current.traitCollection];
        if (color && CGColorGetAlpha(color.CGColor) >= 0.99) return color;
        if (current == stop) break;
    }
    return [DYYYUtils douyinSettingsPageBackgroundColor];
}

- (CGRect)pageFrameAtIndex:(NSInteger)index inPage:(AWERLPageViewController *)page scrollView:(UIScrollView *)scroll {
    if ([page respondsToSelector:@selector(addedViewControllers)] && [page respondsToSelector:@selector(indexForViewController:)]) {
        for (id child in page.addedViewControllers) {
            if (![child isKindOfClass:UIViewController.class]) continue;
            UIViewController *controller = child;
            if (!controller.isViewLoaded || controller.view.superview != scroll) continue;
            if ([page indexForViewController:controller] == index) return controller.view.frame;
        }
    }
    // 喜欢页尚未加载时按分页宽度预留位置，横滑进入时同样不会露出内容。
    CGSize size = scroll.bounds.size;
    return CGRectMake(size.width * index, 0, size.width, size.height);
}

- (void)layoutCover {
    DYYYLikePrivacyCoverView *cover = self.cover;
    AWERLPageViewController *page = self.page;
    UIScrollView *scroll = page.scrollView;
    if (!cover || cover.superview != scroll || self.likeIndex == NSNotFound) return;
    CGFloat contentTop = -CGFLOAT_MAX;
    UIView *segment = [self tabListForHome:self.home].segmentView;
    if (segment.window && segment.window == scroll.window && !segment.hidden) {
        contentTop = CGRectGetMaxY([segment convertRect:segment.bounds toView:scroll]);
    }
    CGRect frame = [DYYYLikePrivacyPagePolicy coverFrameForPageFrame:[self pageFrameAtIndex:self.likeIndex inPage:page scrollView:scroll]
                                                          contentTop:contentTop];
    if (!CGRectEqualToRect(cover.frame, frame)) cover.frame = frame;
    [self bringCoverToFrontIfNeeded];
}

- (void)bringCoverToFrontIfNeeded {
    UIView *cover = self.cover;
    UIView *scroll = cover.superview;
    if (!scroll) return;
    NSArray<UIView *> *subviews = scroll.subviews;
    NSUInteger index = [subviews indexOfObjectIdenticalTo:cover];
    if (index == NSNotFound) return;
    for (NSUInteger i = index + 1; i < subviews.count; i++) {
        UIView *view = subviews[i];
        // 忽略滚动指示条等细条视图，避免每帧重排。
        if (view.hidden || MIN(view.bounds.size.width, view.bounds.size.height) <= 10) continue;
        if (CGRectIntersectsRect(view.frame, cover.frame)) {
            [scroll bringSubviewToFront:cover];
            return;
        }
    }
}

- (void)installCover {
    UIScrollView *scroll = self.page.scrollView;
    if (CGRectIsEmpty(scroll.bounds)) {
        [self removeCover];
        return;
    }
    if (!self.cover) {
        self.cover = [[DYYYLikePrivacyCoverView alloc] initWithFrame:CGRectZero];
        self.cover.tag = DYYY_IGNORE_GLOBAL_ALPHA_TAG;
    }
    UIUserInterfaceStyle style = scroll.traitCollection.userInterfaceStyle;
    if (self.cover.superview != scroll || self.coverStyle != style) {
        [scroll addSubview:self.cover];
        [self.cover updateAppearanceWithBackgroundColor:[self backgroundColorFromView:scroll]];
        self.coverStyle = style;
    }
    [self layoutCover];
}

- (void)removeCover {
    if (self.cover.isFirstResponder) [self.cover resignFirstResponder];
    [self.cover removeFromSuperview];
}

- (BOOL)likesCoverIsForeground {
    AWERLPageViewController *page = self.page;
    return self.cover.window && self.home.viewIfLoaded.window && page && page.selectedIndex == self.likeIndex &&
        ![self isPageScrolling:page] && !self.state.unlocked;
}

- (void)updateLikesCover {
    AWEUserHomeViewControllerV2 *home = self.home;
    BOOL ownHome = [self isOwnHome:home];
    AWERLTabListViewController *tabList = ownHome ? [self tabListForHome:home] : nil;
    AWERLPageViewController *page = [self pageForTabList:tabList];
    NSArray *titles = page ? [self tabTitlesForTabList:tabList home:home] : nil;
    self.page = page;
    self.likeIndex = [DYYYLikePrivacyPagePolicy likeTabIndexInTitles:titles];
    if (!self.state.enabled || !ownHome) {
        [self removeCover];
        return;
    }
    if (!page || !titles.count) {
        if (home.viewIfLoaded.window) [self reportUnsupportedIfNeeded];
        [self removeCover];
        return;
    }
    if (self.likeIndex == NSNotFound) {
        // 用户隐藏了喜欢标签时没有需要保护的内容。
        [self removeCover];
        return;
    }
    if (home.viewIfLoaded.window && !self.videoSession && ![self isPageScrolling:page]) {
        if (page.selectedIndex == self.likeIndex) {
            [self.state updateContext:[self contextForHome:home] location:DYYYLikePrivacyLocationLikes];
        } else if (self.state.unlocked || self.unlockPrompt) {
            [self leaveWithReason:@"切换主页标签"];
        }
    }
    // 锁定期间遮挡层常驻喜欢页位置，即使当前在其他标签，横滑进入时也不会露出内容。
    if (self.state.unlocked) [self removeCover];
    else [self installCover];
}

- (void)updateVideoCover {
    UIViewController *video = self.videoController;
    BOOL show = self.state.enabled && self.videoSession && !self.state.unlocked && video.viewIfLoaded.window;
    if (!show) {
        if (self.videoCover.isFirstResponder) [self.videoCover resignFirstResponder];
        [self.videoCover removeFromSuperview];
        self.videoCover = nil;
        return;
    }
    if (!self.videoCover) {
        self.videoCover = [[DYYYLikePrivacyCoverView alloc] initWithFrame:video.view.bounds];
        self.videoCover.tag = DYYY_IGNORE_GLOBAL_ALPHA_TAG;
        self.videoCover.showsEmptyState = NO;
        self.videoCover.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.videoCover updateAppearanceWithBackgroundColor:[DYYYUtils douyinSettingsPageBackgroundColor]];
    }
    if (self.videoCover.superview != video.view) [video.view addSubview:self.videoCover];
    if (video.view.subviews.lastObject != self.videoCover) [video.view bringSubviewToFront:self.videoCover];
}

- (void)updateFirstResponder {
    if (self.prompt || self.busy || UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
    DYYYLikePrivacyCoverView *target = nil;
    if ([self likesCoverIsForeground]) target = self.cover;
    else if (self.videoCover.window) target = self.videoCover;
    if (self.cover.isFirstResponder && target != self.cover) [self.cover resignFirstResponder];
    if (target && !target.isFirstResponder) [target becomeFirstResponder];
}

- (void)refresh {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self refresh]; });
        return;
    }
    if (self.refreshing) return;
    self.refreshing = YES;
    [self updateLikesCover];
    [self updateVideoCover];
    [self updateFirstResponder];
    self.refreshing = NO;
}

#pragma mark - 密码输入与设置

- (BOOL)handleShakeInWindow:(UIWindow *)window {
    [self refresh];
    if (!self.state.enabled || self.state.unlocked) return NO;
    BOOL likesVisible = [self likesCoverIsForeground] && (!window || self.cover.window == window);
    BOOL videoVisible = self.videoCover.window && (!window || self.videoCover.window == window);
    if (!likesVisible && !videoVisible) return NO;
    if (self.busy || self.prompt) return YES;
    NSUInteger generation = self.state.generation;
    [self askForPIN:@"输入喜欢页密码" completion:^(NSString *PIN) {
        if (!PIN) return;
        self.busy = YES;
        dispatch_async(self.passwordQueue, ^{
            BOOL success = [self.state unlockWithPIN:PIN generation:generation];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.busy = NO;
                [self refresh];
                if (!success && generation == self.state.generation) [DYYYUtils showToast:@"密码不正确"];
            });
        });
    }];
    // 只有解锁密码框会因切换标签而取消，设置页发起的密码框不受影响。
    self.unlockPrompt = self.prompt != nil;
    return YES;
}

- (void)cancelPromptWithReason:(NSString *)reason {
    [self.state cancelPrompts];
    DYYYCustomInputView *prompt = self.prompt;
    self.prompt = nil;
    self.unlockPrompt = NO;
    if (prompt) NSLog(@"[DYYY] 喜欢页密码框取消：%@", reason);
    [prompt dismiss];
}

- (void)askForPIN:(NSString *)title completion:(void (^)(NSString *PIN))completion {
    if (self.busy || self.prompt) return;
    if (![DYYYUtils getActiveWindow]) return;
    DYYYCustomInputView *input = [[DYYYCustomInputView alloc] initWithTitle:title defaultText:nil placeholder:@"请输入 4～6 位数字"];
    input.inputTextField.secureTextEntry = YES;
    input.inputTextField.keyboardType = UIKeyboardTypeNumberPad;
    input.inputTextField.textContentType = @"";
    NSUInteger promptGeneration = [self.state beginPrompt];
    __weak typeof(self) weakSelf = self;
    void (^finish)(NSString *) = ^(NSString *PIN) {
        // 先检查令牌，旧输入框的回调不能清除后来新建的输入框引用。
        if (![weakSelf.state consumePrompt:promptGeneration]) return;
        weakSelf.prompt = nil;
        weakSelf.unlockPrompt = NO;
        [weakSelf refresh];
        completion(PIN);
    };
    input.onConfirm = finish;
    input.onCancel = ^{ finish(nil); };
    self.prompt = input;
    [input show];
}

- (NSString *)protectionStatus {
    if (self.state.storageError) return @"密码记录不可用，保持锁定";
    if (self.state.enabled && (!NSClassFromString(@"AWEUserHomeViewControllerV2") || !NSClassFromString(@"AWERLPageViewController"))) {
        return @"当前版本尚未适配";
    }
    return self.state.enabled ? @"已开启" : @"未开启";
}

- (void)finishChange:(BOOL)success error:(NSError *)error completion:(void (^)(void))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.busy = NO;
        [self refresh];
        NSString *message = self.state.enabled ? @"喜欢页保护已开启" : @"喜欢页保护已关闭";
        [DYYYUtils showToast:success ? message : (error.localizedDescription ?: @"设置失败")];
        if (completion) completion();
    });
}

- (void)showProtectionSettingsWithCompletion:(void (^)(void))completion {
    if (!self.state.hasPIN) {
        [self showPasswordSettingsWithCompletion:completion];
        return;
    }
    BOOL enable = !self.state.enabled;
    [self askForPIN:enable ? @"验证密码以开启保护" : @"验证密码以关闭保护" completion:^(NSString *PIN) {
        if (!PIN) return;
        self.busy = YES;
        dispatch_async(self.passwordQueue, ^{
            NSError *error = nil;
            BOOL success = [self.state setEnabled:enable currentPIN:PIN error:&error];
            [self finishChange:success error:error completion:completion];
        });
    }];
}

- (void)collectNewPINWithCurrentPIN:(NSString *)currentPIN completion:(void (^)(void))completion {
    [self askForPIN:@"设置喜欢页密码" completion:^(NSString *PIN) {
        if (!PIN) return;
        if (![DYYYLikePrivacyState isValidPIN:PIN]) {
            [DYYYUtils showToast:@"密码必须为 4～6 位数字"];
            return;
        }
        [self askForPIN:@"再次输入新密码" completion:^(NSString *confirmation) {
            if (!confirmation) return;
            if (![PIN isEqualToString:confirmation]) {
                [DYYYUtils showToast:@"两次密码不一致，设置未更改"];
                return;
            }
            self.busy = YES;
            dispatch_async(self.passwordQueue, ^{
                NSError *error = nil;
                BOOL success = [self.state setPIN:PIN currentPIN:currentPIN error:&error];
                [self finishChange:success error:error completion:completion];
            });
        }];
    }];
}

- (void)showPasswordSettingsWithCompletion:(void (^)(void))completion {
    if (self.state.storageError) {
        [DYYYUtils showToast:self.state.storageError.localizedDescription];
        return;
    }
    if (!self.state.hasPIN) {
        [self collectNewPINWithCurrentPIN:nil completion:completion];
        return;
    }
    [self askForPIN:@"输入原喜欢页密码" completion:^(NSString *PIN) {
        if (!PIN) return;
        NSUInteger promptGeneration = self.state.promptGeneration;
        self.busy = YES;
        dispatch_async(self.passwordQueue, ^{
            BOOL verified = [self.state verifyPIN:PIN];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.busy = NO;
                if (promptGeneration != self.state.promptGeneration) return;
                if (verified) [self collectNewPINWithCurrentPIN:PIN completion:completion];
                else [DYYYUtils showToast:@"原密码不正确"];
            });
        });
    }];
}

@end
