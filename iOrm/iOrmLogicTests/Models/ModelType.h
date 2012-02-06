//
//  ModelType.h
//  iOrm
//
//  Created by Scott Taylor on 2/6/12.
//  Copyright (c) 2012. All rights reserved.
//

#import "iOrm.h"

@interface ModelType : iOrm {
    NSString *nsstring;
    NSData *nsdata;
    NSDate *nsdate;
    int i;
    unsigned int ui;
    short s;
    unsigned short us;
    char c;
    unsigned char uc;
    long l;
    unsigned long ul;
    long long ll;
    unsigned long long ull;
    float f;
    double d;
    BOOL fakeBool;
    bool realBool;
}

@property (nonatomic, retain) NSString *nsstring;
@property (nonatomic, retain) NSData *nsdata;
@property (nonatomic, retain) NSDate *nsdate;
@property (nonatomic) int i;
@property (nonatomic) unsigned int ui;
@property (nonatomic) short s;
@property (nonatomic) unsigned short us;
@property (nonatomic) char c;
@property (nonatomic) unsigned char uc;
@property (nonatomic) long l;
@property (nonatomic) unsigned long ul;
@property (nonatomic) long long ll;
@property (nonatomic) unsigned long long ull;
@property (nonatomic) float f;
@property (nonatomic) double d;
@property (nonatomic) BOOL fakeBool;
@property (nonatomic) bool realBool;


@end
