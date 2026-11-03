#import "DYYYLikePrivacyPagePolicy.h"
#import <math.h>

static NSString *const kDYYYLikeTabTitle = @"喜欢";

@implementation DYYYLikePrivacyPagePolicy

#pragma mark - 标签识别

+ (NSString *)stringFromTitle:(id)title {
    if ([title isKindOfClass:NSString.class]) return title;
    if ([title isKindOfClass:NSAttributedString.class]) return [(NSAttributedString *)title string];
    return nil;
}

+ (NSString *)titleForItem:(id)item {
    NSString *title = [self stringFromTitle:item];
    if (title) return title;
    for (NSString *key in @[@"title", @"selectedTitle"]) {
        if (![item respondsToSelector:NSSelectorFromString(key)]) continue;
        title = [self stringFromTitle:[item valueForKey:key]];
        if (title.length) return title;
    }
    return nil;
}

+ (NSInteger)likeTabIndexInTitles:(NSArray *)titles {
    if (![titles isKindOfClass:NSArray.class]) return NSNotFound;
    NSCharacterSet *nonLetters = NSCharacterSet.letterCharacterSet.invertedSet;
    for (NSUInteger index = 0; index < titles.count; index++) {
        // 去掉首尾的数量、空白与图标字符，兼容“喜欢 12”“🔒喜欢”等标题。
        NSString *title = [[self titleForItem:titles[index]] stringByTrimmingCharactersInSet:nonLetters];
        if ([title hasPrefix:kDYYYLikeTabTitle]) return (NSInteger)index;
    }
    return NSNotFound;
}

#pragma mark - 遮挡几何

+ (CGRect)coverFrameForPageFrame:(CGRect)pageFrame contentTop:(CGFloat)contentTop {
    if (CGRectIsEmpty(pageFrame) || isnan(contentTop)) return pageFrame;
    CGFloat top = MAX(CGRectGetMinY(pageFrame), contentTop);
    CGFloat height = MAX(0, CGRectGetMaxY(pageFrame) - top);
    return CGRectMake(CGRectGetMinX(pageFrame), top, CGRectGetWidth(pageFrame), height);
}

@end
