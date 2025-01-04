//
//  UIView+ppEx.h
//  PPToolKit
//
//  Created by Garenge on 2025/1/4.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIView (ppEx)

+ (instancetype)pp_view;

@property (nonatomic, assign) CGFloat pp_width;
@property (nonatomic, assign) CGFloat pp_height;

@end

@interface UIStackView (ppEx)

- (instancetype)initWithAxis:(UILayoutConstraintAxis)axis;
+ (instancetype)pp_viewWithAxis:(UILayoutConstraintAxis)axis;

@end

NS_ASSUME_NONNULL_END
