//
//  UIView+ppEx.m
//  PPToolKit
//
//  Created by Garenge on 2025/1/4.
//

#import "UIView+ppEx.h"

@implementation UIView (ppEx)

+ (instancetype)pp_view {
    return [[self alloc] init];
}

- (CGFloat)pp_width {
    return self.frame.size.width;
}

- (void)setPp_width:(CGFloat)pp_width {
    CGRect frame = self.frame;
    frame.size.width = pp_width;
    self.frame = frame;
}

- (CGFloat)pp_height {
    return self.frame.size.height;
}

- (void)setPp_height:(CGFloat)pp_height {
    CGRect frame = self.frame;
    frame.size.height = pp_height;
    self.frame = frame;
}

@end

@implementation UIStackView (ppEx)

- (instancetype)initWithAxis:(UILayoutConstraintAxis)axis {
    if (self = [self init]) {
        self.axis = axis;
        self.distribution = UIStackViewDistributionFill;
    }
    return self;
}
+ (instancetype)pp_viewWithAxis:(UILayoutConstraintAxis)axis {
    return [[self alloc] initWithAxis:axis];
}

@end
