#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface DYYYBookmarkRecord : NSObject
+ (nullable NSDictionary *)recordWithType:(NSString *)type identifier:(id)identifier title:(nullable NSString *)title author:(nullable NSString *)author;
+ (nullable NSString *)routeForRecord:(NSDictionary *)record;
+ (NSArray<NSDictionary *> *)recordsByUpserting:(NSDictionary *)record intoRecords:(NSArray<NSDictionary *> *)records;
@end
NS_ASSUME_NONNULL_END
