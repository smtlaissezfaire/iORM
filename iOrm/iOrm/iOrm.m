//
//  iOrm.m
//  iOrm
//
//  Created by Scott Taylor on 2/3/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "iOrm.h"
#import "assert.h"
#import "stdarg.h"
#import "iOrmSingleton.h"
#import <objc/runtime.h>
#import <objc/message.h>

@implementation iOrm

@synthesize id;

static NSString *__table_name__;
static NSArray *__columns__;

@interface iOrm (Private)
+ (int) __findQueryCount__:  (NSString *) stmt;
- (void) __setNewRecord__: (BOOL) val;
@end

+ (FMDatabase *) connection {
    return [iOrmSingleton connection];
}

+ (NSString *) tableName {
    if (__table_name__) {
        return __table_name__;
    }

    __table_name__ = NSStringFromClass(self);
    return __table_name__;
}

// lazy load column names in __columns__
+ (NSArray *) columns {
    if (__columns__) {
        return __columns__;
    }

    NSMutableArray *columns = [NSMutableArray arrayWithCapacity: 1];

    NSString *tableName = [self tableName];

    FMResultSet *results = [self executeSql: @"select sql from sqlite_master where tbl_name = ?", tableName];
    NSString *createTableStatement;
    if ([results next]) {
        createTableStatement = [results stringForColumn: @"sql"];
    } else {
        [NSException raise: @"TableError" format: @"Could not find a table named `%@`", tableName];
    }

    NSString *regexString = [NSString stringWithFormat: @"CREATE TABLE %@ \\((.*)\\)", tableName];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern: regexString
        options: NSRegularExpressionCaseInsensitive
        error: nil];

    NSString *createTableSubstring = [regex stringByReplacingMatchesInString: createTableStatement
                                                               options: NSRegularExpressionCaseInsensitive
                                                                 range: NSMakeRange(0, [createTableStatement length])
                                                          withTemplate:@"$1"];

    NSArray *columnsWithTypes = [createTableSubstring componentsSeparatedByString: @", "];

    for (NSString *columnWithType in columnsWithTypes) {
        NSArray *columnAndTypeSplit = [columnWithType componentsSeparatedByString: @" "];
        NSString *columnName = [columnAndTypeSplit objectAtIndex: 0];
        [columns addObject: columnName];
    }

    __columns__ = [columns copy];
    return __columns__;
}

+ (void) reloadColumns {
    __columns__ = nil;
    [self columns];
}

+ (int) __findQueryCount__:  (NSString *) stmt {
    sqlite3_stmt *pStmt = 0x00;
    sqlite3_prepare_v2([[self connection] sqliteHandle], [stmt UTF8String], -1, &pStmt, 0);
    sqlite3_finalize(pStmt);
    return sqlite3_bind_parameter_count(pStmt);
}

// Any SELECT returns NSArray *, everyhting else returns BOOL
+ (id) executeSql: (NSString *) sqlString, ... {
    int queryCount = [self __findQueryCount__: sqlString];

    NSMutableArray *array = [NSMutableArray arrayWithCapacity: 1];
    va_list args;
    va_start(args, sqlString);
    for (int i = 0; i < queryCount; i++) {
        NSString *arg = va_arg(args, NSString *);
        [array addObject: arg];
    }

    id out = [self executeSql: sqlString args: array];
    va_end(args);
    return out;
}

+ (id) executeSql: (NSString *) sqlString args: (NSArray *) args {
    FMDatabase *conn = [self connection];

    if ([[sqlString uppercaseString] rangeOfString: @"SELECT"].location == NSNotFound) {
        BOOL result = [conn executeUpdate: sqlString error: nil withArgumentsInArray: args orVAList: nil];

        if (!result) {
            [NSException raise: @"QueryError" format: @"Your query: %@ with arguments: %@ failed to execute properly! Error message: \"%@\"", sqlString, args, [conn lastErrorMessage]];
        }

        return [NSNumber numberWithBool: result];
    } else { // select
        return [conn executeQuery: sqlString withArgumentsInArray: args orVAList: nil];
    }
}

+ (NSArray *) findBySql: (NSString *) sqlString, ... {
    int queryCount = [self __findQueryCount__: sqlString];
    NSLog(@"queryCount: %i", queryCount);

    NSMutableArray *array = [NSMutableArray arrayWithCapacity: queryCount];
    va_list args;
    va_start(args, sqlString);
    for (int i = 0; i < queryCount; i++) {
        id arg = va_arg(args, id);
        [array addObject: arg];
    }

    id out = [self findBySql: sqlString args: array];
    va_end(args);

    return out;
}

+ (NSArray *) findBySql: (NSString *) sqlString args: (NSArray *) args {
    FMResultSet *results = [self executeSql: sqlString args: args];
    NSMutableArray *newCollection = [NSMutableArray arrayWithCapacity: 1];
    NSArray *columns = [self columns];

    while(1) {
        if ([results next]) {
            iOrm *obj = [[[self class] alloc] init];
            [obj __setNewRecord__: NO];

            int columnIndex = 0;
            for (NSString *columnName in columns) {
                struct objc_property *prop = class_getProperty(self, [columnName UTF8String]);
                const char *propString = property_getAttributes(prop);
                const char *strOffset;

                switch(propString[1]) {
                    case '@':
                        strOffset = &propString[3];

                        if (strstr(strOffset, "NSString") == strOffset) {
                            NSLog(@"setting %@ to %@", columnName, [results stringForColumnIndex: columnIndex]);
                            [obj setValue: [results stringForColumnIndex: columnIndex] forKey: columnName];
                        } else if (strstr(strOffset, "NSDate") == propString) {
                            [obj setValue: [results dateForColumnIndex: columnIndex] forKey: columnName];
                        } else if (strstr(strOffset, "NSData") == propString) {
                            [obj setValue: [results dataForColumnIndex: columnIndex] forKey: columnName];
                        } else if (strstr(strOffset, "NSBoolean") == propString) {
                            [obj setValue: [NSNumber numberWithBool: [results boolForColumnIndex: columnIndex]] forKey: columnName];
                        }  else {
                            [NSException raise: @"UnsupportedColumnType" format: @"Unsupported column type for column: `%@`", columnName];
                        }
                    break;

                    case 'i': // int
                    case 'I': // unsigned int
                    case 's': // short
                    case 'S': // unsigned short
                        [obj setValue: [NSNumber numberWithInt: [results intForColumnIndex: columnIndex]] forKey: columnName];
                    break;

                    case 'B':
                        [obj setValue: [NSNumber numberWithBool: [results boolForColumnIndex: columnIndex]] forKey: columnName];
                    break;

                    // case 'c': // char
                    // case 'C': // unsigned char
                    //     [obj setValue: [[results stringForColumnIndex: columnIndex] UTF8String][0] forKey: columnName];
                    // break;
                    //
                    // case '*': // char *
                    //     [obj setValue: [[results stringForColumnIndex: columnIndex] UTF8String] forKey: columnName];
                    // break;
                    //
                    // case 'l': // long
                    // case 'L': // unsigned long
                    //     [obj setValue: [results longForColumnIndex: columnIndex] forKey: columnName];
                    // break;
                    //
                    // case 'q': // long long
                    // case 'Q': // unsigned long long
                    //     [obj setValue: [results longLongForColumnIndex: columnIndex] forKey: columnName];
                    // break;
                    //
                    // case 'f': // float
                    // case 'd': // double
                    //     [obj setValue: [results doubleForColumnIndex: columnIndex] forKey: columnName];
                    // break;

                    default:
                        [NSException raise: @"UnsupportedColumnType" format: @"Unsupported type for columnName: %@", columnName];
                }

                columnIndex++;
            }

            [newCollection addObject: obj];
        } else {
            NSLog(@"no next result!");
            NSLog(@"sqlString: %@", sqlString);
            NSLog(@"args: %@", args);
            break;
        }
    }

    NSLog(@"newCollection: %@", newCollection);

    return [newCollection copy];
}

////////////////////////////////////////////////////

- (id)init
{
    if (self = [super init]) {
        __newRecord__ = YES;
    }

    return self;
}

- (BOOL) isNewRecord {
    return __newRecord__;
}

- (void) __setNewRecord__: (BOOL) val {
    __newRecord__ = val;
}

- (BOOL) save {
    NSMutableString *sqlString;
    NSArray *columns = [[self class] columns];
    NSString *tableName = [[self class] tableName];
    BOOL result;
    NSNumber *resultNum;

    NSMutableArray *columnNames = [NSMutableArray arrayWithCapacity: [columns count]];

    for (NSString *column in columns) {
        if (![column isEqualToString: @"id"]) {
            [columnNames addObject: column];
        }
    }

    NSLog(@"columnNames: %@", columnNames);

    NSMutableArray *values = [NSMutableArray arrayWithCapacity: [columnNames count]];

    for (id columnName in columnNames) {
        [values addObject: [self valueForKey: columnName]];
    }

    NSLog(@"values: %@", values);

    if ([self isNewRecord]) {
        int count = [columnNames count];
        NSString *columnNamesString = [columnNames componentsJoinedByString: @", "];
        NSMutableString *valuesString = [NSMutableString stringWithCapacity: count];

        for (int i = 0; i < count; i++) {
            if (i == count - 1) {
                [valuesString appendString: @"?"];
            } else {
                [valuesString appendString: @"?, "];
            }
        }

        NSLog(@"valuesString: %@", valuesString);

        sqlString = [NSString stringWithFormat: @"INSERT INTO %@ (%@) VALUES (%@)", tableName, columnNamesString, valuesString];
    } else {
        NSMutableArray *columnsAndValues = [NSMutableArray arrayWithCapacity: [columns count]];

        for (id columnName in columnNames) {
            [columnsAndValues addObject: [NSString stringWithFormat: @"%@ = ?", columnName]];
        }

        NSString *columnsAndValuesString = [columnsAndValues componentsJoinedByString: @", "];

        sqlString = [NSString stringWithFormat: @"UPDATE %@ SET %@ WHERE id = %i", tableName, columnsAndValuesString, self.id];
        NSLog(@"sqlString: %@", sqlString);
        NSLog(@"values: %@", values);
    }

    resultNum = [[self class] executeSql: sqlString args: values];
    result = [resultNum boolValue];

    if (result) {
        if (self.isNewRecord) {
            self.id = [[[self class] connection] lastInsertRowId];
        }
        __newRecord__ = NO;
    }

    return result;
}

- (void) reload {
    // [self where: [NSArray arrayWithObjects: @"id = %", self.id]
    //       limit: 1];
    id obj = [[self class] findBySql: @"select * from ? where id = ? limit 1", [[self class] tableName], self.id];
    for (NSString *col in [[self class] columns]) {
        [self setValue: [obj valueForKey: col] forKey: col];
    }
}

@end
