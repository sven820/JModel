//
//  TestDbModel.h
//  JModel
//
//  Created by 靳小飞 on 2018/1/5.
//  Copyright © 2018年 靳小飞. All rights reserved.
//
#import "DBModel.h"
@class Student;
@class Teacher;

typedef NS_ENUM(NSUInteger, DBKind) {
    DbKind_public,
    DbKind_user,
};

@interface TestDbModel : DBModel

@property (nonatomic, strong) NSString *name;
//主键
@property (nonatomic, assign) NSInteger pkId;

@property (nonatomic, strong) NSString *emptyTest;

@property (nonatomic, strong) Teacher *teacher; //支持对象写入db
@property (nonatomic, strong) NSDictionary *dic; //支持json obj 写入db
@property (nonatomic, strong) NSURL *url; //支持 NSUrl
@property (nonatomic, strong) NSAttributedString *attrStr; //支持NSMutableString
@property (nonatomic, strong) NSDate *date; //支持 NSDate
@property (nonatomic, strong) NSData *data; //支持 NSData写入db
//非数据库字段
@property (nonatomic, strong) NSString *nonDbKey;
@end

@interface SubTestDbModel : TestDbModel
@end


@interface Student : DBModel
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *className;
@property (nonatomic, assign) NSInteger age;
@property (nonatomic, strong) NSArray<Teacher *> *teachers; //支持数组内对象写入db
@end

@interface Teacher : DBModel
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *course;
@end
