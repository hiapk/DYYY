#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

// 本地工具数据独立于设置导出；账户只参与文件名摘要，不明文写入文件名。
@interface DYYYLocalRecordStore : NSObject
@property(nonatomic, strong, readonly) NSURL *fileURL;
- (instancetype)initWithDirectoryURL:(NSURL *)directory namespace:(NSString *)name accountID:(NSString *)accountID;
- (nullable NSArray<NSDictionary *> *)recordsWithError:(NSError **)error;
- (BOOL)updateRecords:(NSArray<NSDictionary *> *_Nullable (^)(NSArray<NSDictionary *> *records, NSError **error))update error:(NSError **)error;
@end
NS_ASSUME_NONNULL_END
