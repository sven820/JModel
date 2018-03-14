//
//  JDBModel.h
//
//  Created by jinxiaofei on 16/3/21.
//  thank for github https://github.com/544523660/LKFMDB

#import <Foundation/Foundation.h>
#import <FMDB/FMDB.h>
#import <YYModel/YYModel.h>

#import "JDBColumnDes.h"

/** SQLite五种数据类型 */
#define SQLTEXT     @"TEXT"
#define SQLINTEGER  @"INTEGER"
#define SQLREAL     @"REAL"
#define SQLBLOB     @"BLOB"
#define SQLNULL     @"NULL"

typedef struct{
    BOOL log;
    //多条数据处理时，是否一旦某条出错就回滚，default NO；
    BOOL rollback_once_err;
}JModelConfig;
/**
 * 1.数据库字段与注册的类class或调用的class有关，父类子类属性均不计入数据库字段
    在设计model时，可单独设计某个层级model为数据库专用，其它派生通过继承即可，注意私有属性也会加入表，请酌情设计db层的model，
 * 2.支持联合主键，具体通过JDBColumnDes描述
 * 3.所有非async开头的方法均为同步，异步请调用async开头的方法
 * 4.所有单个对象操作，都没有作事务操作，对象集合操作都进行了事务操作
 * 5.支持model -> table 一对多 （比如你想将消息记录到两个表，一个个人消息，一个群消息）
 */
@interface JDBModel : NSObject<YYModel>
/** lastInsertRowId */
@property (nonatomic, assign)   int        lastInsertRowId;
/** 属性名 */
@property (retain, readonly, nonatomic) NSMutableArray         *propertyNames;
/** 列类型 */
@property (retain, readonly, nonatomic) NSMutableArray         *columeTypes;
/** 列名 */
@property (retain, readonly, nonatomic) NSMutableArray         *columeNames;

#pragma mark 常用方法
+ (void)setJmodelConfig:(void(^)(JModelConfig *defaultConf))config;
/**
 * 是否存在
 */
- (BOOL)isExist;
/** 保存或更新
 * 如果不存在，保存，
 * 有，则更新，如果表没指定主键，不会做作任何操作，请使用下面saveOrUpdateByColumnName：方法(其它同理)
 */
- (BOOL)saveOrUpdate;
/** 保存或更新
 * 如果根据特定的列数据可以获取记录，则更新，只更新当前model有值的，nil判为空，可作批量更新某些字段
 * 没有记录，则保存
 */
- (BOOL)saveOrUpdateByColumnName:(NSArray*)columnNames AndColumnValue:(NSArray*)columnValues;
/** 保存单个数据 */
- (BOOL)save;
/** 批量保存数据 */
+ (BOOL)saveObjects:(NSArray *)array;
+ (BOOL)saveOrUpdateObjects:(NSArray *)array;

/** 更新单个数据 */
- (BOOL)update;
/** 更新非空字段 */
- (BOOL)updateNonEmptyKeyValues;
/** 批量更新数据*/
+ (BOOL)updateObjects:(NSArray *)array;

/** 删除单个数据*/
- (BOOL)deleteObject;
/** 批量删除数据 */
+ (BOOL)deleteObjects:(NSArray *)array;
/** 通过条件删除数据 */
+ (BOOL)deleteObjectsByCriteria:(NSString *)criteria;
/** 通过条件删除 (多参数）--2 */
+ (BOOL)deleteObjectsWithFormat:(NSString *)format, ...;

/** 查询全部数据 */
+ (NSArray *)findAll;
+ (instancetype)findFirstWithFormat:(NSString *)format, ...;
/** 查找某条数据 */
+ (instancetype)findFirstByCriteria:(NSString *)criteria;
+ (NSArray *)findWithFormat:(NSString *)format, ...;
/** 通过条件查找数据
 * 这样可以进行分页查询 @" WHERE pk > 5 limit 10"
 */
+ (NSArray *)findByCriteria:(NSString *)criteria;
/**
 * 通过条件查找数据
 * SELECT max(sortId)FROM 'XX' WHERE "criteria", field为查找的列
 */
+ (NSArray *)findByCriteria:(NSString *)criteria field:(NSArray *)fields;
/**
 * 创建表
 * 如果已经创建，返回YES,model字段变更，表会自动变更
 */

+ (BOOL)createTable;
/** 清空表 */
+ (BOOL)clearTable;
#pragma mark - 针对类方法 可指定具体表名，以上没指定的都是first tableName
+ (BOOL)deleteObjectsByCriteria:(NSString *)criteria table:(NSString *)tableName;
+ (BOOL)deleteObjects:(NSString *)tableName withFormat:(NSString *)format, ...;
+ (NSArray *)findAll:(NSString *)tableName;
+ (instancetype)findFirst:(NSString *)tableName withFormat:(NSString *)format, ...;
+ (instancetype)findFirstByCriteria:(NSString *)criteria table:(NSString *)tableName;
+ (NSArray *)find:(NSString *)tableName withFormat:(NSString *)format, ...;
+ (NSArray *)findByCriteria:(NSString *)criteria table:(NSString *)tableName;
+ (NSArray *)findByCriteria:(NSString *)criteria field:(NSArray *)fields table:(NSString *)tableName;
+ (BOOL)clearTable:(NSString *)tableName;

#pragma mark - async
- (void)asyncSaveOrUpdate:(void(^)(BOOL res))complete;
- (void)asyncSaveOrUpdateByColumnName:(NSArray*)columnNames AndColumnValue:(NSArray*)columnValues complete:(void(^)(BOOL res))complete;
- (void)asyncSave:(void(^)(BOOL res))complete;
+ (void)asyncSaveObjects:(NSArray *)array complete:(void(^)(BOOL res))complete;
+ (void)asyncSaveOrUpdateObjects:(NSArray *)array complete:(void(^)(BOOL res))complete;
- (void)asyncUpdate:(void(^)(BOOL res))complete;
- (void)asyncUpdateNonEmptyKeyValues:(void(^)(BOOL res))complete;
+ (void)asyncUpdateObjects:(NSArray *)array complete:(void(^)(BOOL res))complete;
- (void)asyncDeleteObject:(void(^)(BOOL res))complete;
+ (void)asyncDeleteObjects:(NSArray *)array complete:(void(^)(BOOL res))complete;
+ (void)asyncDeleteObjectsByCriteria:(NSString *)criteria complete:(void(^)(BOOL res))complete;
+ (void)asyncFindAll:(void(^)(NSArray *))complete;
+ (void)asyncFindByCriteria:(NSString *)criteria field:(NSArray *)fields complete:(void(^)(NSArray *))complete;
#pragma mark 必须要重写的方法
/** 如果子类中有一些property不需要创建数据库字段,或者对字段加修饰属性   具体请参考JDBColumnDes类*/
+ (NSDictionary *)describeColumnDict;
/**
 * 执行数据库处理的dbQueue
 */
+ (FMDatabaseQueue *)dbQueue;
#pragma mark 可选要重写的方法
/**
 * 表名, 默认@[className]，支持model -> table 一对多 （比如你想将消息记录到两个表，一个个人消息，一个群消息）
 */
+ (NSArray *)tableNames;
/**
 * 对象最终存储表名，默认tableNames first
 */
- (NSString *)tableName;
/**
 * 格式化日期 default：@"yyyy-MM-dd, HH:mm:ss"
 */
+ (NSString *)dateFormat;
/**
 * 当前类log控制开关，default yes;
 */
+ (BOOL)logForThisClass;
/**
 * 指定数据库表的class
 */
+ (Class)tableClass;
#pragma mark 不重要的方法
/**
 *  获取该类的所有属性
 */
+ (NSDictionary *)getPropertys;

/** 获取所有属性，包括主键 */
+ (NSDictionary *)getAllProperties;

/** 数据库中是否存在表 */
+ (BOOL)isTableExist;
- (BOOL)isTableExist;

/** 表中的字段*/
+ (NSArray *)getColumns:(NSString *)tableName;
- (NSArray *)getColumns;
@end
