//
//  JDBColumnDes.h
//
//  Created by JDBColumnDes on 16/3/21.
//  Copyright © 2016年 LK. All rights reserved.
//


// 此类为修饰类
#import <Foundation/Foundation.h>
/** 修饰 */
#define DEFAULT(value) @"DEFAULT value"//默认值
/** 限制值 */
#define CHECK(value) @"CHECK(value)" //限制值
/** 外键 */
#define FOREIGNKEY(foreignkey,talbeName,filed) @"FOREIGN KEY(foreignkey) REFERENCES talbeName(filed)"//设置外键

@interface JDBColumnDes : NSObject
/** db column名 */
@property (nonatomic, copy, readonly, getter=getInDbName)  NSString *inDbName;
/** 属性名 */
@property (nonatomic, copy)  NSString *propertyName;
/** 别名 */
@property (nonatomic, copy)  NSString *aliasName;
/** 默认值 */
@property (nonatomic, copy)  NSString *defaultValue;
/** 限制 */
@property (nonatomic, copy)  NSString *check;
/** 外键 */
@property (nonatomic, copy)  NSString *foreignKey;
/** 是否为主键 */
@property (nonatomic, assign, getter=isPrimaryKey)  BOOL      primaryKey;
/** 是否为联合主键 */
@property (nonatomic, assign, getter=isUnionKey) BOOL unionKey;
/** 是否为唯一 */
@property (nonatomic, assign, getter=isUnique)  BOOL      unique;
/** 是否为不为空 */
@property (nonatomic, assign, getter=isNotNull)  BOOL      notNull;
/** 是否为自动升序 如何为text就不能自动升序 */
@property (nonatomic, assign, getter=isAutoincrement)  BOOL      autoincrement;
/** 此属性是否不创建数据库字段 */
@property (nonatomic, assign, getter=isUseless) BOOL useless;

/**
 * 是主键
 */
+ (instancetype)primaryKeyDesc;
/**
 * 联合主键
 */
+ (instancetype)unionPrimaryKeyDesc;
/**
 * 非数据库字段
 */
+ (instancetype)uselessDesc;

/**
 *  主键便利构造器
 */
- (instancetype)initWithAuto:(BOOL)isAutoincrement isNotNull:(BOOL)notNull check:(NSString *)check defaultVa:(NSString *)defaultValue;
/**
 *  一般字段便利构造器
 */
- (instancetype)initWithgeneralFieldWithAuto:(BOOL)isAutoincrement  unique:(BOOL)isUnique isNotNull:(BOOL)notNull check:(NSString *)check defaultVa:(NSString *)defaultValue;

/**
 *  外键构造器
 */
- (instancetype)initWithFKFiekdUnique:(BOOL)isUnique isNotNull:(BOOL)notNull check:(NSString *)check default:(NSString *)defaultValue foreignKey:(NSString *)foreignKey;

/**
 *  生成修饰语句
 */
- (NSString *)finishModify;
@end
