#import <UIKit/UIKit.h>
#import "AwemeHeaders.h"
NS_ASSUME_NONNULL_BEGIN
@class DYYYLocalRecordStore;
@interface DYYYLocalTools : NSObject
+ (instancetype)shared;
+ (DYYYLocalRecordStore *)recordStoreWithName:(NSString *)name account:(NSString *)account;
- (void)saveVideoBookmark:(AWEAwemeModel *)model;
- (void)saveProfileBookmark:(AWEUserModel *)user;
- (void)showBookmarks;
- (void)showHiddenUIDs;
- (void)addHiddenUser:(AWEUserModel *)user;
- (void)trackChatTable:(UITableView *)table;
- (void)refreshChatTables;
- (void)homeDidAppear:(AWEUserHomeViewControllerV2 *)home;
- (void)homeDidDisappear:(AWEUserHomeViewControllerV2 *)home;
- (BOOL)shouldHideRow:(NSIndexPath *)path controller:(AWEIMChatListViewController *)controller table:(UITableView *)table;
- (void)applyHidden:(BOOL)hidden toCell:(UITableViewCell *)cell;
- (void)restoreCell:(UITableViewCell *)cell;
- (NSArray *)profileActions:(NSArray *)actions forSheet:(AWEUserActionSheetView *)sheet;
@end
NS_ASSUME_NONNULL_END
