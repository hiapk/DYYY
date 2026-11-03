#import "DYYYConversationPrivacyPolicy.h"
@implementation DYYYConversationPrivacyPolicy
+ (NSString *)normalizedUID:(id)value {
    if (![value isKindOfClass:NSString.class]) return nil;
    NSString *uid = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (uid.length == 0 || uid.length > 32) return nil;
    if ([uid rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789"] invertedSet]].location != NSNotFound) return nil;
    return uid;
}

+ (NSNumber *)integerValue:(NSString *)key fromChat:(id)chat {
    SEL selector = NSSelectorFromString(key);
    if (![chat respondsToSelector:selector]) return nil;
    NSMethodSignature *signature = [chat methodSignatureForSelector:selector];
    if (signature.numberOfArguments != 2 || strlen(signature.methodReturnType) != 1 || !strchr("BcsilqCSILQ", signature.methodReturnType[0])) return nil;
    @try {
        id result = [chat valueForKey:key];
        return [result isKindOfClass:NSNumber.class] ? result : nil;
    } @catch (NSException *exception) { return nil; }
}

+ (BOOL)shouldHideChat:(id)chat hiddenUIDs:(NSSet<NSString *> *)uids enabled:(BOOL)enabled {
    if (!enabled || !chat || uids.count == 0 || ![self integerValue:@"isC2CConversation" fromChat:chat].boolValue) return NO;
    NSMethodSignature *signature = [chat methodSignatureForSelector:NSSelectorFromString(@"peerID")];
    if (signature.numberOfArguments != 2 || signature.methodReturnType[0] != '@') return NO;
    NSString *uid;
    @try { uid = [self normalizedUID:[chat valueForKey:@"peerID"]]; }
    @catch (NSException *exception) { return NO; }
    if (!uid || ![uids containsObject:uid]) return NO;
    for (NSString *key in @[@"unreadCount", @"realUnreadCount", @"dotUnreadCount", @"threadUnreadCount"]) {
        NSNumber *count = [self integerValue:key fromChat:chat];
        if (!count || count.longLongValue != 0) return NO;
    }
    for (NSString *key in @[@"subscribeUnreadCountOnMute", @"unreadMention", @"chatCellDisplayUnreadCount", @"chatCellDisplayDotUnreadCount"]) {
        if ([chat respondsToSelector:NSSelectorFromString(key)]) {
            NSNumber *count = [self integerValue:key fromChat:chat];
            if (!count || count.longLongValue != 0) return NO;
        }
    }
    return YES;
}

+ (BOOL)shouldHideRow:(NSInteger)row section:(NSInteger)section nativeCount:(NSInteger)count chats:(NSArray *)chats hiddenUIDs:(NSSet<NSString *> *)uids enabled:(BOOL)enabled {
    if (section != 0 || ![chats isKindOfClass:NSArray.class] || count < 0 || count > (NSInteger)chats.count || row < 0 || row >= count) return NO;
    return [self shouldHideChat:chats[(NSUInteger)row] hiddenUIDs:uids enabled:enabled];
}
@end
