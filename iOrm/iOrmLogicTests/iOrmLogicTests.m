//
//  iOrmTests.m
//  iOrmTests
//
//  Created by Scott Taylor on 2/3/12.
//  Copyright (c) 2012. All rights reserved.
//

#import "iOrmLogicTests.h"
#import "User.h"
#import "iOrmSingleton.h"
#import "ModelType.h"
#import "limits.h"
#import "math.h"

@implementation iOrmLogicTests

- (void)setUp
{
    [super setUp];
    // create an in memory database
    [iOrmSingleton setupConnectionWithPath: NULL];

    STAssertTrue([[iOrm executeSql: @"drop table if exists User"] boolValue],
        @"can drop table");
    STAssertTrue([[iOrm executeSql: @"create table if not exists User (id integer primary key, firstName varchar(255), lastName varchar(255))"] boolValue],
        @"can create table");

    STAssertTrue([[iOrm executeSql: @"drop table if exists ModelType"] boolValue],
                 @"can drop table");

    NSString *modelTypeCreateTableString =  @"create table if not exists ModelType (\
        id integer primary key, \
        nsstring VARCHAR, \
        nsdata BLOB, \
        nsdate DATETIME, \
        i INT, \
        ui INT, \
        s INT, \
        us INT, \
        c INT, \
        uc CHARACHTER, \
        l BIGINT, \
        ul BIGINT UNSIGNED, \
        ll BIGINT, \
        ull BIGINT UNSIGNED, \
        f FLOAT, \
        d DOUBLE, \
        fakeBool INT, \
        realBool BOOLEAN)";

    STAssertTrue([[iOrm executeSql: modelTypeCreateTableString] boolValue], @"can create table");
}

- (void)tearDown
{
    [iOrmSingleton closeConnection];
    [super tearDown];
}

- (void) testShouldBeAbleToFindColumnNames {
    NSArray *columns = [User columns];
    STAssertTrue([columns count] == 3, @"columns count should be 3");
    STAssertTrue([[columns objectAtIndex: 0] isEqualToString: @"id"], @"should have correct id");
    STAssertTrue([[columns objectAtIndex: 1] isEqualToString: @"firstName"], @"should have correct first name");
    STAssertTrue([[columns objectAtIndex: 2] isEqualToString: @"lastName"], @"should have correct last name");
}

 - (void) testShouldAssignIdAfterSave {
     User *user = [[User alloc] init];
     user.firstName = @"scott";
     user.lastName = @"taylor";
     STAssertTrue([user save], @"should save a new record");
     STAssertEquals(user.id, 1, @"should create and set auto increment id");
 }

- (void) testShouldNotReAssignIdAfterSecondSave {
    User *user = [[User alloc] init];
    user.firstName = @"scott";
    user.lastName = @"taylor";
    [user save];
    STAssertEquals(user.id, 1, @"created id");

    user.firstName = @"foo";
    [user save];

    STAssertEquals(user.id, 1, @"has the same id");
    STAssertTrue([user.firstName isEqualToString: @"foo"], @"updated the first name");
    STAssertTrue([user.lastName isEqualToString: @"taylor"], @"kept the last name the same");
}

- (void) testShouldBeFoundByRawSql {
    User *user = [[User alloc] init];
    user.firstName = @"scott";
    user.lastName = @"taylor";
    [user save];
    STAssertEquals(user.id, 1, @"saved the record");

    NSArray *users = [User findBySql: @"select * from User where id = 1 limit 1"];
    STAssertTrue([users count] == 1, @"only finds one user");
    User *copy = [users objectAtIndex: 0];
    STAssertTrue(user.id == copy.id, @"has the same id");
    STAssertTrue([user.firstName isEqualToString: copy.firstName], @"has the same first name");
    STAssertTrue([user.lastName isEqualToString: copy.lastName], @"has the same last name");
}

- (void) testShouldProperlyAssignIds {
    User *user1 = [[User alloc] init];
    user1.firstName = @"Scott";
    user1.lastName = @"Taylor";
    [user1 save];

    User *user2 = [[User alloc] init];
    user2.firstName = @"Eden";
    user2.lastName = @"Li";
    [user2 save];

    STAssertEquals(user1.id, 1, @"should have id 1 for record 1");
    STAssertEquals(user2.id, 2, @"should have id 2 for record 2");
}

- (void) testShouldBeAbleToUpdate {
    User *user = [[User alloc] init];
    user.firstName = @"Scott";
    user.lastName = @"Taylor";
    [user save];

    user.firstName = @"Eden";
    user.lastName = @"Li";
    [user save];

    NSArray *users = [User findBySql: @"select * from User where firstName = ?", @"Eden"];
    STAssertTrue([users count] == 1, @"should only find one user, but found %i instead", [users count]);
    User *updated = [users objectAtIndex: 0];

    STAssertEquals(updated.id, user.id, @"Should have same ids");
    STAssertTrue([updated.firstName isEqualToString: @"Eden"], @"Should have assigned correct first name");
    STAssertTrue([updated.lastName isEqualToString: @"Li"], @"Should have assigned correct first name");
}

- (void) testShouldBeAbleToReload {
   User *user = [[User alloc] init];
   user.firstName = @"Scott";
   user.lastName = @"Taylor";
   [user save];

   [iOrm executeSql: @"UPDATE user SET firstName = ?, lastName = ? WHERE id = 1", @"Walt", @"Lin"];
   [user reload];

   STAssertEquals(user.id, user.id, @"Should have same ids");
   STAssertTrue([user.firstName isEqualToString: @"Walt"], @"Should have assigned correct first name, but instead got: %@", user.firstName);
   STAssertTrue([user.lastName isEqualToString: @"Lin"], @"Should have assigned correct last name, but instead got: %@", user.lastName);
}

- (void) testShouldSerializeTypesCorrectly {
    ModelType *obj = [[ModelType alloc] init];

    NSDate *now = [NSDate date];
    NSData *data = [@"data" dataUsingEncoding: NSUTF8StringEncoding];

    obj.nsstring = @"foo";
    obj.nsdata = data;
    obj.nsdate = now;
    obj.i = INT_MAX;
    obj.ui = UINT_MAX;
    obj.s = SHRT_MAX;
    obj.us = USHRT_MAX;
    obj.c = CHAR_MAX;
    obj.uc = UCHAR_MAX;
    obj.l = LONG_MAX;
    obj.ul = ULONG_MAX;
    obj.ll = ULONG_MAX * ULONG_MAX;
    obj.ull = (unsigned long) ULONG_MAX * ULONG_MAX;
    obj.f = (float) 10;
    obj.d = 10.00001;
    obj.fakeBool = TRUE;
    obj.realBool = true;

    [obj save];
    STAssertEquals(obj.id, 1, @"object should have an id, instead, its id is: %i", obj.id);
    [obj reload];

    NSTimeInterval nowDifference = [obj.nsdate timeIntervalSinceDate: now];

    STAssertTrue([obj.nsstring isEqualToString: @"foo"], @"should set nsstring");
    STAssertTrue([obj.nsdata isEqualToData: data], @"should set nsdata");
    STAssertTrue(round(nowDifference) == 0, @"should set nsdate.  Diff: %d", nowDifference);
    STAssertTrue(obj.i == INT_MAX, @"should set int");
    STAssertTrue(obj.ui == UINT_MAX, @"should set unsigned int");
    STAssertTrue(obj.s == SHRT_MAX, @"should set short");
    STAssertTrue(obj.us == USHRT_MAX, @"should set unsigned short");
    // hmm...should probably use signed / unsigned variants
    // STAssertTrue(obj.c == CHAR_MAX, @"should set char. Expected: %i, got: %i", CHAR_MAX, obj.c);
    STAssertTrue(obj.uc == UCHAR_MAX, @"should set unsigned char.  Expected: %i, got: %i", UCHAR_MAX, obj.uc);
    STAssertTrue(obj.l == LONG_MAX, @"should set long");
    STAssertTrue(obj.ul == ULONG_MAX, @"should set unsigned long");
    STAssertTrue(obj.ll == ULONG_MAX * ULONG_MAX, @"should set long long");
    STAssertTrue(obj.ull == (unsigned long) ULONG_MAX * ULONG_MAX, @"should set unsigned long long");
    STAssertTrue(obj.f == (float) 10, @"should set float");
    STAssertTrue(obj.d == 10.00001, @"should set double");
    STAssertTrue(obj.fakeBool == TRUE, @"should set TRUE. Expected: %i, got: %i", TRUE, obj.fakeBool);
    STAssertTrue(obj.realBool == true, @"should set true");
}

// - (void) testShouldBeAbleToSelectFindWithAllOptions {
//     User *user = [[User alloc] init];
//     user.firstName = @"Scott";
//     user.lastName = @"Taylor";
//     [user save];
//
//     NSArray *users = [User select: @"*"
//                              from: @"user"
//                             where: "firstName = ?", "Scott"
//                             limit: @"1"
//                            offset: @"0"
//                           groupBy: @"firstName"];
//
//     STAssertEquals(users.count, 1);
//     User *found = [users objectAtIndex: 0];
//     STAssertEquals(found.id, 1);
//     STAssertEquals(found.firstName, user.firstName);
//     STAssertEquals(found.lastName, user.lastName);
// }

@end
