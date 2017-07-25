//
//  SQLiteModel.m
//  
//
//  Created by danal on 8/13/15.
//  Copyright (c) 2015 danal. All rights reserved.
//

#import "SQLiteModel.h"
#import <objc/runtime.h>
#import "sqlite3.h"

#if !__has_feature(objc_arc)
#error arc supports only
#endif

#ifdef DEBUG
#define SQL_LOG(...) NSLog(@"\n----------\n%@\n----------\n",[NSString stringWithFormat:__VA_ARGS__])
#else
#define SQL_LOG
#endif


typedef struct {
    enum {
        kTypeList = 0,
        kTypeCount
    } type;
    Class cls;
    long rowCount;
    NSMutableArray *list;
} SQLiteResult;

#pragma mark - SQLite

@interface SQLite (){
    sqlite3 *_handler;
}
@property (nonatomic, copy) NSString *dbPath;
- (sqlite3 *)sqlite;
@end

@implementation SQLite

int (_sqlite3_callback)(void* ptr, int cols, char** values, char** fields){

    if (ptr != NULL){
        SQLiteResult *p = (SQLiteResult *)ptr;
        switch (p->type){
            case SQLiteResult::kTypeList:{  //Parse list
                
                id obj = [p->cls new];      //Create a model instance
                [p->list addObject:obj];
                for (int i = 0; i < cols; i++){
                    const char *f = fields[i];
                    const char *v = values[i];
                    @try {
                        if (v != NULL){
                            [obj setValue:@(v) forKey:@(f)];
                        }
                    }
                    @catch (NSException *exception) {
                        SQL_LOG(@"    %s=%s err:%@",f, v, exception.description);
                    }
                }
                if ([obj isKindOfClass:[SQLiteModel class]]){
                    SQLiteModel *dao = obj;
                    [dao onDecodeDone];
                }
            }
                break;
            case SQLiteResult::kTypeCount:{  //Parse count
                p->rowCount = atol(values[0]);
            }
                break;
            default:
                break;
        }
        
    }
    return 0;
}

static SQLite *__sqlite = nil;
+ (instancetype)shared{
    @synchronized(self){
        if (!__sqlite) __sqlite = [[self alloc] init];
        return __sqlite;
    }
}

- (sqlite3 *)sqlite{
    return _handler;
}

- (NSString *)copyDB:(NSString *)srcPath{
    NSFileManager *fm = [NSFileManager defaultManager];

    NSString *bundle = [NSBundle mainBundle].infoDictionary[@"CFBundleName"];
    
    NSString *filename = [srcPath lastPathComponent];
    NSString *destPath = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject];
    destPath = [destPath stringByAppendingPathComponent:bundle];
    [fm createDirectoryAtPath:destPath withIntermediateDirectories:YES attributes:nil error:nil];
    destPath = [destPath stringByAppendingPathComponent:filename];
    
    
    if (![fm fileExistsAtPath:destPath]){
        [fm copyItemAtPath:srcPath toPath:destPath error:nil];
        
        //Save date as the db data version
        NSDictionary *attrs  = [fm attributesOfItemAtPath:srcPath error:nil];
        NSString *latestModify = attrs[@"NSFileModificationDate"];
        [[NSUserDefaults standardUserDefaults] setObject:latestModify forKey:NSStringFromClass(self.class)];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    SQL_LOG(@"Dest db path: %@",destPath);
    return destPath;
}

- (BOOL)removeDB:(NSString *)srcPath{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *filename = [srcPath lastPathComponent];
    NSString *bundle = [NSBundle mainBundle].infoDictionary[@"CFBundleName"];
    NSString *destPath = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject];
    destPath = [destPath stringByAppendingPathComponent:bundle];
    [fm createDirectoryAtPath:destPath withIntermediateDirectories:YES attributes:nil error:nil];
    destPath = [destPath stringByAppendingPathComponent:filename];
    return [fm removeItemAtPath:destPath error:nil];
}

- (BOOL)open:(NSString *)db{
    if (_isOpened) return YES;
    
    self.dbPath = db;
    _handler = NULL;
    _isOpened =  sqlite3_open(db.UTF8String, &_handler) == SQLITE_OK;
    return _isOpened;
}

- (BOOL)close{
    _isOpened = NO;
    return sqlite3_close(_handler) == SQLITE_OK;
}

- (const char *)errmsg{
    return sqlite3_errmsg(_handler);
}

- (BOOL)execSQL:(NSString *)sql{
    //SQL_LOG(@"    SQL: %@", sql);
    char *errmsg = NULL;
    if (sqlite3_exec(_handler, sql.UTF8String, NULL, NULL, &errmsg) == SQLITE_OK){
        return YES;
    } else {
        SQL_LOG(@"\r\n**********\r\nSQL Error: [%s] :Sql=%@\r\n**********", errmsg, sql);
        return NO;
    }
}

- (BOOL)execSQL:(NSString *)sql result:(SQLiteResult *)ptr{
    //SQL_LOG(@"    SQL: %@", sql);
    char *errmsg = NULL;
    if (sqlite3_exec(_handler, sql.UTF8String, _sqlite3_callback, ptr, &errmsg) == SQLITE_OK){
        return YES;
    } else{
        SQL_LOG(@"\r\n**********\r\nSQL Error: [%s] :Sql=%@\r\n**********", errmsg, sql);
        return NO;
    }
}

- (unsigned long long)lastInsertRowid{
    return sqlite3_last_insert_rowid(_handler);
}

- (BOOL)beginTransaction{
    sqlite3_exec(_handler, "BEGIN TRANSACTION", NULL, NULL, NULL);
    return NO;
}

- (BOOL)commitTransaction{
    sqlite3_exec(_handler, "COMMIT", NULL, NULL, NULL);
    return NO;
}

- (BOOL)rollbackTransaction{
    sqlite3_exec(_handler, "ROLLBACK", NULL, NULL, NULL);
    return NO;
}

@end

#pragma mark - SQLiteModel
@implementation SQLiteModel

/** Get all property names */
+ (void)iterateProperties:(id)obj onIterate:(void (^)(NSString *prop, NSString *propType))onIterate{
    Class cls = [obj class];
    while (cls) {
        if ([NSStringFromClass(cls) isEqualToString:@"SQLiteModel"]) break;
        
        unsigned int n = 0;
        const char *name, *type;
        objc_property_t *ps = class_copyPropertyList(cls, &n);
        for (unsigned int i = 0; i < n; i++){
            objc_property_t p = ps[i];
            name = property_getName(p);
            //const char *attrs = property_getAttributes(p);
            //Get property type
            Ivar var = class_getInstanceVariable(cls, [NSString stringWithFormat:@"_%s",name].UTF8String);
            type = ivar_getTypeEncoding(var);
            if (type != NULL && name != NULL){
                if (onIterate) onIterate(@(name), @(type));
            }
        }
        free(ps);
        
        cls = class_getSuperclass(cls);
    }
}

+ (NSString *)tableName{
    return NSStringFromClass([self class]);
}

+ (NSString *)tableSql{
    return nil;
}

+ (BOOL)tableExists{
    NSString *sql = [NSString stringWithFormat:
                     @"select count(*) from sqlite_master where type = 'table' and name = '%@'", [self tableName]];
    SQLiteResult p;
    p.rowCount = 0;
    p.type = SQLiteResult::kTypeCount;
    [[SQLite shared] execSQL:sql result:&p];
    return p.rowCount > 0;
}

+ (void)checkExistsAndCreate{
    if (![self tableExists]){
        NSString *sql = [self tableSql];
        if (sql.length){
            [[SQLite shared] execSQL:sql];
        }
    }
}

#pragma mark - Query

+ (NSNumber *)count{
    return [self count:nil];
}

+ (NSNumber *)count:(NSString *)format,...{
    NSMutableString *sql = [NSMutableString new];
    [sql appendFormat:@"select count(rowid) from %@",[self tableName]];
    if (format != nil){
        va_list ap;
        va_start(ap, format);
        [sql appendFormat:@" where %@", [[NSString alloc] initWithFormat:format arguments:ap]];
        va_end(ap);
    }
    
    SQLiteResult p;
    p.rowCount = 0;
    p.type = SQLiteResult::kTypeCount;
    [[SQLite shared] execSQL:sql result:&p];
    return @(p.rowCount);
}

+ (BOOL)deleteAll:(NSString *)condition{
    NSString *sql = [NSString stringWithFormat:@"delete from `%@`", [[self class] tableName]];
    if (condition){
        sql = [sql stringByAppendingFormat:@" where %@", condition];
    }
    return [[SQLite shared] execSQL:sql result:NULL];
}

+ (BOOL)deleteAll{
    NSString *sql = [NSString stringWithFormat:@"delete from `%@`", [self tableName]];
    return [[SQLite shared] execSQL:sql];
}

+ (NSMutableArray *)findAll{
    return [self find:nil];
}

+ (instancetype)findFirstBy:(NSString *)sql{
    return [[self findBy:[sql stringByAppendingString:@" limit 1"]] firstObject];
}

+ (NSMutableArray *)findBy:(NSString *)sql{
    [self checkExistsAndCreate];
    
    NSMutableArray *arr = [NSMutableArray new];
    SQLiteResult p;
    p.cls = [self class];
    p.list = arr;
    p.type = SQLiteResult::kTypeList;
    [[SQLite shared] execSQL:sql result:&p];
    /*
    sqlite3_stmt *stmt;
    int ret = sqlite3_prepare_v2([SQLite shared].sqlite, sql.UTF8String, -1, &stmt, NULL);
    if (ret == SQLITE_OK){
        int colCount = sqlite3_column_count(stmt);
        int colType = 0;
        const char *type;
        while ((ret = sqlite3_step(stmt))) {
            switch (ret) {
                case SQLITE_ROW:{
                    for (int i = 0; i < colCount; i++){
                        sqlite3_value *val = sqlite3_column_value(stmt, i);
                        type = sqlite3_column_decltype(stmt, i);
                        colType = sqlite3_value_type(val);
                        switch (colType) {
                            case SQLITE_INTEGER:{
                                sqlite3_int64 v = sqlite3_value_int64(val);
                            }
                                break;
                            case SQLITE_FLOAT:
                                
                                break;
                            case SQLITE_TEXT:
                                
                                break;
                            case SQLITE_NULL:
                                
                                break;
                            case SQLITE_BLOB:
                                
                                break;
                            default:
                                break;
                        }
                    }
                }
                    break;
                case SQLITE_DONE:{
                    goto done;
                }
                    break;
                case SQLITE_BUSY:{
                    goto done;
                }
                    break;
                default:
                    goto done;
                    break;
            }
        }
        
    } else {
        goto done;
    }
done:
    sqlite3_finalize(stmt);
     */
    return arr;
}

+ (NSMutableArray *)find:(NSString *)format,...{
    va_list ap;
    va_start(ap, format);
    return [self findBy:[self _formatSql:format arguments:ap tail:nil]];
}

+ (NSMutableArray *)findBy:(NSString *)limitOrOrder andQuery:(NSString *)format, ...{
    va_list ap;
    va_start(ap, format);
    return [self findBy:[self _formatSql:format arguments:ap tail:limitOrOrder]];
}

+ (instancetype)findFirst:(NSString *)format,...{
    va_list ap;
    va_start(ap, format);
    return [[self findBy:[self _formatSql:format arguments:ap tail:@"limit 1"]] firstObject];
}

+ (NSString *)_formatSql:(NSString *)format arguments:(va_list)ap tail:(NSString *)tail{
    NSMutableString *sql = [NSMutableString new];
    [sql appendFormat:@"select *,rowid rowid from %@",[self tableName]];
    if (format != nil){
        [sql appendFormat:@" where %@", [[NSString alloc] initWithFormat:format arguments:ap]];
    }
    if (tail != nil){
        [sql appendFormat:@" %@", tail];
    }
    return sql;
}

+ (instancetype)findMaxValueOfField:(NSString *)field{
    return [[self findBy:[NSString stringWithFormat:@"order by %@ desc", field]
                      andQuery:nil] firstObject];
}

+ (BOOL)addField:(NSString *)fieldName type:(NSString *)type{
    NSString *sql = [NSString stringWithFormat:@"ALTER TABLE `%@` ADD COLUMN `%@` %@", [self tableName], fieldName, type];
    return [[SQLite shared] execSQL:sql];
}

- (id)init{
    self = [super init];
    if (self){
    }
    return self;
}

- (BOOL)save{
    //if ([[self class] count:@"rowid = %@",self.rowid].integerValue == 0)
    if (self.rowid.integerValue == 0){
        return [self insert];
    } else {
        return [self update];
    }
}

- (BOOL)destroy{
    NSString *sql = [NSString stringWithFormat:@"delete from `%@` where rowid = %@", [[self class] tableName], self.rowid];
    return [[SQLite shared] execSQL:sql result:NULL];
}

- (BOOL)insert{

    [[self class] checkExistsAndCreate];
    
    NSMutableString *fields = [NSMutableString new];
    NSMutableString *values = [NSMutableString new];
    [[self class] iterateProperties:self onIterate:^(NSString *prop, NSString *type) {
        
        [fields appendFormat:@"%@,", prop];
        id val = [self valueForKey:prop];
        if (val == nil){
            [values appendString:@"null,"];
        } else if ([type containsString:NSStringFromClass(NSString.class)]){
            [values appendFormat:@"'%@',", val];
        } else {    //number or other unsupport types
            [values appendFormat:@"%@,", val];
        }
    }];
    
    if (values.length > 0){
        [values deleteCharactersInRange:NSMakeRange(values.length-1, 1)];
        [fields deleteCharactersInRange:NSMakeRange(fields.length-1, 1)];
    }
    
    NSString *sql = [NSString stringWithFormat:@"insert into `%@` (%@) values (%@)", [[self class] tableName], fields, values];
    if (![[SQLite shared] execSQL:sql]){
        return NO;
    }
    self.rowid = @([[SQLite shared] lastInsertRowid]);
    return YES;
}

- (BOOL)update{

    NSMutableString *values = [NSMutableString new];
    [[self class] iterateProperties:self onIterate:^(NSString *key, NSString *type) {

        id val = [self valueForKey:key];
        if (val == nil){
            [values appendFormat:@" `%@` = null,", key];
        } else if ([type containsString:NSStringFromClass(NSString.class)]){
            [values appendFormat:@" `%@` = '%@',", key, val];
        } else {    //number or other unsupport types
            [values appendFormat:@" `%@` = %@,", key, val];
        }
    
    }];
    if (values.length > 0){
        //Remove the last ','
        [values deleteCharactersInRange:NSMakeRange(values.length-1, 1)];
    }
    
    NSString *sql =  [NSString stringWithFormat:@"update `%@` set %@ where `rowid` = %@", [[self class] tableName], values, self.rowid];
    if (![[SQLite shared] execSQL:sql]){
        return NO;
    }
    return YES;
}

- (void)onDecodeDone{
    
}

- (NSString *)description{
    return [NSString stringWithFormat:@"<%@ rowid=%@ ...>", self.class, self.rowid];
}

@end
