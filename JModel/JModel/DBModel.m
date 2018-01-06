//
//  DBModel.m
//
//  Created by jinxiaofei on 17/3/7.
//  Copyright © 2017年 tuoheng.huahuo. All rights reserved.
//

#import "DBModel.h"

@implementation DBModel

+ (FMDatabaseQueue *)dbQueue
{
    NSInteger kind = [self dbKind];
    return DBHelper(kind).dbQueue;
}

+ (NSInteger)dbKind
{
    return 0;
}
@end
