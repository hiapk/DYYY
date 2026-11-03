#import "DYYYAdChapterSkipPolicy.h"

#import <objc/runtime.h>
#import <string.h>

NSString *const DYYYAutoSkipAdChapterKey = @"DYYYAutoSkipAdChapter";

@implementation DYYYAdChapterSkipPolicy

+ (BOOL)isEnabled {
    return [NSUserDefaults.standardUserDefaults boolForKey:DYYYAutoSkipAdChapterKey];
}

+ (BOOL)supportsSkipToastForClass:(Class)cls {
    SEL selector = NSSelectorFromString(@"showAdSkipChapterToastWithStartTime:endTime:");
    Method method = cls ? class_getInstanceMethod(cls, selector) : NULL;
    if (!method) return NO;
    NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)];
    return signature.numberOfArguments == 4 && strcmp(signature.methodReturnType, @encode(void)) == 0 &&
           strcmp([signature getArgumentTypeAtIndex:2], @encode(double)) == 0 &&
           strcmp([signature getArgumentTypeAtIndex:3], @encode(double)) == 0;
}

+ (NSArray *)autoSkipIndexesWithOriginal:(NSArray *)original allAdIndexes:(NSArray *)allAdIndexes enabled:(BOOL)enabled {
    if (!enabled || ![allAdIndexes isKindOfClass:NSArray.class] || allAdIndexes.count == 0) return original;
    for (id index in allAdIndexes) {
        // 宿主按 integerValue 比较章节序号，非数字时不改写，避免宿主校验失败后整段失效。
        if (![index isKindOfClass:NSNumber.class]) return original;
    }
    return [allAdIndexes copy];
}

@end
