//
//  NSString+ppEx.h
//  PicData
//
//  Created by 鹏鹏 on 2022/8/22.
//  Copyright © 2022 garenge. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (ppEx)

/// 格式化文件大小, 将字节大小转换为合适的单位
+ (NSString *)pp_fileSizeFormat:(long long)value;

@end

NS_ASSUME_NONNULL_END
