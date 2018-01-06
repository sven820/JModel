//
//  DBManager.m
//
//  Created by jinxiaofei on 16/7/15.
//  Copyright © 2016年 Guangzhou TalkHunt Information Technology Co., Ltd. All rights reserved.
//

#import "DBManager.h"
#import "DBModel.h"

@interface DBManager ()
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, DBHelper *> *dbHelps;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSString *> *dbNames;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSMutableArray *> *dbClasses;
@end

@implementation DBManager
+ (instancetype)shareManager
{
    static DBManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc]init];
        [instance initSetting];
    });
    return instance;
}
- (void)initSetting
{
#if TARGET_OS_IPHONE
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *baseDir = paths.firstObject;
    NSString *dataBaseDirectory = [baseDir stringByAppendingPathComponent:@"dataBase"];
    
#else
    NSString *appName = [[NSProcessInfo processInfo] processName];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? paths[0] : NSTemporaryDirectory();
    NSString *dataBaseDirectory = [[basePath stringByAppendingPathComponent:@"dataBase"] stringByAppendingPathComponent:appName];
#endif
    self.dbDir = dataBaseDirectory;
}

- (void)addDb:(NSString *)dbName dbKind:(NSInteger)dbKind;
{
    DBHelper *help = [[DBHelper alloc] init];
    [self.dbHelps setObject:help forKey:@(dbKind)];
    [self.dbNames setObject:dbName.length?dbName:[@(dbKind) stringValue] forKey:@(dbKind)];
}
- (DBHelper *)dbHelp:(NSInteger)dbKind
{
    return self.dbHelps[@(dbKind)];
}
- (void)initWithDbs
{
    for (NSNumber *dbKind in self.dbHelps.allKeys) {
        DBHelper *help = self.dbHelps[dbKind];
        NSString *dbName = self.dbNames[dbKind];
        if (![[NSFileManager defaultManager] fileExistsAtPath:self.dbDir]) {
            NSError *err = nil;
            if (![[NSFileManager defaultManager] createDirectoryAtPath:self.dbDir
                                           withIntermediateDirectories:YES
                                                            attributes:nil
                                                                 error:&err]) {
                NSLog(@"create db dir:%@ error: %@",self.dbDir, err);
            }
        }
        NSString *dBFile = [self.dbDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.db",dbName]];
        help.dbFile = dBFile;
        NSArray *classes = self.dbClasses[dbKind];
        
        @synchronized (help) { //防止多次重复initWithDbs造成的错误
            BOOL result = NO;
            for (NSString *clsStr in classes) {
                Class cls = NSClassFromString(clsStr);
                result = [cls createTable];
                if (!result) {
                    NSLog(@"db create table error, model cls:%@", clsStr);
                }
            }
            
            NSLog(@"db init over");
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DBManagerDbOpenedNotification
                                                                    object:self
                                                                  userInfo:@{@"dbKind":dbKind}];
            });
        }
        
    }
}
- (void)close
{
    for (NSNumber *dbKind in self.dbHelps) {
        [self.dbHelps[dbKind] close];
    }
    [self.dbHelps removeAllObjects];
    [self.dbNames removeAllObjects];
    [self.dbClasses removeAllObjects];
}
- (void)registerDbModelClass:(Class)cls
{
    if (![cls isSubclassOfClass:[DBModel class]]) return;
    NSString *clsStr = NSStringFromClass(cls);

    if ([cls respondsToSelector:@selector(dbKind)])
    {
        NSInteger dbKind = [cls dbKind];
        NSMutableArray *arr = self.dbClasses[@(dbKind)];
        if (!arr) {
            arr = [NSMutableArray array];
            [self.dbClasses setObject:arr forKey:@(dbKind)];
        }
        [arr addObject:clsStr];
    }
}

#pragma mark - private

#pragma mark - get
- (NSMutableDictionary<NSNumber *,NSMutableArray *> *)dbClasses
{
    if (!_dbClasses) {
        _dbClasses = [NSMutableDictionary dictionary];
    }
    return _dbClasses;
}
- (NSMutableDictionary<NSNumber *,NSString *> *)dbNames
{
    if (!_dbNames) {
        _dbNames = [NSMutableDictionary dictionary];
    }
    return _dbNames;
}
- (NSMutableDictionary<NSNumber *,DBHelper *> *)dbHelps
{
    if (!_dbHelps) {
        _dbHelps = [NSMutableDictionary dictionary];
    }
    return _dbHelps;
}
@end
