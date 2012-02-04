//
//  iOrmSingleton.h
//  iOrm
//
//  Created by Scott Taylor on 2/3/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FMDatabase.h"

@interface iOrmSingleton : NSObject

+ (FMDatabase *) connection;
+ (void) setupConnectionWithPath: (NSString *) path;
+ (BOOL) closeConnection;

@end
