#import "DYYYBookmarkRecord.h"
@implementation DYYYBookmarkRecord
+ (NSString *)validIdentifier:(id)value {
    if (![value isKindOfClass:NSString.class] || [value length] == 0 || [value length] > 32) return nil;
    return [value rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789"] invertedSet]].location == NSNotFound ? value : nil;
}
+ (NSString *)limitedText:(id)value length:(NSUInteger)length {
    if (![value isKindOfClass:NSString.class]) return @"";
    return [value length] > length ? [value substringToIndex:length] : value;
}
+ (NSDictionary *)recordWithType:(NSString *)type identifier:(id)identifier title:(NSString *)title author:(NSString *)author {
    NSString *stableID = [self validIdentifier:identifier];
    if (!stableID || ![@[@"video", @"profile"] containsObject:type]) return nil;
    return @{@"id":[NSString stringWithFormat:@"%@:%@", type, stableID], @"type":type, @"identifier":stableID,
             @"title":[self limitedText:title length:1000], @"author":[self limitedText:author length:100],
             @"savedAt":@(NSDate.date.timeIntervalSince1970)};
}
+ (NSString *)routeForRecord:(NSDictionary *)record {
    if (![record isKindOfClass:NSDictionary.class]) return nil;
    NSString *identifier = [self validIdentifier:record[@"identifier"]];
    if (!identifier) return nil;
    if ([record[@"type"] isEqual:@"video"]) return [@"snssdk1128://aweme/detail/" stringByAppendingString:identifier];
    if ([record[@"type"] isEqual:@"profile"]) return [@"snssdk1128://user/profile/" stringByAppendingString:identifier];
    return nil;
}
+ (NSArray *)recordsByUpserting:(NSDictionary *)record intoRecords:(NSArray *)records {
    NSMutableDictionary *merged = [record mutableCopy];
    NSMutableArray *result = [NSMutableArray array];
    for (NSDictionary *old in records) {
        if ([old[@"id"] isEqual:record[@"id"]]) {
            for (NSString *key in @[@"note", @"category"]) if (!merged[key] && old[key]) merged[key] = old[key];
        } else [result addObject:old];
    }
    [result insertObject:[merged copy] atIndex:0];
    return result;
}
@end
