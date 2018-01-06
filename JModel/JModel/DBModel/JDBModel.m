//
//  JDBModel.m
//
//  Created by jinxiaofei on 16/3/21.
//  thank for github https://github.com/544523660/LKFMDB

#import "JDBModel.h"
#import "JDBColumnDes.h"
#import <objc/runtime.h>

static JModelConfig conf = {0};

@interface JDBModel ()

/** 主键(include联合主键)*/
@property (nonatomic, strong, getter=getPkDescs) NSArray<JDBColumnDes *> *pkDescs;
@end

@implementation JDBModel
+ (void)setJmodelConfig:(void(^)(JModelConfig *defaultConf))config
{
    JModelConfig dConf = {0};
    dConf.log = NO;
    dConf.rollback_once_err = NO;
    if (config) {
        config(&dConf);
    }
    conf = dConf;
}
- (instancetype)init
{
    self = [super init];
    if (self) {
        
        NSDictionary *dic = [self.class getAllProperties];
        _propertyNames = [[NSMutableArray alloc] initWithArray:[dic objectForKey:@"name"]];
        _columeTypes = [[NSMutableArray alloc] initWithArray:[dic objectForKey:@"type"]];
        _columeNames = [[NSMutableArray alloc] initWithArray:[self.class getColumnNames]];
    }
    
    return self;
}

#pragma mark - base method
/** 数据库中是否存在表 */
+ (BOOL)isTableExist
{
    __block BOOL res = NO;
    for (NSString *tableName in [self tableNames]) {
        [[self getDbqueue] inDatabase:^(FMDatabase *db) {
            res = [db tableExists:tableName];
        }];
    }
    
    return res;
}
- (BOOL)isTableExist
{
    __block BOOL res = NO;
    [[self.class getDbqueue] inDatabase:^(FMDatabase *db) {
        res = [db tableExists:[self tableName]];
    }];
    return res;
}
+ (BOOL)createTable
{
    __block BOOL res = YES;
    for (NSString *tableName in [self tableNames]) {
        res = [self p_createTable:tableName];
    }
    return res;
}
/**
 * 创建表
 */
+ (BOOL)p_createTable:(NSString *)tableName
{
    __block BOOL res = YES;
    //创建表
    NSString *columeAndType = [self.class getColumeAndTypeString];
    NSString *create_table_sql = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@(%@);",tableName,columeAndType];
    [[self dbQueue] inTransaction:^(FMDatabase *db, BOOL *rollback) {
        if (![db executeUpdate:create_table_sql]) {
            res = NO;
            [self.class jdblog:@"db create table fail %@", tableName];
            *rollback = YES;
            return ;
        };
    }];
    
    NSMutableArray *columns = [NSMutableArray array];
    [[self dbQueue] inDatabase:^(FMDatabase *db) {
        FMResultSet *resultSet = [db getTableSchema:tableName];
        while ([resultSet next]) {
            NSString *column = [resultSet stringForColumn:@"name"];
            [columns addObject:column];
        }
    }];
    NSDictionary *dict = [self.class getAllProperties];
    NSArray *properties = [self.class getColumnNames];
    
    //添加列
    [[self dbQueue] inTransaction:^(FMDatabase *db, BOOL *rollback) {
        //过滤数组 add new sqlite 不支持多列添加
        NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"NOT (SELF IN %@)",columns];
        NSArray *resultArray = [properties filteredArrayUsingPredicate:filterPredicate];
        for (NSString *column in resultArray) {
            NSUInteger index = [properties indexOfObject:column];
            NSString *proType = [[dict objectForKey:@"type"] objectAtIndex:index];
            NSString *fieldSql = [NSString stringWithFormat:@"%@ %@",column,proType];
            NSString *sql = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ ",tableName,fieldSql];
            if (![db executeUpdate:sql]) {
                res = NO;
                [self.class jdblog:@"add column %@ error", fieldSql];
                *rollback = YES;
            }
            //
            [columns addObject:column];
        }
    }];
    
    /* sqlite 不支持删除列，修改列，这里通过复制表达到目的
     */
    [[self dbQueue] inTransaction:^(FMDatabase *db, BOOL *rollback) {
        NSPredicate *filterPredicate_drop = [NSPredicate predicateWithFormat:@"NOT (SELF IN %@)",properties];
        NSArray *resultArray_drop = [columns filteredArrayUsingPredicate:filterPredicate_drop];
        [columns removeObjectsInArray:resultArray_drop];
        if (resultArray_drop.count)
        {
            NSString *temp_name = [NSString stringWithFormat:@"%@_temp", tableName];
            NSString *rename_old_sql = [NSString stringWithFormat:@"alter table %@ rename to %@;", tableName, temp_name];
            if (![db executeUpdate:rename_old_sql]) {
                [self.class jdblog:@"删除列，修改列 --- rename table error"];
                *rollback = YES;
                return;
            }
            if (![db executeUpdate:create_table_sql]) {
                [self.class jdblog:@"删除列，修改列 --- create_new table error"];
                *rollback = YES;
                return;
            }
            NSMutableString *sel_keys_sql = [NSMutableString stringWithFormat:@""];
            for (NSString *column in columns) {
                [sel_keys_sql appendFormat:@"%@, ", column];
            }
            [sel_keys_sql deleteCharactersInRange:NSMakeRange(sel_keys_sql.length-2, 2)];
            NSMutableString *insert_sql = [NSMutableString stringWithFormat:@"insert into %@(%@) select %@ from %@;", tableName, sel_keys_sql, sel_keys_sql, temp_name];
            if (![db executeUpdate:insert_sql]) {
                [self.class jdblog:@"删除列，修改列 --- insert new table error"];
                *rollback = YES;
                return;
            }
            
            NSString *del_old = [NSString stringWithFormat:@"drop table %@;", temp_name];
            if (![db executeUpdate:del_old]) {
                [self.class jdblog:@"删除列，修改列 --- del_old table error"];
                *rollback = YES;
                return;
            }
        }
    }];
    
    if (res) {
        [self.class jdblog:@"db create or alter table %@ success",tableName];
    }else{
        [self.class jdblog:@"db create or alter table %@ exist some err, see before log",tableName];
    }
    return res;
}

- (BOOL)isExist
{
    NSMutableString *condition = [NSMutableString stringWithFormat:@"WHERE  "];
    NSArray *pkdescs = [self getPkDescs];
    BOOL isExist = NO;
    if (pkdescs.count > 1) {
        //联合
        for (JDBColumnDes *desc in pkdescs) {
            [condition appendFormat:@"%@ = '%@' and ", desc.inDbName, [self valueForKey:desc.propertyName]];
        }
        [condition deleteCharactersInRange:NSMakeRange(condition.length-5, 5)];
    }
    else
    {
        JDBColumnDes *desc = pkdescs.firstObject;
        [condition appendFormat:@"%@ = '%@'", desc.inDbName, [self valueForKey:desc.propertyName]];
    }
    JDBModel *model = [self.class findFirstByCriteria:condition table:self.tableName];
    if (model) {
        isExist = YES;
    }
    
    return isExist;
}
- (BOOL)saveOrUpdate
{
    if (!self.pkDescs.count) {
        //无主键不做操作
        return NO;
    }
    if (![self isExist]) {
        return [self save];
    }
    
    return [self update];
}
- (BOOL)save
{
    NSString *tableName = [self tableName];
    NSMutableString *keyString = [NSMutableString string];
    NSMutableString *valueString = [NSMutableString string];
    NSMutableArray *insertValues = [NSMutableArray  array];

    for (int i = 0; i < self.columeNames.count; i++) {
        NSString *proname = [self.columeNames objectAtIndex:i];
        [keyString appendFormat:@"%@,", proname];
        [valueString appendString:@"?,"];
        id value = [self valueForKey:self.propertyNames[i]];
        value = [self.class transformInsertValueToString:value];
        if (!value) {
            value = [NSNull null];
        }
        
        [insertValues addObject:value];
    }
    
    [keyString deleteCharactersInRange:NSMakeRange(keyString.length - 1, 1)];
    [valueString deleteCharactersInRange:NSMakeRange(valueString.length - 1, 1)];
    
    __block BOOL res = NO;
    [[self.class getDbqueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = [NSString stringWithFormat:@"INSERT INTO %@(%@) VALUES (%@);", tableName, keyString, valueString];
        res = [db executeUpdate:sql withArgumentsInArray:insertValues];
        self.lastInsertRowId = res?[NSNumber numberWithLongLong:db.lastInsertRowId].intValue:0;
        [self.class jdblog:@"%@", [NSString stringWithFormat:@"db talble:%@ 插入%@ \n %@", tableName, res?@"成功":@"失败", self.description]];
    }];
    return res;
}

/** 批量保存用户对象 */
+ (BOOL)saveObjects:(NSArray *)array
{
    __block BOOL res = YES;
    // 如果要支持事务
    [[self getDbqueue] inTransaction:^(FMDatabase *db, BOOL *rollback) {
        for (JDBModel *model in array) {
            if (![model isKindOfClass:[JDBModel class]]) {
                continue;
            }
            BOOL flag = [model save];
            model.lastInsertRowId = flag?[NSNumber numberWithLongLong:db.lastInsertRowId].intValue:0;
            if (!flag) {
                res = NO;
                if (conf.rollback_once_err) {
                    *rollback = YES;
                    return;
                }
            }
        }
    }];
    return res;
}

+(BOOL)saveOrUpdateObjects:(NSArray *)array
{
    __block BOOL res = YES;
    // 如果要支持事务
    [[self getDbqueue] inTransaction:^(FMDatabase *db, BOOL *rollback) {
        for (JDBModel *model in array) {
            if (![model isKindOfClass:[JDBModel class]]) {
                continue;
            }
            BOOL tempF = [model saveOrUpdate];
            if (!tempF) {
                res = NO;
                if (conf.rollback_once_err) {
                    *rollback = YES;
                    return;
                }
            }
        }
    }];
    
    return res;
}
/** 更新单个对象 */
- (BOOL)update
{
    __block BOOL res = NO;
    if (!self.pkDescs.count) {
        //无主键不操作
        return res;
    }
    [[self.class getDbqueue] inDatabase:^(FMDatabase *db) {
        NSString *tableName = [self tableName];
        
        NSMutableString *keyString = [NSMutableString string];
        NSMutableArray *updateValues = [NSMutableArray  array];
        for (int i = 0; i < self.columeNames.count; i++) {
            NSString *proname = [self.columeNames objectAtIndex:i];
            [keyString appendFormat:@" %@=?,", proname];
            id value = [self valueForKey:self.propertyNames[i]];
            value = [self.class transformInsertValueToString:value];
            if (!value) {
                value = [NSNull null];
            }
            [updateValues addObject:value];
        }
        
        //删除最后那个逗号
        [keyString deleteCharactersInRange:NSMakeRange(keyString.length - 1, 1)];
        
        NSMutableString *sql = [NSMutableString stringWithFormat:@"UPDATE %@ SET %@ WHERE ", tableName, keyString];
        for (int i = 0; i < self.pkDescs.count; i++) {
            JDBColumnDes *des = self.pkDescs[i];
            [sql appendFormat:@"%@ = ? AND ", des.propertyName];
            [updateValues addObject:[self valueForKey:des.propertyName]];
        }
        
        [sql deleteCharactersInRange:NSMakeRange(sql.length-5, 5)];
        [sql appendFormat:@"%@", @";"];
        
        res = [db executeUpdate:sql withArgumentsInArray:updateValues];
        [self.class jdblog:@"%@", [NSString stringWithFormat:@"db talble:%@ 更新%@ \n %@", tableName, res?@"成功":@"失败", self.description]];
    }];
    return res;
}
- (BOOL)updateNonEmptyKeyValues
{
    __block BOOL res = NO;
    if (!self.pkDescs.count) {
        //无主键不操作
        return res;
    }
    [[self.class getDbqueue] inDatabase:^(FMDatabase *db) {
        NSString *tableName = [self tableName];
        
        NSMutableString *keyString = [NSMutableString string];
        NSMutableArray *updateValues = [NSMutableArray  array];
        for (int i = 0; i < self.columeNames.count; i++) {
            NSString *proname = [self.columeNames objectAtIndex:i];
            id value = [self valueForKey:self.propertyNames[i]];
            value = [self.class transformInsertValueToString:value];
            if (value) {
                [keyString appendFormat:@" %@=?,", proname];
                [updateValues addObject:value];
            }
        }
        
        //删除最后那个逗号
        [keyString deleteCharactersInRange:NSMakeRange(keyString.length - 1, 1)];
        
        NSMutableString *sql = [NSMutableString stringWithFormat:@"UPDATE %@ SET %@ WHERE ", tableName, keyString];
        for (int i = 0; i < self.pkDescs.count; i++) {
            JDBColumnDes *des = self.pkDescs[i];
            [sql appendFormat:@"%@ = ? AND ", des.propertyName];
            [updateValues addObject:[self valueForKey:des.propertyName]];
        }
        [sql deleteCharactersInRange:NSMakeRange(sql.length-5, 5)];
        [sql appendFormat:@"%@", @";"];
        
        res = [db executeUpdate:sql withArgumentsInArray:updateValues];
        [self.class jdblog:@"%@", [NSString stringWithFormat:@"db talble:%@ 更新%@ \n %@", tableName, res?@"成功":@"失败", self.description]];
    }];
    return res;
}
- (BOOL)saveOrUpdateByColumnName:(NSArray*)columnNames AndColumnValue:(NSArray*)columnValues
{
    NSMutableString *findSql = [NSMutableString stringWithFormat:@"where "];
    for (int i = 0; i < columnNames.count; i++) {
        id cn = columnNames[i];
        id value = columnValues[i];
        [findSql appendFormat:@"%@ = '%@' and ",cn, value];
        [findSql deleteCharactersInRange:NSMakeRange(findSql.length - 5, 5)];
    }
    id record = [self.class findFirstByCriteria:findSql table:self.tableName];
    if (!record) {
        return [self save];
    }
    __block BOOL res = NO;
    [[self.class getDbqueue] inDatabase:^(FMDatabase *db) {
        NSString *tableName = [self tableName];
        
        NSMutableString *keyString = [NSMutableString string];
        NSMutableArray *updateValues = [NSMutableArray  array];
        for (int i = 0; i < self.columeNames.count; i++) {
            NSString *proname = [self.columeNames objectAtIndex:i];
            id value = [self valueForKey:self.propertyNames[i]];
            value = [self.class transformInsertValueToString:value];
            //更新有值的
            if (value) {
                [keyString appendFormat:@" %@=?,", proname];
                [updateValues addObject:value];
            }
        }
        
        //删除最后那个逗号
        [keyString deleteCharactersInRange:NSMakeRange(keyString.length - 1, 1)];
        NSMutableString *sql = [NSMutableString stringWithFormat:@"UPDATE %@ SET %@ WHERE ", tableName, keyString];
        for (int i = 0; i < columnNames.count; i++) {
            id cn = columnNames[i];
            id value = columnValues[i];
            [sql appendFormat:@"%@ = ? AND ", cn];
            [updateValues addObject:value];
        }
        [sql deleteCharactersInRange:NSMakeRange(sql.length-5, 5)];
        [sql appendFormat:@"%@", @";"];
        res = [db executeUpdate:sql withArgumentsInArray:updateValues];
        [self.class jdblog:@"%@", [NSString stringWithFormat:@"db talble:%@ 更新%@ \n %@", tableName, res?@"成功":@"失败", self.description]];
    }];
    
    return res;
}

/** 批量更新用户对象*/
+ (BOOL)updateObjects:(NSArray *)array
{
    __block BOOL res = YES;
    // 如果要支持事务
    [[self getDbqueue] inTransaction:^(FMDatabase *db, BOOL *rollback) {
        for (JDBModel *model in array) {
            if (![model isKindOfClass:[JDBModel class]]) {
                continue;
            }
            BOOL flag = [model update];
            if (!flag) {
                res = NO;
                if (conf.rollback_once_err) {
                    *rollback = YES;
                    return;
                }
            }
        }
    }];
    
    return res;
}

/** 删除单个对象 */
- (BOOL)deleteObject
{
    __block BOOL res = NO;
    if (!self.pkDescs.count) {
        //无主键不操作
        return res;
    }
    [[self.class getDbqueue] inDatabase:^(FMDatabase *db) {
        NSString *tableName = [self tableName];
        NSMutableString *sql = [NSMutableString stringWithFormat:@"DELETE FROM %@ WHERE ",tableName];
        NSMutableArray *arguments = [NSMutableArray array];
        for (int i = 0; i < self.pkDescs.count; i++) {
            JDBColumnDes *des = self.pkDescs[i];
            [sql appendFormat:@"%@ = ? AND ", des.propertyName];
            [arguments addObject:[self valueForKey:des.propertyName]];
        }
        [sql deleteCharactersInRange:NSMakeRange(sql.length-5, 5)];
        [sql appendFormat:@"%@", @";"];
        res = [db executeUpdate:sql withArgumentsInArray:arguments];
        [self.class jdblog:@"%@", [NSString stringWithFormat:@"db talble:%@ 删除%@ \n %@", tableName, res?@"成功":@"失败",self.description]];
    }];
    return res;
}

/** 批量删除用户对象 */
+ (BOOL)deleteObjects:(NSArray *)array
{
    __block BOOL res = YES;
    // 如果要支持事务
    [[self getDbqueue] inTransaction:^(FMDatabase *db, BOOL *rollback) {
        for (JDBModel *model in array) {
            if (![model isKindOfClass:[JDBModel class]]) {
                continue;
            }
            BOOL flag = [model deleteObject];
            if (!flag) {
                res = NO;
                if (conf.rollback_once_err) {
                    *rollback = YES;
                    return;
                }
            }
        }
    }];
    return res;
}

/** 通过条件删除数据 */
+ (BOOL)deleteObjectsByCriteria:(NSString *)criteria table:(NSString *)tableName
{
    __block BOOL res = NO;
    [[self getDbqueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@ %@ ",tableName,criteria];
        res = [db executeUpdate:sql];
        [self.class jdblog:@"%@", [NSString stringWithFormat:@"db talble:%@ 删除%@ criteria:%@", tableName, res?@"成功":@"失败", criteria]];
    }];
    return res;
}
+ (BOOL)deleteObjectsByCriteria:(NSString *)criteria
{
    return [self deleteObjectsByCriteria:criteria table:[self firstTableName]];
}

/** 通过条件删除 (多参数）--2 */
+ (BOOL)deleteObjects:(NSString *)tableName withFormat:(NSString *)format, ...
{
    va_list ap;
    va_start(ap, format);
    NSString *criteria = [[NSString alloc] initWithFormat:format locale:nil arguments:ap];
    va_end(ap);
    
    return [self deleteObjectsByCriteria:criteria table:tableName];
}
+ (BOOL)deleteObjectsWithFormat:(NSString *)format, ...
{
    return [self deleteObjects:[self firstTableName] withFormat:format];
}

/** 清空表 */
+ (BOOL)clearTable
{
    return [self clearTable:[self firstTableName]];
}
+ (BOOL)clearTable:(NSString *)tableName
{
    __block BOOL res = NO;
    [[self getDbqueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@",tableName];
        res = [db executeUpdate:sql];
        [self.class jdblog:@"%@", [NSString stringWithFormat:@"db talble:%@ 清空%@", tableName, res?@"成功":@"失败"]];
    }];
    return res;
}

/** 查询全部数据 */
+ (NSArray *)findAll:(NSString *)tableName
{
    NSMutableArray *users = [NSMutableArray array];
    
    [[self getDbqueue] inDatabase:^(FMDatabase *db) {
        NSString *sql = [NSString stringWithFormat:@"SELECT * FROM %@",tableName];
        FMResultSet *resultSet = [db executeQuery:sql];
        while ([resultSet next]) {
            NSDictionary *dict = [resultSet resultDictionary];
            JDBModel *model = [self.class yy_modelWithDictionary:dict];
            [users addObject:model];
            FMDBRelease(model);
        }
    }];
    
    [self.class jdblog:@"db talble:%@ find all %zd", tableName, users.count];
    return users;
}
+ (NSArray *)findAll
{
    return [self findAll:[self firstTableName]];
}

+ (instancetype)findFirst:(NSString *)tableName withFormat:(NSString *)format, ...
{
    return [self find:tableName withFormat:format].firstObject;
}
+ (instancetype)findFirstWithFormat:(NSString *)format, ...
{
    return [self findFirst:[self firstTableName] withFormat:format];
}

/** 查找某条数据 */
+ (instancetype)findFirstByCriteria:(NSString *)criteria table:(NSString *)tableName
{
    return [self findByCriteria:criteria table:tableName].firstObject;
}
+ (instancetype)findFirstByCriteria:(NSString *)criteria
{
    return [self findFirstByCriteria:criteria table:[self firstTableName]];
}

+ (NSArray *)find:(NSString *)tableName withFormat:(NSString *)format, ...
{
    va_list ap;
    va_start(ap, format);
    NSString *criteria = [[NSString alloc] initWithFormat:format locale:nil arguments:ap];
    va_end(ap);
    
    return [self findByCriteria:criteria table:tableName];
}
+ (NSArray *)findWithFormat:(NSString *)format, ...
{
    return [self find:[self firstTableName] withFormat:format];
}

/** 通过条件查找数据 */
+ (NSArray *)findByCriteria:(NSString *)criteria field:(NSArray *)fields table:(NSString *)tableName
{
    NSMutableArray *temp = [NSMutableArray array];
    [[self getDbqueue] inDatabase:^(FMDatabase *db) {
        NSMutableString *sqlPre = [NSMutableString string];
        if (fields.count == 0) {
            [sqlPre appendString:@"SELECT *"];
        } else {
            [sqlPre appendString:@"SELECT "];
            for (NSString *key in fields) {
                if (key == fields.lastObject) {
                    [sqlPre appendFormat:@"%@", key];
                } else {
                    [sqlPre appendFormat:@"%@, ", key];
                }
            }
        }
        NSString *sql = [NSString stringWithFormat:@"%@ FROM %@ %@",sqlPre, tableName, criteria?criteria:@""];
        FMResultSet *resultSet = [db executeQuery:sql];
        while ([resultSet next]) {
            NSDictionary *dict = [resultSet resultDictionary];
            JDBModel *model = [self.class yy_modelWithDictionary:dict];
            [temp addObject:model];
            [self.class jdblog:@"db table:%@ find model:\n %@", tableName, model];
            FMDBRelease(model);
        }
    }];
    
    return temp;
}
+ (NSArray *)findByCriteria:(NSString *)criteria field:(NSArray *)fields
{
    return [self findByCriteria:criteria field:fields table:[self firstTableName]];
}
+ (NSArray *)findByCriteria:(NSString *)criteria table:(NSString *)tableName
{
    return [self findByCriteria:criteria field:nil table:tableName];
}
+ (NSArray *)findByCriteria:(NSString *)criteria
{
    return [self findByCriteria:criteria field:nil];
}
#pragma mark 基本方法
/**
 *  获取该类的所有属性
 */
+ (NSDictionary *)getPropertys
{
    NSMutableArray *proNames = [NSMutableArray array];
    NSMutableArray *proTypes = [NSMutableArray array];
    NSArray *theTransients = [[self class] transients];
    unsigned int outCount, i;
    objc_property_t *properties = class_copyPropertyList([self class], &outCount);
    for (i = 0; i < outCount; i++) {
        objc_property_t property = properties[i];
        //获取属性名
        NSString *propertyName = [NSString stringWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
        if ([theTransients containsObject:propertyName]) {
            continue;
        }
        [proNames addObject:propertyName];
        //获取属性类型等参数
        NSString *propertyType = [NSString stringWithCString: property_getAttributes(property) encoding:NSUTF8StringEncoding];
        /*
         各种符号对应类型，部分类型在新版SDK中有所变化，如long 和long long
         c char         C unsigned char
         i int          I unsigned int
         l long         L unsigned long
         s short        S unsigned short
         d double       D unsigned double
         f float        F unsigned float
         q long long    Q unsigned long long
         B BOOL
         @ 对象类型 //指针 对象类型 如NSString 是@“NSString”
         
         
         64位下long 和long long 都是Tq
         SQLite 默认支持五种数据类型TEXT、INTEGER、REAL、BLOB、NULL
         因为在项目中用的类型不多，故只考虑了少数类型
         */
        if ([propertyType containsString:@"NSData"]) {
            [proTypes addObject:SQLBLOB];
        }
        else if ([propertyType hasPrefix:@"T@"]) {
            [proTypes addObject:SQLTEXT];
        } else if ([propertyType hasPrefix:@"Ti"]||[propertyType hasPrefix:@"TI"]||
                   [propertyType hasPrefix:@"Ts"]||[propertyType hasPrefix:@"TS"]||
                   [propertyType hasPrefix:@"TB"]) {
            [proTypes addObject:SQLINTEGER];
        } else {
            [proTypes addObject:SQLREAL];
        }
        
    }
    free(properties);
    
    return [NSDictionary dictionaryWithObjectsAndKeys:proNames,@"name",proTypes,@"type",nil];
}

/** 获取所有属性，包含主键pk */
+ (NSDictionary *)getAllProperties
{
    NSDictionary *dict = [self.class getPropertys];
    
    NSMutableArray *proNames = [NSMutableArray array];
    NSMutableArray *proTypes = [NSMutableArray array];
    [proNames addObjectsFromArray:[dict objectForKey:@"name"]];
    [proTypes addObjectsFromArray:[dict objectForKey:@"type"]];
    
    return [NSDictionary dictionaryWithObjectsAndKeys:proNames,@"name",proTypes,@"type",nil];
}
/** 获取列名 */
- (NSArray *)getColumns
{
    NSMutableArray *columns = [NSMutableArray array];
    [[self.class getDbqueue] inDatabase:^(FMDatabase *db) {
        NSString *tableName = [self tableName];
        FMResultSet *resultSet = [db getTableSchema:tableName];
        while ([resultSet next]) {
            NSString *column = [resultSet stringForColumn:@"name"];
            [columns addObject:column];
        }
    }];
    return [columns copy];
}
+ (NSArray *)getColumns:(NSString *)tableName
{
    NSMutableArray *columns = [NSMutableArray array];
    [[self.class getDbqueue] inDatabase:^(FMDatabase *db) {
        FMResultSet *resultSet = [db getTableSchema:tableName];
        while ([resultSet next]) {
            NSString *column = [resultSet stringForColumn:@"name"];
            [columns addObject:column];
        }
    }];
    return [columns copy];
}
#pragma mark - util method
/**
 *  创建数据库sql语句
 */
+ (NSString *)getColumeAndTypeString
{
    NSMutableString* pars = [NSMutableString string];
    NSDictionary *dict = [self.class getAllProperties];
    
    NSMutableArray *columns = [self.class getColumnNames];
    NSMutableArray *proTypes = [dict objectForKey:@"type"];
    
    for (int i=0; i< columns.count; i++) {
        [pars appendFormat:@"%@ %@ %@",[columns objectAtIndex:i],[proTypes objectAtIndex:i],[self.class PKAndColumnModify][i]];
        if(i+1 != columns.count)
        {
            [pars appendString:@","];
        }
    }
    //处理联合主键
    NSMutableString *unionKey = [NSMutableString stringWithFormat:@"primary key("];
    NSArray *pkdescs = [self getPkDescs];
    if (pkdescs.count > 1) {
        for (int i = 0; i < pkdescs.count; i++) {
            JDBColumnDes *des = pkdescs[i];
            [unionKey appendFormat:@"%@, ", des.inDbName];
            if (i + 1 == pkdescs.count) {
                [unionKey deleteCharactersInRange:NSMakeRange(unionKey.length-2, 2)];
                [unionKey appendFormat:@"%@", @")"];
                [pars appendFormat:@", %@", unionKey];
            }
        }
    }
    

    return pars;
}

- (NSString *)description
{
    NSString *result = @"";
    NSDictionary *dict = [self.class getAllProperties];
    NSMutableArray *proNames = [dict objectForKey:@"name"];
    for (int i = 0; i < proNames.count; i++) {
        NSString *proName = [proNames objectAtIndex:i];
        id  proValue = [self valueForKey:proName];
        result = [result stringByAppendingFormat:@"%@:%@\n",proName,proValue];
    }
    return result;
}



#pragma mark get modify column
/**
 *  不需要创建字段的属性名称
 */
+ (NSMutableArray *)transients{
    NSMutableArray *transients = [NSMutableArray array];
    
    [[self.class describeColumnDict] enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        JDBColumnDes *columnDes = obj;
        if (columnDes.isUseless) {
            [transients addObject:key];
        }
    }];
    return transients;
}
/**
 * 创建数据库字段修饰
 */
+ (NSMutableArray *)PKAndColumnModify{
    NSMutableArray *modifies = [NSMutableArray array];
    NSMutableArray *properties = [self.class getAllProperties][@"name"];
    NSDictionary *desDic = [self.class describeColumnDict];
    
    for (int i = 0; i < properties.count ; i++) {
        NSString *property = properties[i];
        JDBColumnDes *des = desDic[property];
        if (des) {
            [modifies addObject:[des finishModify]];
        }else{
            [modifies addObject:@""];
        }
    }
    return modifies;
}
/**
 *  得到起过别名的数据库字段
 */
+ (NSMutableArray *)getColumnNames{
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    [[self.class describeColumnDict] enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        JDBColumnDes *columnDes = obj;
        columnDes.propertyName = key;
        if (columnDes.aliasName != nil && ![columnDes.aliasName isEqualToString:key]) {
            [dic setValue:columnDes.aliasName forKey:key];
        }
        
    }];
    
    NSMutableArray *properties = [self.class getPropertys][@"name"];
    for (int i =0 ; i < properties.count; i++) {
        if (dic[properties[i]]){
            [properties replaceObjectAtIndex:i withObject:dic[properties[i]]];
        }
    }
    
    return properties;
}
#pragma mark - must be override method
/** 如果子类中有一些property不需要创建数据库字段,或者对字段加修饰属性   具体请参考JDBColumnDes类*/
+ (NSDictionary *)describeColumnDict
{
    return @{};
}
+ (FMDatabaseQueue *)dbQueue
{
    return nil;
}
#pragma mark 可选要重写的方法
+ (NSString *)firstTableName
{
    return [self tableNames].firstObject;
}
+ (NSArray *)tableNames
{
    return @[NSStringFromClass(self.class)];
}
- (NSString *)tableName
{
    return [self.class tableNames].firstObject;
}
+ (BOOL)logForThisClass
{
    return YES;
}
#pragma mark - private
+ (void)jdblog:(NSString *)format, ...
{
    if (conf.log && [self logForThisClass])
    {
        va_list ap;
        va_start(ap, format);
        NSString *formatstr = [[NSString alloc] initWithFormat:format locale:nil arguments:ap];
        va_end(ap);
        
        NSLog(@"%@", formatstr);
    }
}
- (NSArray<JDBColumnDes *> *)getPkDescs
{
    if (!_pkDescs) {
        _pkDescs = [self.class getPkDescs];
    }
    return _pkDescs;
}
+ (NSArray<JDBColumnDes *> *)getPkDescs
{
    NSMutableArray *temp = [NSMutableArray array];
    [[self.class describeColumnDict] enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        JDBColumnDes *columnDes = obj;
        if (columnDes.isUnionKey || columnDes.isPrimaryKey) {
            columnDes.propertyName = key;
            [temp addObject:columnDes];
        }
    }];
    return temp;
}
+ (FMDatabaseQueue *)getDbqueue
{
    FMDatabaseQueue *dbqueue = [self dbQueue];
    if (!dbqueue) {
        [self.class jdblog:@"b queue null, there must be a dbqueue returned for model, overwrite 'dbQueue' method and return a dbqueue"];
    }
    return dbqueue;
}
+ (id)transformInsertValueToString:(id)value
{
    if ([value isKindOfClass:[NSArray class]] ||
        [value isKindOfClass:[NSDictionary class]] ||
        [value isKindOfClass:[NSSet class]]) {
        value = [value yy_modelToJSONString];
    }
    else if ([value isKindOfClass:[NSURL class]]) {value = ((NSURL *)value).absoluteString;}
    else if ([value isKindOfClass:[NSAttributedString class]]) {value = ((NSAttributedString *)value).string;}
    else if ([value isKindOfClass:[NSDate class]]){
        NSDateFormatter *outputFormatter = [[NSDateFormatter alloc] init];
        [outputFormatter setDateFormat:[self dateFormat]];
        NSString *timestamp_str = [outputFormatter stringFromDate:(NSDate *)value];
        value = timestamp_str;
    }
    else if ([value isKindOfClass:[NSData class]]) {
//        value = @"";
    }
    else if([value conformsToProtocol:@protocol(YYModel)]){
        NSString *yymodel_res = [value yy_modelToJSONString];
        if (yymodel_res) {
            value = yymodel_res;
        }
    }
    
    return value;
}
+ (NSString *)dateFormat
{
    return @"yyyy-MM-dd, HH:mm:ss";
}
#pragma mark - get
@end
