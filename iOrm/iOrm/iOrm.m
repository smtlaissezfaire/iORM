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

static NSMutableDictionary *__tablesMetadata__ = nil;

@interface iOrm (Private)
+ (int) __findQueryCount__:  (NSString *) stmt;
+ (NSArray *) __findColumnTypesFromColumns__: (NSArray *) columns;
- (void) __setNewRecord__: (BOOL) val;
@end

enum iOrmColumnTypes {
    iOrmColumnTypesNSString = 1,
    iOrmColumnTypesNSDate,
    iOrmColumnTypesNSData,
    iOrmColumnTypesInt,
    iOrmColumnTypesBoolean,
    iOrmColumnTypesChar,
    iOrmColumnTypesLong,
    iOrmColumnTypesLongLong,
    iOrmColumnTypesFloat,
};

+ (void) initialize {
    if (!__tablesMetadata__) {
        __tablesMetadata__ = [NSMutableDictionary dictionary];
    }
}

+ (FMDatabase *) connection {
    return [iOrmSingleton connection];
}

+ (NSString *) tableName {
    return NSStringFromClass(self);
}

+ (NSArray *) columnTypes {
    NSString *tableName = [self tableName];
    return [[__tablesMetadata__ objectForKey: tableName] objectForKey: @"column_types"];
}

// lazy load column names in __columns__
+ (NSArray *) columns {
    NSString *tableName = [self tableName];
    NSDictionary *info;
    NSArray *columnNames;

    if ((info = [__tablesMetadata__ objectForKey: tableName])) {
        columnNames = [info objectForKey: @"columns"];

        if (columnNames) {
            return columnNames;
        }
    }

    NSMutableArray *columns = [NSMutableArray arrayWithCapacity: 1];

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
        NSArray *columnAndTypeSplit = [[columnWithType stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
            componentsSeparatedByString: @" "];
        NSString *columnName = [columnAndTypeSplit objectAtIndex: 0];
        [columns addObject: columnName];
    }

    NSArray *columnsCopy = [columns copy];
    NSArray *columnTypes = [self __findColumnTypesFromColumns__: columnsCopy];
    NSMutableDictionary *tableData = [NSMutableDictionary dictionary];
    [tableData setObject: columnsCopy forKey: @"columns"];
    [tableData setObject: columnTypes forKey: @"column_types"];
    [__tablesMetadata__ setObject: [tableData copy] forKey: tableName];
    return columnsCopy;
}

+ (NSArray *) __findColumnTypesFromColumns__: (NSArray *) columns {
    NSMutableArray *columnTypes = [NSMutableArray array];

    int columnIndex = 0;
    for (NSString *columnName in columns) {
        int columnType;

        struct objc_property *prop = class_getProperty(self, [columnName UTF8String]);
        const char *propString = property_getAttributes(prop);
        const char *strOffset;

        switch(propString[1]) {
            case '@':
                strOffset = &propString[3];
                if (strstr(strOffset, "NSString") == strOffset) {
                    columnType = iOrmColumnTypesNSString;
                } else if (strstr(strOffset, "NSDate") == strOffset) {
                    columnType = iOrmColumnTypesNSDate;
                } else if (strstr(strOffset, "NSData") == strOffset) {
                    columnType = iOrmColumnTypesNSData;
                } else {
                    [NSException raise: @"UnsupportedColumnType" format: @"Unsupported column type for column: `%@`", columnName];
                }
            break;

            case 'i': // int
            case 'I': // unsigned int
            case 's': // short
            case 'S': // unsigned short
                columnType = iOrmColumnTypesInt;
            break;

            case 'B':
                columnType = iOrmColumnTypesBoolean;
            break;

            case 'c': // char
            case 'C': // unsigned char
                columnType = iOrmColumnTypesChar;
            break;

            case '*': // char * - not supported, because NSKeyValueCoding doesn't support it
                [NSException raise: @"UnsupportedColumnType" format: @"char * is not a supported column type.  Use NSString * instead"];
            break;

            case 'l': // long
            case 'L': // unsigned long
                columnType = iOrmColumnTypesLong;
            break;

            case 'q': // long long
            case 'Q': // unsigned long long
                columnType = iOrmColumnTypesLongLong;
            break;

            case 'f': // float
            case 'd': // double
                columnType = iOrmColumnTypesFloat;
            break;

            default:
                [NSException raise: @"UnsupportedColumnType" format: @"Unsupported type for columnName: %@", columnName];
        }

        [columnTypes addObject: [NSNumber numberWithInteger: columnType]];
        columnIndex++;
    }

    return [columnTypes copy];
}

+ (void) reloadTableData {
    [__tablesMetadata__ removeObjectForKey: [self tableName]];
    [self columns];
}

+ (int) __findQueryCount__:  (NSString *) stmt {
    sqlite3_stmt *pStmt = 0x00;
    sqlite3_prepare_v2([[self connection] sqliteHandle], [stmt UTF8String], -1, &pStmt, 0);
    sqlite3_finalize(pStmt);
    return sqlite3_bind_parameter_count(pStmt);
}

// Any SELECT returns NSArray *, every thing else returns BOOL
+ (id) executeSql: (NSString *) sqlString, ... {
    int queryCount = [self __findQueryCount__: sqlString];
    NSMutableArray *array = [NSMutableArray arrayWithCapacity: 1];
    va_list args;
    va_start(args, sqlString);
    for (int i = 0; i < queryCount; i++) {
        id arg = va_arg(args, id);
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
    NSArray *columnTypes = [self columnTypes];

    while([results next]) {
        iOrm *obj = [[[self class] alloc] init];
        [obj __setNewRecord__: NO];

        int columnIndex = 0;
        for (NSString *columnName in columns) {
            int columnType = [[columnTypes objectAtIndex: columnIndex] intValue];

            switch (columnType) {
                case iOrmColumnTypesNSString:
                    [obj setValue: [results stringForColumnIndex: columnIndex] forKey: columnName];
                break;

                case iOrmColumnTypesNSDate:
                    [obj setValue: [results dateForColumnIndex: columnIndex] forKey: columnName];
                break;

                case iOrmColumnTypesNSData:
                    [obj setValue: [results dataForColumnIndex: columnIndex] forKey: columnName];
                break;

                case iOrmColumnTypesInt:
                    [obj setValue: [NSNumber numberWithInt: [results intForColumnIndex: columnIndex]] forKey: columnName];
                break;

                case iOrmColumnTypesBoolean:
                    [obj setValue: [NSNumber numberWithBool: [results boolForColumnIndex: columnIndex]] forKey: columnName];
                break;

                case iOrmColumnTypesChar:
                    [obj setValue: [NSNumber numberWithChar: [results intForColumnIndex: columnIndex]] forKey: columnName];
                break;

                case iOrmColumnTypesLong:
                    [obj setValue: [NSNumber numberWithLong:[results longForColumnIndex: columnIndex]] forKey: columnName];
                break;

                case iOrmColumnTypesLongLong:
                    [obj setValue: [NSNumber numberWithLongLong: [results longLongIntForColumnIndex: columnIndex]] forKey: columnName];
                break;

                case iOrmColumnTypesFloat:
                    [obj setValue: [NSNumber numberWithDouble:[results doubleForColumnIndex: columnIndex]] forKey: columnName];
                break;
            }

            columnIndex++;
        }

        [newCollection addObject: obj];
    }

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

    NSMutableArray *values = [NSMutableArray arrayWithCapacity: [columnNames count]];

    for (id columnName in columnNames) {
        [values addObject: [self valueForKey: columnName]];
    }

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

        sqlString = [NSString stringWithFormat: @"INSERT INTO %@ (%@) VALUES (%@)", tableName, columnNamesString, valuesString];
    } else {
        NSMutableArray *columnsAndValues = [NSMutableArray arrayWithCapacity: [columns count]];

        for (id columnName in columnNames) {
            [columnsAndValues addObject: [NSString stringWithFormat: @"%@ = ?", columnName]];
        }

        NSString *columnsAndValuesString = [columnsAndValues componentsJoinedByString: @", "];

        sqlString = [NSString stringWithFormat: @"UPDATE %@ SET %@ WHERE id = %i", tableName, columnsAndValuesString, self.id];
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
    NSString *query = [NSString stringWithFormat: @"select * from %@ where id = %i limit 1", [[self class] tableName], self.id];
    NSArray *objects = [[self class] findBySql: query];
    FMDatabase *conn = [[self class] connection];

    if ([objects count] == 0) {
        [NSException raise: @"ReloadError" format: @"Could not reload object.  last_error: \"%@\"", [conn lastErrorMessage]];
    }

    iOrm *obj = [objects objectAtIndex: 0];
    for (NSString *col in [[self class] columns]) {
        if ([col isEqualToString: @"id"]) {
            self.id = obj.id;
        } else {
            [self setValue: [obj valueForKey: col] forKey: col];
        }
    }
}

@end
