//
//  User.h
//  MusouKit
//
//  Created by danal on 13-3-26.
//  Copyright (c) 2013年 danal. All rights reserved.
//

#import "SQLiteModel.h"

@interface User : SQLiteModel
@property (copy, nonatomic) NSString *name;
@property (assign, nonatomic) NSInteger age;
@end
