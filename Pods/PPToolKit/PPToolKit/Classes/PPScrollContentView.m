//
//  PPScrollContentView.m
//  HiconicsEMS
//
//  Created by ex_liuzp9 on 2024/7/18.
//

#import "PPScrollContentView.h"

@implementation PPScrollContentView

- (instancetype)initWithFrame:(CGRect)frame {
  if ([super initWithFrame:frame]) {
    self.axis = UILayoutConstraintAxisVertical;
    self.showsVerticalScrollIndicator = NO;
    self.showsHorizontalScrollIndicator = NO;
  }
  return self;
}

@synthesize axis = _axis;

- (UILayoutConstraintAxis)axis {
  return self.contentView.axis;
}

- (void)setAxis:(UILayoutConstraintAxis)axis {
  _axis = axis;
  self.contentView.axis = axis;

  if (axis == UILayoutConstraintAxisVertical) {
    [self.contentView mas_remakeConstraints:^(MASConstraintMaker *make) {
      make.left.width.top.bottom.equalTo(self);
    }];
  } else {
    [self.contentView mas_remakeConstraints:^(MASConstraintMaker *make) {
      make.left.height.top.right.equalTo(self);
    }];
  }
}

- (UIStackView *)contentView {
    if (nil == _contentView) {
        UIStackView *contentView = [UIStackView pp_viewWithAxis:UILayoutConstraintAxisVertical];
        [self addSubview:contentView];
        _contentView = contentView;
        [contentView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.width.top.bottom.equalTo(self);
        }];
    }
    return _contentView;
}

- (void)setContentInset:(UIEdgeInsets)contentInset {
  [super setContentInset:contentInset];
  if (self.axis == UILayoutConstraintAxisVertical) {
    [self.contentView mas_updateConstraints:^(MASConstraintMaker *make) {
      make.width.equalTo(self).offset(-(self.contentInset.left + self.contentInset.right));
    }];
  } else {
    [self.contentView mas_updateConstraints:^(MASConstraintMaker *make) {
      make.height.equalTo(self).offset(-(self.contentInset.top + self.contentInset.bottom));
    }];
  }
}

- (void)layoutIfNeeded {
  [super layoutIfNeeded];

  self.pp_width = self.contentView.pp_width + self.contentInset.left + self.contentInset.right;
  self.pp_height = self.contentView.pp_height + self.contentInset.top + self.contentInset.bottom;
}

#pragma mark - func

- (void)addArrangedSubview:(UIView *)view {
  [self.contentView addArrangedSubview:view];
}

- (void)removeAllSubviews {
  for (UIView *view in self.contentView.subviews) {
    [view removeFromSuperview];
  }
}

@end
