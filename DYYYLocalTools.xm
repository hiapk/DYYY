#import "AwemeHeaders.h"
#import "DYYYLocalTools.h"

%group DYYYLocalChatPrivacy
%hook AWEIMChatListViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    [[DYYYLocalTools shared] refreshChatTables];
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat original = %orig;
    return [[DYYYLocalTools shared] shouldHideRow:indexPath controller:self table:tableView] ? 0.0 : original;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = %orig;
    [[DYYYLocalTools shared] applyHidden:[[DYYYLocalTools shared] shouldHideRow:indexPath controller:self table:tableView] toCell:cell];
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([[DYYYLocalTools shared] shouldHideRow:indexPath controller:self table:tableView]) return;
    %orig;
}
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    %orig;
    [[DYYYLocalTools shared] applyHidden:[[DYYYLocalTools shared] shouldHideRow:indexPath controller:self table:tableView] toCell:cell];
}
%end
%hook AWEIMChatListCommonCell
- (void)prepareForReuse {
    [[DYYYLocalTools shared] restoreCell:self];
    %orig;
}
%end
%end

%group DYYYLocalProfileActions
%hook AWEUserHomeViewControllerV2
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    [[DYYYLocalTools shared] homeDidAppear:self];
}
- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    [[DYYYLocalTools shared] homeDidDisappear:self];
}
%end
%hook AWEUserActionSheetView
- (void)show {
    if ([self respondsToSelector:@selector(actions)]) self.actions = [[DYYYLocalTools shared] profileActions:self.actions forSheet:self];
    %orig;
}
%end
%end

%ctor {
    @autoreleasepool {
        Class chat = NSClassFromString(@"AWEIMChatListViewController");
        Class cell = NSClassFromString(@"AWEIMChatListCommonCell");
        NSMethodSignature *height = [chat instanceMethodSignatureForSelector:@selector(tableView:heightForRowAtIndexPath:)];
        NSMethodSignature *rows = [chat instanceMethodSignatureForSelector:@selector(tableView:numberOfRowsInSection:)];
        NSMethodSignature *cells = [chat instanceMethodSignatureForSelector:@selector(tableView:cellForRowAtIndexPath:)];
        if (height.numberOfArguments == 4 && strcmp(height.methodReturnType, @encode(CGFloat)) == 0 && rows.numberOfArguments == 4 && strcmp(rows.methodReturnType, @encode(NSInteger)) == 0 && cells.numberOfArguments == 4 && cells.methodReturnType[0] == '@' && [cell isSubclassOfClass:UITableViewCell.class]) {
            %init(DYYYLocalChatPrivacy);
        }
        Class sheet = NSClassFromString(@"AWEUserActionSheetView");
        Class home = NSClassFromString(@"AWEUserHomeViewControllerV2");
        if ([sheet isSubclassOfClass:UIView.class] && [sheet instancesRespondToSelector:@selector(setActions:)] && [sheet instancesRespondToSelector:@selector(show)] && [home isSubclassOfClass:UIViewController.class]) {
            %init(DYYYLocalProfileActions);
        }
    }
}
