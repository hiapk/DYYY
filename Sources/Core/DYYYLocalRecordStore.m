#import "DYYYLocalRecordStore.h"
#import <CommonCrypto/CommonDigest.h>

@interface DYYYLocalRecordStore ()
@property(nonatomic, strong, readwrite) NSURL *fileURL;
@end

@implementation DYYYLocalRecordStore

+ (dispatch_queue_t)storageQueue {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ queue = dispatch_queue_create("com.dyyy.local-records", DISPATCH_QUEUE_SERIAL); });
    return queue;
}

+ (NSError *)invalidDataError {
    return [NSError errorWithDomain:@"DYYYLocalRecords" code:1 userInfo:@{NSLocalizedDescriptionKey:@"本地数据格式异常，已保留原文件，请备份后处理"}];
}

- (instancetype)initWithDirectoryURL:(NSURL *)directory namespace:(NSString *)name accountID:(NSString *)accountID {
    self = [super init];
    if (self) {
        NSData *identity = [[NSString stringWithFormat:@"%@\n%@", name, accountID] dataUsingEncoding:NSUTF8StringEncoding];
        unsigned char digest[CC_SHA256_DIGEST_LENGTH];
        CC_SHA256(identity.bytes, (CC_LONG)identity.length, digest);
        NSMutableString *filename = [NSMutableString string];
        for (NSUInteger index = 0; index < sizeof(digest); index++) [filename appendFormat:@"%02x", digest[index]];
        _fileURL = [directory URLByAppendingPathComponent:[filename stringByAppendingString:@".json"]];
    }
    return self;
}

// 只由串行队列调用；损坏文件不会被当成空列表覆盖。
- (NSArray<NSDictionary *> *)readRecords:(NSError **)error {
    if (![NSFileManager.defaultManager fileExistsAtPath:self.fileURL.path]) return @[];
    NSData *data = [NSData dataWithContentsOfURL:self.fileURL options:0 error:error];
    if (!data) return nil;
    if (data.length > 4 * 1024 * 1024) {
        if (error) *error = [self.class invalidDataError];
        return nil;
    }
    id envelope = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if (![envelope isKindOfClass:NSDictionary.class]) {
        if (error && !*error) *error = [self.class invalidDataError];
        return nil;
    }
    NSArray *records = envelope[@"records"];
    if (![envelope[@"version"] isEqual:@1] || ![records isKindOfClass:NSArray.class] || records.count > 2000) {
        if (error) *error = [self.class invalidDataError];
        return nil;
    }
    for (id record in records) {
        if (![record isKindOfClass:NSDictionary.class]) {
            if (error) *error = [self.class invalidDataError];
            return nil;
        }
    }
    return records;
}

- (NSArray<NSDictionary *> *)recordsWithError:(NSError **)error {
    __block NSArray *records;
    __block NSError *failure;
    dispatch_sync([self.class storageQueue], ^{ records = [self readRecords:&failure]; });
    if (error) *error = failure;
    return records;
}

- (BOOL)updateRecords:(NSArray<NSDictionary *> *(^)(NSArray<NSDictionary *> *, NSError **))update error:(NSError **)error {
    __block BOOL success = NO;
    __block NSError *failure;
    dispatch_sync([self.class storageQueue], ^{
        NSArray *oldRecords = [self readRecords:&failure];
        if (!oldRecords) return;
        NSArray *records = update(oldRecords, &failure);
        if (!records || failure) return;
        BOOL valid = [records isKindOfClass:NSArray.class] && records.count <= 2000;
        for (id record in records) valid = valid && [record isKindOfClass:NSDictionary.class];
        NSDictionary *envelope = @{@"version":@1, @"records":records};
        if (!valid || ![NSJSONSerialization isValidJSONObject:envelope]) {
            failure = [self.class invalidDataError];
            return;
        }
        NSData *data = [NSJSONSerialization dataWithJSONObject:envelope options:0 error:&failure];
        if (!data) return;
        if (data.length > 4 * 1024 * 1024) {
            failure = [self.class invalidDataError];
            return;
        }
        NSURL *directory = [self.fileURL URLByDeletingLastPathComponent];
        if (![NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:&failure]) return;
        success = [data writeToURL:self.fileURL options:NSDataWritingAtomic error:&failure];
        if (success) [NSFileManager.defaultManager setAttributes:@{NSFilePosixPermissions:@0600} ofItemAtPath:self.fileURL.path error:nil];
    });
    if (error) *error = failure;
    return success;
}
@end
