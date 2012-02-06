
iOrm
====

The basics of an ActiveRecord clone in Objective C (with hopefully less magic).

Usage:
------

### User.h

    #import "iOrm.h"

    @interface User : iOrm {
        NSString *firstName;
        NSString *lastName;
    }

    @property (nonatomic, retain) NSString *firstName;
    @property (nonatomic, retain) NSString *lastName;

    @end

### User.m

    #import "User.h"

    @implementation User
    @synthesize firstName;
    @synthesize lastName;
    @end

### Usage - saving + updating:

    User *user = [[User alloc] init];
    user.firstName = @"Scott";
    user.lastName = @"Taylor";
    [user save];

    user.id //=> 1

### Querying:

    NSArray *results = [User findBySql: @"firstName = ?", @"Scott"];
    [results count] //=> 1
    User *user = [results objectAtIndex: 0];
    user.firstName // => @"Scott"

### Executing raw sql:
    [iOrm executeSql: @"select * from user where first_name = ?", @"Scott"];
    // - this will not cast the objects back into a type, so you'll get a raw FMResultSet back
    // - anything other than a select just returns a BOOL = true.  Query errors NSException raise:format:

Conventions:
------------

* table name = class name (so 'user' for the 'User' class)
* id field is always named "id"
* column names = property names (only the properties with equivalent column names will be saved)
* db is always named db.sqlite3 (although can be set [iOrmSingleton setupConnectionWithPath])
