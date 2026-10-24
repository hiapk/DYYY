#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, DYYYLikePrivacyLocation) {
    DYYYLikePrivacyLocationOutside,
    DYYYLikePrivacyLocationLikes,
    DYYYLikePrivacyLocationVideo,
};

// 密码记录与浏览会话独立于界面，便于验证退出、切号和异步验证的边界。
@interface DYYYLikePrivacyState : NSObject

@property(nonatomic, assign, readonly) BOOL enabled;
@property(nonatomic, assign, readonly) BOOL hasPIN;
@property(nonatomic, assign, readonly) BOOL unlocked;
@property(nonatomic, assign, readonly) NSUInteger generation;
@property(nonatomic, assign, readonly) NSUInteger promptGeneration;
@property(nonatomic, strong, readonly, nullable) NSError *storageError;

- (instancetype)init;
- (instancetype)initWithLoadRecord:(NSDictionary *_Nullable (^)(NSError **error))loadRecord
                       saveRecord:(BOOL (^)(NSDictionary *record, NSError **error))saveRecord;

+ (BOOL)isValidPIN:(nullable NSString *)PIN;
- (BOOL)setPIN:(NSString *)PIN currentPIN:(nullable NSString *)currentPIN error:(NSError **)error;
- (BOOL)setEnabled:(BOOL)enabled currentPIN:(NSString *)currentPIN error:(NSError **)error;
- (BOOL)verifyPIN:(nullable NSString *)PIN;
- (BOOL)unlockWithPIN:(NSString *)PIN generation:(NSUInteger)generation;
- (void)updateContext:(nullable NSString *)context location:(DYYYLikePrivacyLocation)location;
// 仅供已记录来源的受保护视频重新进入使用，离开后的会话始终保持锁定。
- (void)enterProtectedVideoWithContext:(NSString *)context;
- (void)lock;
- (NSUInteger)beginPrompt;
- (void)cancelPrompts;
- (BOOL)consumePrompt:(NSUInteger)generation;
- (void)reloadCredentialRecord;

@end

NS_ASSUME_NONNULL_END
