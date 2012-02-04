//
//  User.h
//  iOrm
//
//  Created by Scott Taylor on 2/3/12.
//  Copyright (c) 2012. All rights reserved.
//

#import "iOrm.h"

@interface User : iOrm {
    NSString *firstName;
    NSString *lastName;
}

@property (nonatomic, retain) NSString *firstName;
@property (nonatomic, retain) NSString *lastName;

@end
