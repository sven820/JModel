//
//  ViewController.m
//  JModel
//
//  Created by 靳小飞 on 2018/1/3.
//  Copyright © 2018年 靳小飞. All rights reserved.
//

#import "ViewController.h"
#import <YYModel.h>

#import "TestDbModel.h"

//打开dblog
#define DBLogOn
@interface ViewController ()
@property (nonatomic, assign) NSInteger uid;
@end

@implementation ViewController
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.uid = 1;
    
    [self initDb];
}

- (void)initDb
{
    //config
    [JDBModel setJmodelConfig:^(JModelConfig *defaultConf) {
        defaultConf->log = YES;
    }];
    //设置db 所在目录
    //    [DBManager shareManager].dbDir = @"";
    //添加db，每种kind对应一个db，每个db由DBHelp管理，
    [ShareDBHelper addDb:@"db_public" dbKind:DbKind_public];
    [ShareDBHelper addDb:[NSString stringWithFormat:@"db_user_%zd",self.uid] dbKind:DbKind_user];
    //注册需要初始化就创建表的model
    [ShareDBHelper registerDbModelClass:[TestDbModel class]];
    
    //初始化db和各个表
    [ShareDBHelper initWithDbs];
    
    //获取db对应的管理类
    DBHelper *helper_1 = DBHelper(DbKind_public);
}

//单主键
- (IBAction)insert:(id)sender {
    SubTestDbModel *t = [[SubTestDbModel alloc]init];
    t.name = @"test_3";
    t.pkId = 102;
    
    Teacher *t1 = [[Teacher alloc]init];
    t1.name = @"t1";
    t1.course = @"math";
    t.teacher = t1;
    
    t.dic = @{@"name": @"jinxiaofei", @"age": @(18)};
    t.url = [NSURL URLWithString:@"https://www.baidu.com"];
    t.attrStr = [[NSAttributedString alloc]initWithString:@"attr string"];
    t.date = [NSDate date];
    t.data = [@"data string" dataUsingEncoding:NSUTF8StringEncoding];
    
    t.nonDbKey = @"non db key";
    
    [t saveOrUpdate];
}
- (IBAction)update:(id)sender {
    TestDbModel *t = [[TestDbModel alloc]init];
    t.pkId = 100;
    t.name = @"name update 1";
//    [t update]; //全更新
    
    //只做部分更新，比如构造某个model，批量更新某些字段
//    [t saveOrUpdateByColumnName:@[@"pkId"] AndColumnValue:@[@(100)]];
    [t updateNonEmptyKeyValues];
}
- (IBAction)getTestModel:(id)sender {
    TestDbModel *t = [TestDbModel findFirstByCriteria:@"where pkId = 102" table:[TestDbModel tableNames].lastObject];
    NSLog(@"getTestModel name: %@", t.name);
    NSLog(@"getTestModel nsdata: %@", [[NSString alloc]initWithData:t.data encoding:NSUTF8StringEncoding]);
}
- (IBAction)deleteTest:(id)sender {
    [TestDbModel deleteObjectsByCriteria:@"where pkId = 100" table:[TestDbModel tableNames].lastObject];
}


//联合主键
//lazy create model table
- (IBAction)studentCreate:(id)sender {
    if (![Student isTableExist]) {
        BOOL res = [Student createTable];
        NSLog(@"student create res: %zd", res);
    }
    
    Student *s = [[Student alloc]init];
    s.name = @"jinxiaofei";
    s.className = @"c1";
    s.age = 18;
    
    Teacher *t1 = [[Teacher alloc]init];
    t1.name = @"t1";
    t1.course = @"math";
    Teacher *t2 = [[Teacher alloc]init];
    t2.name = @"t2";
    t2.course = @"music";
    
    s.teachers = @[t1, t2];
    
    [s saveOrUpdate];
}

//无主键
- (IBAction)teacherCreate:(id)sender {
    if (![Teacher isTableExist]) {
        BOOL res = [Teacher createTable];
        NSLog(@"Teacher create res: %zd", res);
    }
    
    Teacher *t1 = [[Teacher alloc]init];
    t1.name = @"t1";
    t1.course = @"math";
    
    // 无主键不用这种对象方法更新
//    [t1 saveOrUpdate];
    
    [t1 saveOrUpdateByColumnName:@[@"name"] AndColumnValue:@[@"t1"]];
}

//切换数据库
- (IBAction)switch:(id)sender {
    [ShareDBHelper close];
    self.uid ++;
    
    [self initDb];
}
@end
