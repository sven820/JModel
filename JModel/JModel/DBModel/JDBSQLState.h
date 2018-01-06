//
//  JDBSQLState.h
//
//  Created by jinxiaofei on 16/3/22.
//  Copyright © 2016年 LK. All rights reserved.
//

#import "JDBModel.h"

typedef NS_ENUM(NSInteger ,QueryType){
    WHERE = 0,
    AND,
    OR
};


@interface JDBSQLState : NSObject

@property (nonatomic, assign) QueryType type;
/**
 *  查询方法
 *
 *  @param obj   model类
 *  @param type  查询类型
 *  @param key   key
 *  @param opt   条件
 *  @param value 值
 */
- (JDBSQLState *)object:(Class)obj
                       type:(QueryType)type
                        key:(id)key
                        opt:(NSString *)opt
                      value:(id)value;
/**
 *  生成查询语句
 */
-(NSString *)sqlOptionStr;



//todo sort 对排序语句

@end
