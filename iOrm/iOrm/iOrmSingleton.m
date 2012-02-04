//
//  iOrmSingleton.m
//  iOrm
//
//  Created by Scott Taylor on 2/3/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "iOrmSingleton.h"

@implementation iOrmSingleton

static FMDatabase *__connection__;

+ (void) setupConnectionWithPath: (NSString *) path {
    __connection__ = [FMDatabase databaseWithPath: path];
    
    if (![__connection__ open]) {
        [NSException raise: @"DatabaseError" format: @"Database cannot be opened"];
    }
}

+ (FMDatabase *) connection {
    if (!__connection__) {
        [self setupConnectionWithPath: @"/db.sqlite3"];
    }
    
    return __connection__;
}

+ (BOOL) closeConnection {
    if (!__connection__ || ![__connection__ open]) {
        return YES;
    }

    return [__connection__ close];
}

@end
