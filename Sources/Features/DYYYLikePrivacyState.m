#import "DYYYLikePrivacyState.h"
#import <CommonCrypto/CommonKeyDerivation.h>
#import <CommonCrypto/CommonCryptoError.h>
#import <Security/Security.h>

static NSString *const kDYYYLikePrivacyErrorDomain = @"com.dyyy.likes-privacy";
static const NSUInteger kDYYYLikePrivacyIterations = 120000;

@interface DYYYLikePrivacyState ()
@property(nonatomic, copy) NSDictionary *record;
@property(nonatomic, copy) NSDictionary *(^loadRecord)(NSError **error);
@property(nonatomic, copy) BOOL (^saveRecord)(NSDictionary *record, NSError **error);
@property(nonatomic, strong, readwrite) NSError *storageError;
@property(nonatomic, copy) NSString *context;
@property(nonatomic, assign) DYYYLikePrivacyLocation location;
@property(nonatomic, assign, readwrite) BOOL unlocked;
@property(nonatomic, assign, readwrite) NSUInteger generation;
@property(nonatomic, assign) NSUInteger currentPromptGeneration;
@property(nonatomic, assign) BOOL promptActive;
@end

@implementation DYYYLikePrivacyState
@synthesize unlocked = _unlocked;
@synthesize generation = _generation;
@synthesize storageError = _storageError;

#pragma mark - 密码记录

+ (NSError *)errorWithMessage:(NSString *)message {
    return [NSError errorWithDomain:kDYYYLikePrivacyErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey : message}];
}

+ (NSDictionary *)keychainQuery {
    return @{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService : kDYYYLikePrivacyErrorDomain,
        (__bridge id)kSecAttrAccount : NSBundle.mainBundle.bundleIdentifier ?: @"DYYY",
    };
}

- (instancetype)init {
    return [self initWithLoadRecord:^NSDictionary *(NSError **error) {
        NSMutableDictionary *query = [[DYYYLikePrivacyState keychainQuery] mutableCopy];
        query[(__bridge id)kSecReturnData] = @YES;
        CFTypeRef result = NULL;
        OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
        NSData *data = CFBridgingRelease(result);
        if (status == errSecItemNotFound) {
            return nil;
        }
        if (status != errSecSuccess) {
            if (error) *error = [DYYYLikePrivacyState errorWithMessage:@"无法读取喜欢页密码，请解锁手机后重试"];
            return nil;
        }
        return [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:nil error:error];
    } saveRecord:^BOOL(NSDictionary *record, NSError **error) {
        NSData *data = [NSPropertyListSerialization dataWithPropertyList:record format:NSPropertyListBinaryFormat_v1_0 options:0 error:error];
        if (!data) return NO;
        NSDictionary *query = [DYYYLikePrivacyState keychainQuery];
        NSDictionary *attributes = @{(__bridge id)kSecValueData : data};
        OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)attributes);
        if (status == errSecItemNotFound) {
            NSMutableDictionary *item = [query mutableCopy];
            [item addEntriesFromDictionary:attributes];
            item[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly;
            status = SecItemAdd((__bridge CFDictionaryRef)item, NULL);
        }
        if (status != errSecSuccess && error) {
            *error = [DYYYLikePrivacyState errorWithMessage:@"喜欢页密码保存失败，设置未更改"];
        }
        return status == errSecSuccess;
    }];
}

- (instancetype)initWithLoadRecord:(NSDictionary *(^)(NSError **))loadRecord saveRecord:(BOOL (^)(NSDictionary *, NSError **))saveRecord {
    self = [super init];
    if (self) {
        _loadRecord = [loadRecord copy];
        _saveRecord = [saveRecord copy];
        [self reloadCredentialRecord];
    }
    return self;
}

- (void)reloadCredentialRecord {
    NSError *error = nil;
    NSDictionary *record = self.loadRecord(&error);
    if (record && (![record isKindOfClass:NSDictionary.class] ||
                       ![record[@"version"] isEqual:@1] ||
                       ![record[@"enabled"] isKindOfClass:NSNumber.class] ||
                       ![record[@"salt"] isKindOfClass:NSData.class] || [record[@"salt"] length] != 16 ||
                       ![record[@"verifier"] isKindOfClass:NSData.class] || [record[@"verifier"] length] != 32)) {
        error = [self.class errorWithMessage:@"喜欢页密码记录损坏，保护保持锁定"];
        record = nil;
    }
    @synchronized(self) {
        self.record = [record copy];
        self.storageError = error;
        [self lock];
    }
}

+ (BOOL)isValidPIN:(NSString *)PIN {
    if (![PIN isKindOfClass:NSString.class] || PIN.length < 4 || PIN.length > 6) return NO;
    return [PIN rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789"] invertedSet]].location == NSNotFound;
}

+ (NSData *)verifierForPIN:(NSString *)PIN salt:(NSData *)salt {
    if (![self isValidPIN:PIN]) return nil;
    NSData *password = [PIN dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *verifier = [NSMutableData dataWithLength:32];
    int status = CCKeyDerivationPBKDF(kCCPBKDF2, password.bytes, password.length, salt.bytes, salt.length,
                                     kCCPRFHmacAlgSHA256, (unsigned int)kDYYYLikePrivacyIterations, verifier.mutableBytes, verifier.length);
    return status == kCCSuccess ? verifier : nil;
}

- (BOOL)enabled {
    @synchronized(self) {
        return self.storageError != nil || [self.record[@"enabled"] boolValue];
    }
}

- (BOOL)hasPIN {
    @synchronized(self) {
        return self.record != nil;
    }
}

- (BOOL)unlocked {
    @synchronized(self) { return _unlocked; }
}

- (NSUInteger)generation {
    @synchronized(self) { return _generation; }
}

- (NSError *)storageError {
    @synchronized(self) { return _storageError; }
}

- (NSDictionary *)recordSnapshot {
    @synchronized(self) { return self.record; }
}

- (BOOL)verifyPIN:(NSString *)PIN {
    NSDictionary *record = [self recordSnapshot];
    if (!record) return NO;
    NSData *actual = [self.class verifierForPIN:PIN salt:record[@"salt"]];
    NSData *expected = record[@"verifier"];
    if (actual.length != expected.length) return NO;
    const unsigned char *a = actual.bytes;
    const unsigned char *b = expected.bytes;
    unsigned char difference = 0;
    for (NSUInteger i = 0; i < expected.length; i++) difference |= a[i] ^ b[i];
    return difference == 0;
}

- (BOOL)save:(NSDictionary *)record error:(NSError **)error {
    NSError *saveError = nil;
    if (!self.saveRecord(record, &saveError)) {
        if (error) *error = saveError ?: [self.class errorWithMessage:@"喜欢页密码保存失败"];
        return NO;
    }
    self.record = record;
    [self lock];
    return YES;
}

- (BOOL)setPIN:(NSString *)PIN currentPIN:(NSString *)currentPIN error:(NSError **)error {
    NSDictionary *previousRecord = [self recordSnapshot];
    if (self.storageError) {
        if (error) *error = self.storageError;
        return NO;
    }
    if (![self.class isValidPIN:PIN]) {
        if (error) *error = [self.class errorWithMessage:@"密码必须为 4～6 位数字"];
        return NO;
    }
    if (previousRecord && ![self verifyPIN:currentPIN]) {
        if (error) *error = [self.class errorWithMessage:@"原密码不正确"];
        return NO;
    }
    NSMutableData *salt = [NSMutableData dataWithLength:16];
    if (SecRandomCopyBytes(kSecRandomDefault, salt.length, salt.mutableBytes) != errSecSuccess) {
        if (error) *error = [self.class errorWithMessage:@"无法生成密码记录，请重试"];
        return NO;
    }
    // 派生运算不持有会话锁，主线程的页面切换和退后台上锁不会等待它。
    NSData *verifier = [self.class verifierForPIN:PIN salt:salt];
    if (!verifier) {
        if (error) *error = [self.class errorWithMessage:@"密码处理失败，请重试"];
        return NO;
    }
    @synchronized(self) {
        if (self.record != previousRecord) {
            if (error) *error = [self.class errorWithMessage:@"密码设置已变化，请重新验证"];
            return NO;
        }
        BOOL enabled = previousRecord ? [previousRecord[@"enabled"] boolValue] : YES;
        return [self save:@{@"version" : @1, @"enabled" : @(enabled), @"salt" : salt, @"verifier" : verifier} error:error];
    }
}

- (BOOL)setEnabled:(BOOL)enabled currentPIN:(NSString *)currentPIN error:(NSError **)error {
    NSDictionary *previousRecord = [self recordSnapshot];
    if (self.storageError || ![self verifyPIN:currentPIN]) {
        if (error) *error = self.storageError ?: [self.class errorWithMessage:@"密码不正确"];
        return NO;
    }
    @synchronized(self) {
        if (self.record != previousRecord) {
            if (error) *error = [self.class errorWithMessage:@"密码设置已变化，请重新验证"];
            return NO;
        }
        NSMutableDictionary *record = [self.record mutableCopy];
        record[@"enabled"] = @(enabled);
        return [self save:record error:error];
    }
}

#pragma mark - 浏览会话

- (void)lock {
    @synchronized(self) {
        self.unlocked = NO;
        self.generation += 1;
    }
}

- (void)updateContext:(NSString *)context location:(DYYYLikePrivacyLocation)location {
    @synchronized(self) {
        BOOL sameContext = context.length > 0 && [self.context isEqualToString:context];
        if (!context.length || (location == DYYYLikePrivacyLocationVideo &&
            (!sameContext || self.location == DYYYLikePrivacyLocationOutside ||
             (self.location == DYYYLikePrivacyLocationLikes && !self.unlocked)))) {
            location = DYYYLikePrivacyLocationOutside;
        }
        BOOL sameSession = sameContext && self.location != DYYYLikePrivacyLocationOutside && location != DYYYLikePrivacyLocationOutside;
        if (!sameSession) [self lock];
        self.context = context;
        self.location = location;
    }
}

- (BOOL)unlockWithPIN:(NSString *)PIN generation:(NSUInteger)generation {
    // 派生运算可在后台进行，结果回来后必须重新检查页面会话。
    if (![self verifyPIN:PIN]) return NO;
    @synchronized(self) {
        if (!self.enabled || self.storageError || !self.context.length || self.location == DYYYLikePrivacyLocationOutside || generation != self.generation) return NO;
        self.unlocked = YES;
        return YES;
    }
}

- (void)enterProtectedVideoWithContext:(NSString *)context {
    @synchronized(self) {
        BOOL sameContext = context.length > 0 && [self.context isEqualToString:context];
        if (!sameContext || self.location == DYYYLikePrivacyLocationOutside) [self lock];
        self.context = context;
        self.location = context.length ? DYYYLikePrivacyLocationVideo : DYYYLikePrivacyLocationOutside;
    }
}

#pragma mark - 密码框回调生命周期

- (NSUInteger)promptGeneration {
    @synchronized(self) { return self.currentPromptGeneration; }
}

- (NSUInteger)beginPrompt {
    @synchronized(self) {
        self.currentPromptGeneration += 1;
        self.promptActive = YES;
        return self.currentPromptGeneration;
    }
}

- (void)cancelPrompts {
    @synchronized(self) {
        self.currentPromptGeneration += 1;
        self.promptActive = NO;
    }
}

- (BOOL)consumePrompt:(NSUInteger)generation {
    @synchronized(self) {
        if (!self.promptActive || generation != self.currentPromptGeneration) return NO;
        self.promptActive = NO;
        return YES;
    }
}

@end
