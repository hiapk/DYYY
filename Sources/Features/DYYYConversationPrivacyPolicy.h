#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface DYYYConversationPrivacyPolicy : NSObject
+ (nullable NSString *)normalizedUID:(nullable id)value;
+ (BOOL)shouldHideChat:(nullable id)chat hiddenUIDs:(NSSet<NSString *> *)uids enabled:(BOOL)enabled;
+ (BOOL)shouldHideRow:(NSInteger)row section:(NSInteger)section nativeCount:(NSInteger)count chats:(nullable NSArray *)chats hiddenUIDs:(NSSet<NSString *> *)uids enabled:(BOOL)enabled;
@end
NS_ASSUME_NONNULL_END
