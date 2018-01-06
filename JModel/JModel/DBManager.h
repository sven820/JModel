//
//  DBManager.h
//
//  Created by jinxiaofei on 16/7/15.
//  Copyright © 2016年 Guangzhou TalkHunt Information Technology Co., Ltd. All rights reserved.
//

#import "DBHelper.h"

//数据库打开成功事件
#define DBManagerDbOpenedNotification      @"DBManagerShareDbOpenedNotification"// @{@"dbKind": @(dbKind)}

#define ShareDBHelper ([DBManager shareManager])
#define DBHelper(dbKind) ([ShareDBHelper dbHelp:dbKind])

@interface DBManager : NSObject
+ (instancetype)shareManager;
@property (nonatomic, strong) NSString *dbDir; //default: NSDocumentDirectory
//添加db，dbName=nil，则内部默认dbName=dbKind
//新加db，则需要调用一次initWithDbs；
- (void)addDb:(NSString *)dbName dbKind:(NSInteger)dbKind;

//获取db对应的管理类
- (DBHelper *)dbHelp:(NSInteger)dbKind;

//这里注册的类，会在initWithDbs方法初始化数据表
- (void)registerDbModelClass:(Class)cls;

//初始化db并创建数据库表
- (void)initWithDbs;
//切换用户后, 一定要close
- (void)close;

@end
