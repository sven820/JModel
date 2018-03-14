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

+ (Class)tableClass
{
    Class cls = self.class;
    Class supercls = cls.superclass;
    BOOL end = NO;
    do {
        if ([supercls isEqual:[DBModel class]]) {
            end = YES;
            break;
        }
        if ([supercls isEqual:[NSObject class]]) {
            end = YES;
            cls = nil;
            break;
        }
        cls = supercls;
        supercls = cls.superclass;
    } while (!end);

    return cls;
}
@end
