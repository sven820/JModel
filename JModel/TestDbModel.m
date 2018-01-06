//
//  TestDbModel.m
//  JModel
//
//  Created by 靳小飞 on 2018/1/5.
//  Copyright © 2018年 靳小飞. All rights reserved.
//

#import "TestDbModel.h"

@implementation TestDbModel

#pragma mark - 可选
+ (NSInteger)dbKind
{
    return DbKind_public;
}
+ (NSDictionary *)describeColumnDict
{
    return @{
             @"pkId" : [JDBColumnDes primaryKeyDesc], //修饰主键
             @"nonDbKey" : [JDBColumnDes uselessDesc], //修饰非数据库字段
             };
}
//默认@[className]，支持model -> table 一对多 （比如你想将消息记录到两个表，一个个人消息，一个群消息）
+ (NSArray *)tableNames
{
    return @[@"table1", @"table2"];
}
//一对多时，对象存储最终表名，默认tableNames first，单独重写无效(可能导致未知错误)，需配合tableNames
- (NSString *)tableName
{
    if (self.pkId > 10000) {
        return @"table1";
    }
    return @"table2";
}
+ (NSString *)dateFormat
{
    return @"yyyy-MM-dd>> HH:mm:ss";
}
@end


@implementation Student
+ (NSDictionary *)describeColumnDict
{
    return @{
#warning 待测试
             //联合主键
             @"name" : [JDBColumnDes unionPrimaryKeyDesc],
             @"className" : [JDBColumnDes unionPrimaryKeyDesc],
             };
}
+ (NSInteger)dbKind
{
    return DbKind_user;
}
@end

@implementation Teacher
+ (NSInteger)dbKind
{
    return DbKind_user;
}
@end
