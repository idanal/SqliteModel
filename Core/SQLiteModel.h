//
//  SQLiteModel.h
//
//  Danal.Luo QQ:290994669
//
//  Created by danal on 8/13/15.
//  Copyright (c) 2015 danal. All rights reserved.
//

#import <Foundation/Foundation.h>

/** 
 * A simple way to operate sqlite
 */
@interface SQLite : NSObject {
}
@property (nonatomic, readonly) BOOL isOpened;

/** Default access */
+ (instancetype)shared;

/** Copy db file to application support 
 * IF copy success, then open the db
 * @param srcPath Source db path
 * @return Destination db path
 */
- (NSString *)copyDB:(NSString *)srcPath;

/** Remove destination db file */
- (BOOL)removeDB:(NSString *)srcPath;

/** Database access */
- (BOOL)open:(NSString *)db;
- (BOOL)close;

/** Execute a sql statement */
- (BOOL)execSQL:(NSString *)sql;
- (const char *)errmsg;
- (unsigned long long)lastInsertRowid;

/** Transaction */
- (BOOL)beginTransaction;
- (BOOL)commitTransaction;
- (BOOL)rollbackTransaction;

@end


#pragma mark -
/**
 * SQLite data access object
 * It's not thread safe, you should always use it on main thread
 */
@interface SQLiteModel: NSObject
@property (nonatomic, strong) NSNumber *rowid; //The primary key

/** Return the table name
 * Attentation: The name is case sensitive
 */
+ (NSString *)tableName;

/** Return a sql used to create table */
+ (NSString *)tableSql;

/** Check if the table exists */
+ (BOOL)tableExists;

/** Read count with sql */
+ (NSNumber *)count;        //total count
+ (NSNumber *)count:(NSString *)format,...;

/** Query with sql */
+ (NSMutableArray *)findAll;    //all records
+ (NSMutableArray *)find:(NSString *)format,...;
+ (instancetype)findFirst:(NSString *)format,...;

//For Swift
+ (NSMutableArray *)findBy:(NSString *)sql;
+ (instancetype)findFirstBy:(NSString *)sql;

+ (BOOL)deleteAll:(NSString *)condition;
+ (BOOL)deleteAll;

//Query max value
+ (instancetype)findMaxValueOfField:(NSString *)field;

//Alter
+ (BOOL)addField:(NSString *)fieldName type:(NSString *)type; //type with modifier: INTEGER NOT NULL  DEFAULT 0

#pragma mark - modify
/** Modify */
- (BOOL)save;
- (BOOL)insert;
- (BOOL)update;
- (BOOL)destroy;

/** Callback when decoded a row to model */
- (void)onDecodeDone;

@end
