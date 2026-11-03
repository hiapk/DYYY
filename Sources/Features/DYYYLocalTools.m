#import "DYYYLocalTools.h"
#import "DYYYBookmarkRecord.h"
#import "DYYYBookmarkListViewController.h"
#import "DYYYConversationPrivacyPolicy.h"
#import "DYYYKeywordListView.h"
#import "DYYYLocalRecordStore.h"
#import "DYYYUtils.h"
#import <objc/runtime.h>

@interface DYYYLocalTools ()
@property(nonatomic, copy) NSString *account;
@property(nonatomic, copy) NSSet<NSString *> *hiddenUIDs;
@property(nonatomic, strong) NSHashTable<UITableView *> *chatTables;
@property(nonatomic, assign) BOOL hideEnabled;
@property(nonatomic, assign) BOOL refreshPending;
@property(nonatomic, weak) AWEUserHomeViewControllerV2 *visibleHome;
@property(nonatomic, assign) NSUInteger hiddenLoadGeneration;
@end

@implementation DYYYLocalTools

+ (instancetype)shared {
    static DYYYLocalTools *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [DYYYLocalTools new]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _hiddenUIDs = [NSSet set];
        _chatTables = [NSHashTable weakObjectsHashTable];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(settingsChanged) name:NSUserDefaultsDidChangeNotification object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(settingsChanged) name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}

- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }

+ (DYYYLocalRecordStore *)recordStoreWithName:(NSString *)name account:(NSString *)account {
    NSURL *directory = [[NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject URLByAppendingPathComponent:@"DYYYLocalTools" isDirectory:YES];
    return [[DYYYLocalRecordStore alloc] initWithDirectoryURL:directory namespace:name accountID:account];
}

- (void)settingsChanged {
    dispatch_async(dispatch_get_main_queue(), ^{ [self ensureAccount]; });
}

- (void)refreshTables {
    if (self.refreshPending) return;
    self.refreshPending = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.refreshPending = NO;
        for (UITableView *table in self.chatTables.allObjects) if (table.window) [table reloadData];
    });
}

- (void)ensureAccount {
    NSString *account = [DYYYUtils currentAccountID] ?: @"guest";
    BOOL enabled = DYYYGetBool(@"DYYYHideCloseFriendChats");
    if (self.hideEnabled != enabled) { self.hideEnabled = enabled; [self refreshTables]; }
    if ([self.account isEqual:account]) return;
    self.account = account;
    self.hiddenUIDs = [NSSet set];
    [self refreshTables];
    if ([account isEqual:@"guest"]) return;
    [self loadHiddenUIDsForAccount:account];
}

- (void)loadHiddenUIDsForAccount:(NSString *)account {
    NSUInteger generation = ++self.hiddenLoadGeneration;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *error;
        NSArray *records = [[self.class recordStoreWithName:@"hidden-conversations" account:account] recordsWithError:&error];
        NSMutableSet *uids = [NSMutableSet set];
        for (NSDictionary *record in records) {
            NSString *uid = [DYYYConversationPrivacyPolicy normalizedUID:record[@"uid"]];
            if (uid) [uids addObject:uid];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation != self.hiddenLoadGeneration || ![[DYYYUtils currentAccountID] isEqual:account]) return;
            self.hiddenUIDs = [uids copy];
            [self refreshTables];
            if (error) [DYYYUtils showToast:error.localizedDescription];
        });
    });
}

- (void)refreshChatTables {
    dispatch_async(dispatch_get_main_queue(), ^{ [self ensureAccount]; [self refreshTables]; });
}

- (void)homeDidAppear:(AWEUserHomeViewControllerV2 *)home {
    if (NSThread.isMainThread) self.visibleHome = home;
}

- (void)homeDidDisappear:(AWEUserHomeViewControllerV2 *)home {
    if (NSThread.isMainThread && self.visibleHome == home) self.visibleHome = nil;
}

- (void)trackChatTable:(UITableView *)table {
    if (!NSThread.isMainThread || !table) return;
    [self.chatTables addObject:table];
    [self ensureAccount];
}

- (BOOL)shouldHideRow:(NSIndexPath *)path controller:(AWEIMChatListViewController *)controller table:(UITableView *)table {
    if (!NSThread.isMainThread) return NO;
    [self trackChatTable:table];
    if (!self.hideEnabled || !self.hiddenUIDs.count || path.section != 0 || ![controller respondsToSelector:@selector(chatList)]) return NO;
    NSArray *chats = controller.chatList;
    NSInteger count = [controller tableView:table numberOfRowsInSection:path.section];
    return [DYYYConversationPrivacyPolicy shouldHideRow:path.row section:path.section nativeCount:count chats:chats hiddenUIDs:self.hiddenUIDs enabled:self.hideEnabled];
}

- (void)applyHidden:(BOOL)hidden toCell:(UITableViewCell *)cell {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ [self applyHidden:hidden toCell:cell]; }); return; }
    [self restoreCell:cell];
    if (!hidden) return;
    NSDictionary *saved = @{@"hidden":@(cell.hidden), @"interactive":@(cell.userInteractionEnabled), @"accessibility":@(cell.accessibilityElementsHidden)};
    objc_setAssociatedObject(cell, @selector(restoreCell:), saved, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    cell.hidden = YES;
    cell.userInteractionEnabled = NO;
    cell.accessibilityElementsHidden = YES;
}

- (void)restoreCell:(UITableViewCell *)cell {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ [self restoreCell:cell]; }); return; }
    NSDictionary *saved = objc_getAssociatedObject(cell, @selector(restoreCell:));
    if (!saved) return;
    cell.hidden = [saved[@"hidden"] boolValue];
    cell.userInteractionEnabled = [saved[@"interactive"] boolValue];
    cell.accessibilityElementsHidden = [saved[@"accessibility"] boolValue];
    objc_setAssociatedObject(cell, @selector(restoreCell:), nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)showBookmarks {
    dispatch_async(dispatch_get_main_queue(), ^{
        DYYYBookmarkListViewController *list = [[DYYYBookmarkListViewController alloc] initWithAccount:[DYYYUtils currentAccountID] ?: @"guest"];
        UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:list];
        [[DYYYUtils topView] presentViewController:navigation animated:YES completion:nil];
    });
}

- (void)saveRecord:(NSDictionary *)record {
    if (!DYYYGetBool(@"DYYYEnableBookmarks")) return;
    if (!record) { [DYYYUtils showToast:@"无法读取作品或用户标识"]; return; }
    NSString *account = [DYYYUtils currentAccountID] ?: @"guest";
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *error;
        BOOL success = [[self.class recordStoreWithName:@"bookmarks" account:account] updateRecords:^NSArray *(NSArray *records, NSError **failure) {
            return [DYYYBookmarkRecord recordsByUpserting:record intoRecords:records];
        } error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{ [DYYYUtils showToast:success ? @"已保存到本地书签，可在列表中编辑分类和备注" : (error.localizedDescription ?: @"书签保存失败")]; });
    });
}

- (void)saveVideoBookmark:(AWEAwemeModel *)model {
    [self saveRecord:[DYYYBookmarkRecord recordWithType:@"video" identifier:model.itemID title:model.descriptionString author:model.author.nickname]];
}

- (void)saveProfileBookmark:(AWEUserModel *)user {
    [self saveRecord:[DYYYBookmarkRecord recordWithType:@"profile" identifier:user.userID title:user.nickname author:user.nickname]];
}

- (void)writeHiddenUIDs:(NSArray<NSString *> *)uids account:(NSString *)account {
    if (![[DYYYUtils currentAccountID] isEqual:account]) { [DYYYUtils showToast:@"账号已切换，请重新打开名单"]; return; }
    NSMutableArray *records = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    for (id value in uids) {
        NSString *uid = [DYYYConversationPrivacyPolicy normalizedUID:value];
        if (!uid) { [DYYYUtils showToast:@"请填写真实数字 UID，不能使用昵称或抖音号"]; return; }
        if (![seen containsObject:uid]) { [seen addObject:uid]; [records addObject:@{@"uid":uid}]; }
    }
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *error;
        BOOL success = [[self.class recordStoreWithName:@"hidden-conversations" account:account] updateRecords:^NSArray *(NSArray *old, NSError **failure) { return records; } error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) { [self loadHiddenUIDsForAccount:account]; [DYYYUtils showToast:@"会话名单已更新，无未读时隐藏"]; }
            else [DYYYUtils showToast:error.localizedDescription ?: @"名单保存失败"];
        });
    });
}

- (void)showHiddenUIDs {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self ensureAccount];
        NSString *account = [DYYYUtils currentAccountID];
        if (!account.length) { [DYYYUtils showToast:@"请先登录抖音账号"]; return; }
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSError *error;
            NSArray *records = [[self.class recordStoreWithName:@"hidden-conversations" account:account] recordsWithError:&error];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (![[DYYYUtils currentAccountID] isEqual:account]) return;
                if (error) { [DYYYUtils showToast:error.localizedDescription]; return; }
                NSMutableArray *uids = [NSMutableArray array];
                for (NSDictionary *record in records) if ([DYYYConversationPrivacyPolicy normalizedUID:record[@"uid"]]) [uids addObject:record[@"uid"]];
                DYYYKeywordListView *view = [[DYYYKeywordListView alloc] initWithTitle:@"隐藏会话的真实 UID（当前账号）" keywords:uids];
                view.addItemTitle = @"添加真实 UID";
                view.editItemTitle = @"编辑 UID";
                view.inputPlaceholder = @"仅数字 UID，非昵称或抖音号";
                view.onConfirm = ^(NSArray *values) { [self writeHiddenUIDs:values account:account]; };
                [view show];
            });
        });
    });
}

- (void)addHiddenUser:(AWEUserModel *)user {
    if (!DYYYGetBool(@"DYYYHideCloseFriendChats")) return;
    NSString *uid = [DYYYConversationPrivacyPolicy normalizedUID:user.userID];
    NSString *account = [DYYYUtils currentAccountID];
    if (!uid || !account.length || [uid isEqual:account]) { [DYYYUtils showToast:@"无法添加此用户，请先登录并打开对方主页"]; return; }
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *error;
        BOOL success = [[self.class recordStoreWithName:@"hidden-conversations" account:account] updateRecords:^NSArray *(NSArray *records, NSError **failure) {
            for (NSDictionary *record in records) if ([record[@"uid"] isEqual:uid]) return records;
            return [records arrayByAddingObject:@{@"uid":uid}];
        } error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) { [self loadHiddenUIDsForAccount:account]; [DYYYUtils showToast:@"已加入会话名单，无未读时隐藏"]; }
            else [DYYYUtils showToast:error.localizedDescription ?: @"名单保存失败"];
        });
    });
}

- (NSArray *)profileActions:(NSArray *)actions forSheet:(AWEUserActionSheetView *)sheet {
    if (!NSThread.isMainThread || ![actions isKindOfClass:NSArray.class]) return actions;
    NSArray *previous = objc_getAssociatedObject(sheet, @selector(profileActions:forSheet:));
    NSMutableArray *result = [actions mutableCopy];
    for (id action in previous) [result removeObjectIdenticalTo:action];
    objc_setAssociatedObject(sheet, @selector(profileActions:forSheet:), nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    BOOL bookmarks = DYYYGetBool(@"DYYYEnableBookmarks"), hidden = DYYYGetBool(@"DYYYHideCloseFriendChats");
    AWEUserHomeViewControllerV2 *home = self.visibleHome;
    if ((!bookmarks && !hidden) || !home.viewIfLoaded.window || home.viewIfLoaded.hidden) return result;
    AWEUserModel *user = home.userModel;
    if (![DYYYConversationPrivacyPolicy normalizedUID:user.userID]) return result;
    Class actionClass = NSClassFromString(@"AWEUserSheetAction");
    if (![actionClass respondsToSelector:@selector(actionWithTitle:imgName:handler:)] || ![actionClass instancesRespondToSelector:@selector(title)]) return result;
    // 该视图也用于视频菜单：必须同时命中至少两个主页原生动作，不能仅凭可见主页注入。
    NSUInteger profileTitles = 0;
    for (AWEUserSheetAction *action in result) {
        if (![action isKindOfClass:actionClass]) continue;
        NSString *title = action.title;
        if (![title isKindOfClass:NSString.class]) continue;
        for (NSString *keyword in @[@"分享名片", @"分享主页", @"私信", @"拉黑", @"举报", @"设置备注", @"加朋友", @"复制链接", @"关注"]) {
            if ([title containsString:keyword]) { profileTitles++; break; }
        }
    }
    if (profileTitles < 2) return result;
    NSMutableArray *added = [NSMutableArray array];
    if (bookmarks) {
        id action = [actionClass actionWithTitle:@"保存主页书签" imgName:@"ic_star_outlined_20" handler:^{ [self saveProfileBookmark:user]; }];
        if (action) [added addObject:action];
    }
    if (hidden && ![user.userID isEqual:[DYYYUtils currentAccountID]]) {
        id action = [actionClass actionWithTitle:@"加入隐藏会话名单" imgName:@"ic_eyeslash_outlined_16" handler:^{ [self addHiddenUser:user]; }];
        if (action) [added addObject:action];
    }
    [result addObjectsFromArray:added];
    objc_setAssociatedObject(sheet, @selector(profileActions:forSheet:), added, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return result;
}
@end
