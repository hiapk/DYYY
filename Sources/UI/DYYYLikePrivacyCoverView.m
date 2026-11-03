#import "DYYYLikePrivacyCoverView.h"
#import "DYYYLikePrivacyController.h"
#import "DYYYUtils.h"

@interface DYYYLikePrivacyCoverView ()
@property(nonatomic, strong) UIImageView *emptyIcon;
@property(nonatomic, strong) UILabel *emptyLabel;
@end

@implementation DYYYLikePrivacyCoverView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.opaque = YES;
        self.clipsToBounds = YES;
        _emptyIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"heart"
                                                               withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:44 weight:UIImageSymbolWeightLight]]];
        _emptyIcon.contentMode = UIViewContentModeScaleAspectFit;
        _emptyLabel = [[UILabel alloc] init];
        _emptyLabel.text = @"暂无喜欢的作品";
        _emptyLabel.font = [UIFont systemFontOfSize:14];
        _emptyLabel.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_emptyIcon];
        [self addSubview:_emptyLabel];
        self.showsEmptyState = YES;
        [self updateAppearanceWithBackgroundColor:[DYYYUtils douyinSettingsPageBackgroundColor]];
    }
    return self;
}

- (void)setShowsEmptyState:(BOOL)showsEmptyState {
    _showsEmptyState = showsEmptyState;
    self.emptyIcon.hidden = !showsEmptyState;
    self.emptyLabel.hidden = !showsEmptyState;
}

- (void)updateAppearanceWithBackgroundColor:(UIColor *)backgroundColor {
    UIColor *resolved = [backgroundColor resolvedColorWithTraitCollection:self.traitCollection];
    if (!resolved || CGColorGetAlpha(resolved.CGColor) < 0.99) {
        resolved = [DYYYUtils usesDouyinLightBackground] ? UIColor.whiteColor : [UIColor colorWithWhite:22.0 / 255.0 alpha:1];
    }
    self.backgroundColor = resolved;
    UIColor *fallback = [DYYYUtils usesDouyinLightBackground] ? [UIColor colorWithWhite:0.6 alpha:1] : [UIColor colorWithWhite:0.5 alpha:1];
    UIColor *secondary = [DYYYUtils douyinColorNamed:@"TextTertiary" fallbackColor:fallback];
    self.emptyIcon.tintColor = secondary;
    self.emptyLabel.textColor = secondary;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat centerX = CGRectGetMidX(self.bounds);
    CGFloat centerY = CGRectGetMinY(self.bounds) + self.bounds.size.height * 0.43;
    self.emptyIcon.frame = CGRectMake(centerX - 28, centerY - 42, 56, 56);
    self.emptyLabel.frame = CGRectMake(20, centerY + 26, MAX(0, self.bounds.size.width - 40), 24);
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}
- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    if (motion == UIEventSubtypeMotionShake && [[DYYYLikePrivacyController shared] handleShakeInWindow:self.window]) return;
    [super motionEnded:motion withEvent:event];
}
@end
