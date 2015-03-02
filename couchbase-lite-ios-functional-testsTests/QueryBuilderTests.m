//
//  QueryBuilderTests.m
//  couchbase-lite-ios-functional-tests
//
//  Created by Ashvinder Singh on 2/23/15.
//  Copyright (c) 2015 couchbase. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <CouchbaseLite/CouchbaseLite.h>
#import <malloc/malloc.h>


@interface QueryBuilderTests : XCTestCase

@end

@implementation QueryBuilderTests {

CBLManager *manager;
CBLDatabase *database;

}

- (void) createDocuments: (unsigned)n {
    [database inTransaction:^BOOL{
        for (unsigned i=0; i<n; i++) {
            @autoreleasepool {
                CBLDocument* doc = [database createDocument];
                NSDictionary* properties = @{@"testName": @"testDatabase", @"sequence": @(i)};
                NSError* docerror;
                if (![doc putProperties: properties error: &docerror]) {
                    //XCTAssert(docerror, @"Could not add properties");
                }
            }
        }
        return YES;
    }];
}

- (void)setUp {
    [super setUp];
    NSError *error;
    manager = [[CBLManager alloc] init];
    XCTAssert(manager, @"Could not create manager");
    
    database = [manager databaseNamed: @"cbl-test-db" error: &error];
    XCTAssert(database, @"Cannot create database: %@",error);
    [self createDocuments:100];
    NSLog(@"Created Documents");

}

- (void)tearDown {
    NSError *error;
    XCTAssert([database deleteDatabase: &error], @"Cannot delete database: %@",error);
    database = nil;
    
    [manager close];
    manager = nil;
    
    [super tearDown];
}

- (void)createDocumentsWithJsonSchema1:(unsigned)number {

    for (unsigned i=0; i <= number; i++) {
        @autoreleasepool {
            NSDictionary* properties = @{     @"product" : @"String",
                                              @"version" : @"Constant number",
                                          @"releaseDate" : @"Future Date",
                                                 @"demo" : @"Boolean value",
                                              @"engineers" : @[@{},@{},@{} ]
                                                  
                                          };
            
        }
    }
    

}

- (void)testQueryBuilder {
    
    NSError* error;
    CBLQueryBuilder* b = [[CBLQueryBuilder alloc] initWithDatabase: database
                                                            select: @[@"sequence"]
                                                             where: @"testName == 'testDatabase' and sequence >= $MIN and sequence <= $MAX"
                                                           orderBy: nil
                                                             error: &error];


    CBLQueryBuilder* c = [[CBLQueryBuilder alloc] initWithDatabase: database
                                                            select: @[@"sequence"]
                                                             where: @"testName == 'testDatabase' and sequence == 1"
                                                           orderBy: nil
                                                             error: &error];

    XCTAssert(b, @"Failed to build: %@", error);
    NSLog(@"%@", b.explanation);
    NSLog(@"%@", c.explanation);
    NSNumber* num = @5;
    NSNumber* min = @5;
    NSNumber* max = @10;
    //CBLQueryEnumerator* e = [b runQueryWithContext: @{@"NUM":num} error: &error];
    CBLQueryEnumerator* e = [b runQueryWithContext: @{@"MIN":min, @"MAX":max} error: &error];
    CBLQueryEnumerator* f = [c runQueryWithContext: nil error: &error];
    XCTAssert(e, @"Query failed: %@", error);
    for (CBLQueryRow* row in e) {
        NSLog(@"My key= %@, Value= %@",row.key,row.value);
        //XCTAssert([row.documentID rangeOfString: @"AA"].length > 0);
    }

    
    for (CBLQueryRow* row in f) {
        NSLog(@"My key= %@, Value= %@",row.key,row.value);
        //XCTAssert([row.documentID rangeOfString: @"AA"].length > 0);
    }

}

@end
