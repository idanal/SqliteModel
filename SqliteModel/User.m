//
//  User.h
//  MusouKit
//
//  Created by danal on 13-3-26.
//  Copyright (c) 2013年 danal. All rights reserved.
//

#import "User.h"

@implementation User

+ (NSString *)tableName{
    return @"user";
}

+ (NSString *)tableSql{
    return @"create table user (    \
    id integer AUTO_INCREMENT, \
    name varchar(64) not null,  \
    age integer,    \
    primary key(id) \
    )";
}

@end
