//
//  PPScrollContentView.h
//  HiconicsEMS
//
//  Created by ex_liuzp9 on 2024/7/18.
//

#import <UIKit/UIKit.h>
#import "UIView+ppEx.h"
#import <Masonry/Masonry.h>

NS_ASSUME_NONNULL_BEGIN

// 一个外套scrollview的stackView, 实现多个子控件排布滚动, 可以设置内边距 contentInset
@interface PPScrollContentView : UIScrollView

/// 内部排列方向, 也就是滚动方向, 默认垂直
@property (nonatomic, assign) UILayoutConstraintAxis axis;

/// 内部的stackView, 自由设置属性, 懒加载, 不可移除
@property (nonatomic, strong) UIStackView *contentView;

/* 快速添加内容view */
- (void)addArrangedSubview:(UIView *)view;

/// 一键移除所有子控件, 除了contentView
- (void)removeAllSubviews;

@end

NS_ASSUME_NONNULL_END
