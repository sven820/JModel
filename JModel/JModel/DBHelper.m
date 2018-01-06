//
//  DBHelper.m
//
//  Created by jinxiaofei on 16/7/14.
//  Copyright © 2016年 Guangzhou TalkHunt Information Technology Co., Ltd. All rights reserved.
//

#import "DBHelper.h"

@interface FMDatabase (Helper)

@end

@interface DBHelper ()
@property (nonatomic, strong) FMDatabaseQueue *dbQueue;
@end

@implementation DBHelper

#pragma mark - lazy load
- (FMDatabaseQueue *)dbQueue {
    if (!_dbQueue) {
        FMDatabaseQueue *q = [[FMDatabaseQueue alloc] initWithPath:self.dbFile];
        _dbQueue = q;
    }
    return _dbQueue;
}

#pragma mark - getter & setter
- (void)setDbFile:(NSString *)dbFile {
    if (_dbFile == dbFile) {
        return;
    }
    _dbFile = [dbFile copy];
    //
    [_dbQueue close];
    _dbQueue = nil;
    
    //创建queue
    [self dbQueue];
}

#pragma mark - public

- (void)executeSQLInDatabase:(NSString *)sql block:(void(^)(BOOL res, NSError *error, FMDatabase *db))block
{
    __block BOOL result = NO;
    __block NSError *error = nil;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        result = [db executeUpdate:sql values:nil error:&error];
        if (block) {
            block(result, error, db);
        }
    }];
}

- (void)close
{
    [self.dbQueue close];
}

#pragma mark - 同步
- (BOOL)insertIntoTable:(NSString*)tableName withKeyValues:(NSDictionary *)keyValues error:(NSError * __autoreleasing *)error {
    NSMutableString *sql = [NSMutableString string];
    NSMutableArray *values = [[NSMutableArray alloc] initWithCapacity:keyValues.count];
    
    [sql appendFormat:@"INSERT INTO \'%@\' ", tableName];
    [sql appendString:@"("];
    
    for (NSString *key in keyValues.allKeys) {
        if (key == keyValues.allKeys.lastObject) {
            [sql appendFormat:@"%@", key];
        } else {
            [sql appendFormat:@"%@, ", key];
        }
        [values addObject:keyValues[key]];
    }
    [sql appendString:@") "];
    
    [sql appendString:@"VALUES ("];
    NSInteger i = values.count;
    while (i-- > 0) {
        if (i == 0) {
            [sql appendString:@"?"];
        } else {
            [sql appendString:@"?, "];
        }
    }
    [sql appendString:@");"];
    
    __block BOOL result;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        result = [db executeUpdate:sql values:values error:error];
    }];
    return result;
}

- (BOOL)replaceIntoTable:(NSString*)tableName withKeyValues:(NSDictionary *)keyValues error:(NSError * __autoreleasing *)error {
    NSMutableString *sql = [NSMutableString string];
    NSMutableArray *values = [[NSMutableArray alloc] initWithCapacity:keyValues.count];
    
    [sql appendFormat:@"REPLACE INTO \'%@\' ", tableName];
    [sql appendString:@"("];
    
    for (NSString *key in keyValues.allKeys) {
        if (key == keyValues.allKeys.lastObject) {
            [sql appendFormat:@"%@", key];
        } else {
            [sql appendFormat:@"%@, ", key];
        }
        [values addObject:keyValues[key]];
    }
    [sql appendString:@") "];
    
    [sql appendString:@"VALUES ("];
    NSInteger i = values.count;
    while (i-- > 0) {
        if (i == 0) {
            [sql appendString:@"?"];
        } else {
            [sql appendString:@"?, "];
        }
    }
    [sql appendString:@");"];
    
    __block BOOL result;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        result = [db executeUpdate:sql values:values error:error];
    }];
    return result;
}

- (BOOL)deleteFromTable:(NSString *)tableName whereCondition:(NSDictionary *)conditions error:(NSError * __autoreleasing *)error {
    NSMutableString *sql = [NSMutableString string];
    NSMutableArray *values = nil;
    
    [sql appendFormat:@"DELETE FROM \'%@\' ", tableName];
    
    //WHERE
    if (conditions.count != 0) {
        values = [[NSMutableArray alloc] initWithCapacity:conditions.count];
        [sql appendString:@"WHERE "];
        for (NSString *key in conditions.allKeys) {
            if (key == conditions.allKeys.lastObject) {
                [sql appendFormat:@"%@ = ?", key];
            } else {
                [sql appendFormat:@"%@ = ? and ", key];
            }
            [values addObject:conditions[key]];
        }
    }
    
    [sql appendString:@";"];
    
    __block BOOL result = NO;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        result = [db executeUpdate:sql values:values error:error];
    }];
    return result;
}

- (FMResultSet *)selectFromTable:(NSString *)tableName fields:(NSArray *)fields where:(NSString *)condition error:(NSError * __autoreleasing *)error
{
    NSMutableString *sql = [NSMutableString string];
    
    if (fields.count == 0) {
        [sql appendString:@"SELECT * "];
    } else {
        [sql appendString:@"SELECT "];
        for (NSString *key in fields) {
            if (key == fields.lastObject) {
                [sql appendFormat:@"%@", key];
            } else {
                [sql appendFormat:@"%@, ", key];
            }
        }
    }
    [sql appendFormat:@"FROM \'%@\' WHERE 1=1 ", tableName];
    
    if (condition.length > 0) {
        [sql appendFormat:@"%@;", condition];
    }
    
    __block FMResultSet *set = nil;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        NSLog(@"%@", sql);
        set = [db executeQuery:sql values:nil error:error];
    }];
    return set;
}

- (FMResultSet *)selectFromTable:(NSString *)tableName withKeys:(NSArray *)keys whereConditions:(NSDictionary *)conditions error:(NSError * __autoreleasing *)error {
    NSMutableString *sql = [NSMutableString string];
    NSMutableArray *values = nil;
    
    if (keys.count == 0) {
        [sql appendString:@"SELECT * "];
    } else {
        [sql appendString:@"SELECT "];
        for (NSString *key in keys) {
            if (key == keys.lastObject) {
                [sql appendFormat:@"%@", key];
            } else {
                [sql appendFormat:@"%@, ", key];
            }
        }
    }
    [sql appendFormat:@"FROM \'%@\' ", tableName];
    
    //WHERE
    if (conditions.count != 0) {
        values = [[NSMutableArray alloc] initWithCapacity:conditions.count];
        [sql appendString:@"WHERE "];
        
        for (NSString *key in conditions.allKeys) {
            if (key == conditions.allKeys.lastObject) {
                [sql appendFormat:@"%@ = ?", key];
            } else {
                [sql appendFormat:@"%@ = ? and ", key];
            }
            [values addObject:conditions[key]];
        }
    }
    
    [sql appendString:@";"];
    
    __block FMResultSet *set = nil;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        set = [db executeQuery:sql values:values error:error];
    }];
    return set;
}

- (BOOL)updateTable:(NSString *)tableName setKeyValues:(NSDictionary *)keyValues whereConditions:(NSDictionary *)conditions error:(NSError * __autoreleasing *)error {
    NSMutableString *sql = [NSMutableString string];
    NSMutableArray *values = [[NSMutableArray alloc] initWithCapacity:keyValues.count + conditions.count];
    
    [sql appendFormat:@"UPDATE \'%@\' ", tableName];
    [sql appendString:@"SET "];
    
    for (NSString *key in keyValues.allKeys) {
        if (key == keyValues.allKeys.lastObject) {
            [sql appendFormat:@"%@ = ?", key];
        } else {
            [sql appendFormat:@"%@ = ?, ", key];
        }
        [values addObject:keyValues[key]];
    }
    //WHERE
    if (conditions.count != 0) {
        [sql appendString:@"WHERE "];
        
        for (NSString *key in conditions.allKeys) {
            if (key == conditions.allKeys.lastObject) {
                [sql appendFormat:@"%@ = ?", key];
            } else {
                [sql appendFormat:@"%@ = ?,", key];
            }
            [values addObject:conditions[key]];
        }
    }
    
    [sql appendString:@";"];
    
    __block BOOL result = NO;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        result = [db executeUpdate:sql values:values error:error];
    }];
    return result;
}

#pragma mark - 异步
- (void)executeSQLInDatabase:(NSString *)sql withCompletion:(void(^)(BOOL res, NSError * error, FMDatabase *db))completion
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [self executeSQLInDatabase:sql block:^(BOOL res, NSError *error, FMDatabase *db) {
            if (completion) {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    completion(res, error, db);
                });
            }
        }];
        
    });
}

- (void)insertIntoTable:(NSString*)tableName withKeyValues:(NSDictionary *)keyValues completion:(void (^)(NSError * error))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        [self insertIntoTable:tableName withKeyValues:keyValues error:&error];
        if (completion) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                completion(error);
            });
        }
    });
}

- (void)replaceIntoTable:(NSString*)tableName withKeyValues:(NSDictionary *)keyValues completion:(void (^)(NSError * error))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        [self replaceIntoTable:tableName withKeyValues:keyValues error:&error];
        if (completion) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                completion(error);
            });
        }
    });
}

- (void)deleteFromTable:(NSString *)tableName whereCondition:(NSDictionary *)conditions completion:(void (^)(NSError * error))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError * error = nil;
        [self deleteFromTable:tableName whereCondition:conditions error:&error];
        if (completion) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                completion(error);
            });
        }
    });
}

- (void)selectFromTable:(NSString *)tableName withKeys:(NSArray *)keys whereConditions:(NSDictionary *)conditions completion:(void(^)(FMResultSet *set, NSError * error))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError * error = nil;
        FMResultSet *set = [self selectFromTable:tableName withKeys:keys whereConditions:conditions error:&error];
        if (completion) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                completion(set, error);
            });
        }
    });
}

- (void)updateTable:(NSString *)tableName setKeyValues:(NSDictionary *)keyValues whereConditions:(NSDictionary *)conditions completion:(void(^)(NSError * error))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        [self updateTable:tableName setKeyValues:keyValues whereConditions:conditions error:&error];
        if (completion) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                completion(error);
            });
        }
    });
}

- (void)executeInTransationWithImplementBlock:(void (^)(FMDatabase *db, BOOL *rollback))block
{
    if (block == nil) {
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.dbQueue inTransaction:block];
    });
}

@end
