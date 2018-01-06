//
//  DBModel.h
//
//  Created by jinxiaofei on 17/3/7.
//  Copyright © 2017年 tuoheng.huahuo. All rights reserved.
//

#import "JDBModel.h"
#import "DBManager.h"

@interface DBModel : JDBModel
/**
 * db Model 类型, 请自定义枚举，有几个kind就有几个db，请重写，默认为0
 */
+ (NSInteger)dbKind;
@end
