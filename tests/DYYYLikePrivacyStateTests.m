#import <Foundation/Foundation.h>
#import <math.h>
#import "DYYYLikePrivacyState.h"
#import "DYYYLikePrivacyPagePolicy.h"

@interface DYYYTestSegmentItem : NSObject
@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy) NSString *selectedTitle;
@end
@implementation DYYYTestSegmentItem
@end

#define CHECK(...) NSCAssert((__VA_ARGS__), @"测试失败：%s", #__VA_ARGS__)

int main(void) {
    @autoreleasepool {
        // 标签识别：按显示顺序找到“喜欢”，兼容数量后缀、富文本与分段数据模型。
        CHECK([DYYYLikePrivacyPagePolicy likeTabIndexInTitles:@[@"作品 3", @"日常", @"收藏", @"喜欢"]] == 3);
        CHECK([DYYYLikePrivacyPagePolicy likeTabIndexInTitles:@[@"作品", @" 喜欢 128"]] == 1);
        CHECK([DYYYLikePrivacyPagePolicy likeTabIndexInTitles:@[@"作品", @"🔒喜欢"]] == 1);
        CHECK([DYYYLikePrivacyPagePolicy likeTabIndexInTitles:@[@"作品", @"喜欢\n1.2万"]] == 1);
        CHECK([DYYYLikePrivacyPagePolicy likeTabIndexInTitles:@[[[NSAttributedString alloc] initWithString:@"喜欢"]]] == 0);
        DYYYTestSegmentItem *works = [DYYYTestSegmentItem new];
        works.title = @"作品";
        DYYYTestSegmentItem *likes = [DYYYTestSegmentItem new];
        likes.selectedTitle = @"喜欢 5";
        CHECK([DYYYLikePrivacyPagePolicy likeTabIndexInTitles:@[works, likes]] == 1);
        CHECK([DYYYLikePrivacyPagePolicy likeTabIndexInTitles:@[@"作品", @"收藏", @"我喜欢的音乐"]] == NSNotFound);
        CHECK([DYYYLikePrivacyPagePolicy likeTabIndexInTitles:@[@1, NSNull.null]] == NSNotFound);
        CHECK([DYYYLikePrivacyPagePolicy likeTabIndexInTitles:nil] == NSNotFound);
        CHECK([DYYYLikePrivacyPagePolicy likeTabIndexInTitles:(NSArray *)@"喜欢"] == NSNotFound);

        // 遮挡几何：从分段标签下沿开始覆盖喜欢页；标签不在页面范围内时覆盖整页。
        CGRect page = CGRectMake(750, 0, 375, 700);
        CHECK(CGRectEqualToRect([DYYYLikePrivacyPagePolicy coverFrameForPageFrame:page contentTop:320], CGRectMake(750, 320, 375, 380)));
        CHECK(CGRectEqualToRect([DYYYLikePrivacyPagePolicy coverFrameForPageFrame:page contentTop:-40], page));
        CHECK(CGRectEqualToRect([DYYYLikePrivacyPagePolicy coverFrameForPageFrame:page contentTop:-CGFLOAT_MAX], page));
        CHECK(CGRectGetHeight([DYYYLikePrivacyPagePolicy coverFrameForPageFrame:page contentTop:900]) == 0);
        CHECK(CGRectEqualToRect([DYYYLikePrivacyPagePolicy coverFrameForPageFrame:page contentTop:NAN], page));
        for (NSString *PIN in @[@"1234", @"01234", @"000001"]) CHECK([DYYYLikePrivacyState isValidPIN:PIN]);
        CHECK(![DYYYLikePrivacyState isValidPIN:nil]);
        for (NSString *PIN in @[@"", @"123", @"1234567", @"１２３４", @"12a4", @"1234 ", @"12\n34"]) CHECK(![DYYYLikePrivacyState isValidPIN:PIN]);

        __block NSDictionary *stored = nil;
        __block BOOL failWrites = NO;
        NSDictionary *(^load)(NSError **) = ^NSDictionary *(NSError **error) { return stored; };
        BOOL (^save)(NSDictionary *, NSError **) = ^BOOL(NSDictionary *record, NSError **error) {
            if (failWrites) return NO;
            stored = [record copy];
            return YES;
        };
        DYYYLikePrivacyState *state = [[DYYYLikePrivacyState alloc] initWithLoadRecord:load saveRecord:save];
        NSUInteger stalePrompt = [state beginPrompt];
        [state cancelPrompts];
        NSUInteger currentPrompt = [state beginPrompt];
        CHECK(![state consumePrompt:stalePrompt]);
        CHECK([state consumePrompt:currentPrompt]);
        CHECK(![state consumePrompt:currentPrompt]);
        CHECK(!state.enabled && !state.hasPIN && !state.unlocked);
        CHECK(![state setPIN:@"123" currentPIN:nil error:nil]);
        CHECK([state setPIN:@"012345" currentPIN:nil error:nil]);
        CHECK(state.enabled && state.hasPIN && !state.unlocked);
        CHECK(![state verifyPIN:nil]);
        CHECK(stored[@"password"] == nil && stored[@"PIN"] == nil);
        CHECK([state verifyPIN:@"012345"] && ![state verifyPIN:@"12345"]);

        [state updateContext:@"account-a" location:DYYYLikePrivacyLocationLikes];
        CHECK(![state unlockWithPIN:@"999999" generation:state.generation]);
        CHECK([state unlockWithPIN:@"012345" generation:state.generation]);
        [state updateContext:@"account-a" location:DYYYLikePrivacyLocationVideo];
        CHECK(state.unlocked);
        [state lock];
        CHECK([state unlockWithPIN:@"012345" generation:state.generation]);
        [state updateContext:@"account-a" location:DYYYLikePrivacyLocationLikes];
        CHECK(state.unlocked);

        NSUInteger challenge = state.generation;
        [state lock];
        CHECK(!state.unlocked);
        CHECK(![state unlockWithPIN:@"012345" generation:challenge]);
        CHECK([state unlockWithPIN:@"012345" generation:state.generation]);
        [state updateContext:@"account-a" location:DYYYLikePrivacyLocationOutside];
        CHECK(!state.unlocked);
        CHECK(![state unlockWithPIN:@"012345" generation:state.generation]);
        [state updateContext:@"account-a" location:DYYYLikePrivacyLocationVideo];
        CHECK(![state unlockWithPIN:@"012345" generation:state.generation]);
        [state enterProtectedVideoWithContext:@"account-a"];
        CHECK(!state.unlocked);
        CHECK([state unlockWithPIN:@"012345" generation:state.generation]);
        [state updateContext:@"account-b" location:DYYYLikePrivacyLocationLikes];
        CHECK(!state.unlocked);
        [state updateContext:nil location:DYYYLikePrivacyLocationLikes];
        CHECK(![state unlockWithPIN:@"012345" generation:state.generation]);
        [state updateContext:@"account-a" location:DYYYLikePrivacyLocationLikes];
        challenge = state.generation;
        [state updateContext:@"account-b" location:DYYYLikePrivacyLocationLikes];
        CHECK(![state unlockWithPIN:@"012345" generation:challenge]);

        CHECK(![state setEnabled:NO currentPIN:@"999999" error:nil] && state.enabled);
        failWrites = YES;
        CHECK(![state setEnabled:NO currentPIN:@"012345" error:nil] && state.enabled);
        CHECK(![state setPIN:@"4444" currentPIN:@"012345" error:nil]);
        CHECK([state verifyPIN:@"012345"]);
        failWrites = NO;
        CHECK([state setEnabled:NO currentPIN:@"012345" error:nil] && !state.enabled);
        CHECK(![state setPIN:@"4444" currentPIN:nil error:nil]);
        CHECK([state setPIN:@"4444" currentPIN:@"012345" error:nil]);
        CHECK(!state.enabled && ![state verifyPIN:@"012345"] && [state verifyPIN:@"4444"]);
        CHECK([state setEnabled:YES currentPIN:@"4444" error:nil]);

        state = [[DYYYLikePrivacyState alloc] initWithLoadRecord:load saveRecord:save];
        CHECK(state.enabled && !state.unlocked && [state verifyPIN:@"4444"]);
        NSDictionary *validRecord = stored;
        __block BOOL protectedDataAvailable = NO;
        DYYYLikePrivacyState *recoverable = [[DYYYLikePrivacyState alloc] initWithLoadRecord:^NSDictionary *(NSError **error) {
            if (protectedDataAvailable) return validRecord;
            *error = [NSError errorWithDomain:@"test-keychain-locked" code:1 userInfo:nil];
            return nil;
        } saveRecord:save];
        CHECK(recoverable.storageError && recoverable.enabled);
        protectedDataAvailable = YES;
        [recoverable reloadCredentialRecord];
        CHECK(!recoverable.storageError && recoverable.enabled && !recoverable.unlocked && [recoverable verifyPIN:@"4444"]);
        // 普通配置清空、导入和进程重启不会清除独立的密码记录。
        stored = @{@"version" : @1, @"enabled" : @NO};
        state = [[DYYYLikePrivacyState alloc] initWithLoadRecord:load saveRecord:save];
        CHECK(state.enabled && state.storageError && ![state setPIN:@"5555" currentPIN:nil error:nil]);
        state = [[DYYYLikePrivacyState alloc] initWithLoadRecord:^NSDictionary *(NSError **error) {
            *error = [NSError errorWithDomain:@"test" code:1 userInfo:nil];
            return nil;
        } saveRecord:save];
        CHECK(state.enabled && !state.unlocked && ![state setEnabled:NO currentPIN:@"4444" error:nil]);
        puts("PASS: native ownership, PIN validation, session locking, prompt lifetime, account isolation");
    }
    return 0;
}
