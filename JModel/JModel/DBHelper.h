//
//  DBHelper.h
//
//  Created by jinxiaofei on 16/7/14.
//  Copyright © 2016年 Guangzhou TalkHunt Information Technology Co., Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <FMDB/FMDB.h>

@interface DBHelper : NSObject
@property (nonatomic, copy) NSString *dbFile;

@property (nonatomic, readonly) FMDatabaseQueue *dbQueue;
/**
 *  关闭数据库
 */
- (void)close;
//同步
/**
 *  同步执行SQL
 *
 *  @param sql   SQL语句
 */
- (void)executeSQLInDatabase:(NSString *)sql block:(void(^)(BOOL res, NSError *error, FMDatabase *db))block;

/**
 *  同步插入
 *
 *  @param tableName 表名
 *  @param keyValues 键值对
 *  @param error     错误信息
 *
 *  @return 成功与否
 */
- (BOOL)insertIntoTable:(NSString*)tableName withKeyValues:(NSDictionary *)keyValues error:(NSError **)error;

/**
 *  同步replace
 *
 *  @param tableName 表名
 *  @param keyValues 键值对
 *  @param error     错误信息
 *
 *  @return 成功与否
 */
- (BOOL)replaceIntoTable:(NSString*)tableName withKeyValues:(NSDictionary *)keyValues error:(NSError **)error;

/**
 *  同步删除
 *
 *  @param tableName  表名
 *  @param conditions 条件键值对。可传nil或者空字典
 *  @param error      错误信息
 *
 *  @return 成功与否
 */
- (BOOL)deleteFromTable:(NSString *)tableName whereCondition:(NSDictionary *)conditions error:(NSError **)error;

/**
 *  同步查询
 *
 *  @param tableName 表名
 *  @param fields    查询列。传nil即是所有列
 *  @param condition where sql (内部用了where 1=1 校验安全, condition sql请加上and, 待优化, 去掉这个1=1, 或其它API的condition统一都加1=1)
 *  @param error     error
 *
 *  @return FMResultSet
 */
- (FMResultSet *)selectFromTable:(NSString *)tableName fields:(NSArray *)fields where:(NSString *)condition error:(NSError **)error;

/**
 *  同步查询
 *
 *  @param tableName  表名
 *  @param keys       查询列。传nil即是所有列
 *  @param conditions 条件键值对。可传nil或者空字典
 *  @param error      错误信息
 *
 *  @return 成功与否
 */
- (FMResultSet *)selectFromTable:(NSString *)tableName withKeys:(NSArray *)keys whereConditions:(NSDictionary *)conditions error:(NSError **)error;

/**
 *  同步更新
 *
 *  @param tableName  表名
 *  @param keyValues  更新键值对
 *  @param conditions 条件键值对。可传nil或者空字典
 *  @param error      错误信息
 *
 *  @return 成功与否
 */
- (BOOL)updateTable:(NSString *)tableName setKeyValues:(NSDictionary *)keyValues whereConditions:(NSDictionary *)conditions error:(NSError **)error;

//异步
/**
 *  异步执行SQL
 *
 *  @param sql        SQL语句
 *  @param completion 回调(在主线程回调)
 */
- (void)executeSQLInDatabase:(NSString *)sql withCompletion:(void(^)(BOOL res, NSError * error, FMDatabase *db))completion;

/**
 *  插入
 *
 *  @param tableName  表名
 *  @param keyValues  插入键值对
 *  @param completion 回调(在主线程回调)
 */
- (void)insertIntoTable:(NSString*)tableName withKeyValues:(NSDictionary *)keyValues completion:(void (^)(NSError * error))completion;

/**
 *  replace
 *
 *  @param tableName  表名
 *  @param keyValues  插入键值对
 *  @param completion 回调(在主线程回调)
 */
- (void)replaceIntoTable:(NSString*)tableName withKeyValues:(NSDictionary *)keyValues completion:(void (^)(NSError * error))completion;

/**
 *  删除
 *
 *  @param tableName  表名
 *  @param conditions 条件键值对。可传nil或者空字典
 *  @param completion 回调(在主线程回调)
 */
- (void)deleteFromTable:(NSString *)tableName whereCondition:(NSDictionary *)conditions completion:(void (^)(NSError * error))completion;

/**
 *  查询
 *
 *  @param tableName  表名
 *  @param keys       查询列
 *  @param conditions 条件键值对。可传nil或者空字典
 *  @param completion 回调(在主线程回调)
 */
- (void)selectFromTable:(NSString *)tableName withKeys:(NSArray *)keys whereConditions:(NSDictionary *)conditions completion:(void(^)(FMResultSet *set, NSError * error))completion;

/**
 *  更新
 *
 *  @param tableName  表名
 *  @param keyValues  更新键值对
 *  @param conditions 条件键值对。可传nil或者空字典
 *  @param completion 回调(在主线程回调)
 */
- (void)updateTable:(NSString *)tableName setKeyValues:(NSDictionary *)keyValues whereConditions:(NSDictionary *)conditions completion:(void(^)(NSError * error))completion;

/**
 *  异步执行事务
 *
 *  @param block      事务内容块
 */
- (void)executeInTransationWithImplementBlock:(void (^)(FMDatabase *db, BOOL *rollback))block;

@end
