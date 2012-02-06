//
//  iOrm.h
//  iOrm
//
//  Created by Scott Taylor on 2/3/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FMResultSet.h"

@interface iOrm : NSObject {
    int id;
    BOOL __newRecord__;
}

@property (nonatomic) int id;

+ (FMDatabase *) connection;
+ (NSString *) tableName;
+ (NSArray *) columns;
+ (void) reloadColumns;
+ (id) executeSql: (NSString *) sqlString, ...;
+ (id) executeSql: (NSString *) sqlString args: (NSArray *) args;
+ (NSArray *) findBySql: (NSString *) sqlString, ...;
+ (NSArray *) findBySql: (NSString *) sqlString args: (NSArray *) args;

- (BOOL) isNewRecord;
- (BOOL) save;
- (void) reload;
@end
