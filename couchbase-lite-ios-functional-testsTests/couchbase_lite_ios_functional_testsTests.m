//
//  couchbase_lite_ios_functional_testsTests.m
//  couchbase-lite-ios-functional-testsTests
//
//  Created by Ashvinder Singh on 11/13/14.
//  Copyright (c) 2014 couchbase. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <CouchbaseLite/CouchbaseLite.h>
#import <malloc/malloc.h>


@interface couchbase_lite_ios_functional_testsTests : XCTestCase

@end

@implementation couchbase_lite_ios_functional_testsTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testCreateManager {
    
    CBLManager *manager = [CBLManager sharedInstance];
    XCTAssert(manager, @"Could not create manager");
    
}

- (void) testCreateManagerWithCustomPath {
    
    NSString* dir = NSTemporaryDirectory();
    NSError* error;
    CBLManager *manager = [[CBLManager alloc] initWithDirectory: dir
                                                        options: NULL
                                                          error: &error];
    
    XCTAssert(manager, @"Cannot create Manager instance: %@", error);
    
}

- (void) testCreateManagerWithOptions {
    
    NSError* error;
    CBLManagerOptions options;
    options.readOnly = YES;
    CBLManager *manager = [[CBLManager alloc] initWithDirectory: CBLManager.defaultDirectory options: &options error: &error ];
    
    XCTAssert(manager, @"Cannot create Manager instance with custom options, %@",error);
    
    
}

- (void) testCreateDatabase {
    NSError *error;
    CBLManager *manager = [CBLManager sharedInstance];
    CBLDatabase *database = [manager databaseNamed: @"cbl-test-db" error: &error];
    
    XCTAssert(database, @"Cannot create database: %@",error);
    
    XCTAssert([database deleteDatabase: &error], @"Cannot delete database: %@",error);
    database = nil;
}

- (void) testCreateDocument {
    CBLManager *manager = [CBLManager sharedInstance];
    NSError *error;
    CBLDatabase *database = [manager databaseNamed: @"cbl-test-db" error: &error];
    NSString* dateStr = [CBLJSON JSONObjectWithDate: [NSDate date]];
    
    NSDictionary* props = @{@"sequence": @("1"),
                            @"date": dateStr};
    
    CBLDocument* doc = [database createDocument];
    
    NSError* doc_error;
    
    XCTAssert([doc putProperties: props error: &doc_error], @"Cannot create document with prop: %@ , error: %@",props, doc_error);
    XCTAssert([database deleteDatabase: &error], @"Cannot delete database: %@",error);
    
    database = nil;
    
}

- (void) testCreateDocWithCustomeID {
    NSError *error;
    CBLManager *manager = [CBLManager sharedInstance];
    CBLDatabase *database = [manager databaseNamed: @"cbl-test-db" error: &error];
    
    NSDictionary* properties = @{@"title":      @"Little, Big",
                                 @"author":     @"John Crowley",
                                 @"published":  @1982};
    CBLDocument* document = [database documentWithID: @"978-0061120053"];
    NSError *doc_error;
    
    XCTAssert([document putProperties: properties error: &doc_error],
              @"Cannot create document with prop: %@ , error: %@",
              properties, doc_error);
    XCTAssert([database deleteDatabase: &error], @"Cannot delete database: %@",error);
    
    database = nil;
}

- (void) testReadDocument {
    NSError *error;
    CBLManager *manager = [[CBLManager alloc]  init];
    CBLDatabase *database = [manager databaseNamed: @"testreaddocument" error: &error];
    
    if (!database) {
        NSLog(@"Cannot create database: %@",error);
        XCTAssert(NO, @"Failed");
    }
    
    NSDictionary* properties = @{@"title":      @"Little, Big",
                                 @"author":     @"John Crowley",
                                 @"published":  @1982};
    CBLDocument* document = [database documentWithID: @"408-0061120053"];
    NSError *doc_error;
    
    XCTAssert([document putProperties: properties error: &doc_error],
              @"Cannot create document with prop: %@ , error: %@",
              properties, doc_error);
    
    CBLDocument* new_doc = [database documentWithID: @"408-0061120053"];
    
    NSString* title = new_doc[@"title"];
    XCTAssert([title isEqualToString: @"Little, Big"], @"Title Matched");
    XCTAssert([database deleteDatabase: &error], @"Cannot delete database: %@",error);
    
    database = nil;
    
}

- (void) testUpdateDocumentWithPutProp {
    NSError *error;
    CBLManager *manager = [[CBLManager alloc]  init];
    CBLDatabase *database = [manager databaseNamed: @"testupdatedocument" error: &error];
    if (!database) {
        NSLog(@"Cannot create database: %@",error);
        XCTAssert(NO, @"Failed");
    }
    
    NSDictionary* properties = @{@"title":      @"Little, Big",
                                 @"author":     @"John Crowley",
                                 @"published":  @1982};
    CBLDocument* document = [database documentWithID: @"555-0061120053"];
    NSError *doc_error;
    
    XCTAssert([document putProperties: properties error: &doc_error],
              @"Cannot create document with prop: %@ , error: %@",
              properties, doc_error);
    
    CBLDocument* doc = [database documentWithID: @"555-0061120053"];
    NSMutableDictionary* p = [doc.properties mutableCopy];
    
    p[@"title"] = @"New Title";
    p[@"notes"] = @"New Notes";
    
    XCTAssert([doc putProperties: p error: &error], @"Unable to update values: %@",error);
    XCTAssert([database deleteDatabase: &error], @"Cannot delete database: %@",error);
    
    database = nil;
    
}

- (void) testDeleteDocument {
    NSError *error;
    CBLManager *manager = [CBLManager sharedInstance];
    CBLDatabase *database = [manager databaseNamed: @"cbl-test-db" error: &error];
    
    NSDictionary* properties = @{@"title":      @"Little, Big",
                                 @"author":     @"John Crowley",
                                 @"published":  @1982};
    CBLDocument* document = [database documentWithID: @"978-0061120053"];
    NSError *doc_error;
    
    XCTAssert([document putProperties: properties error: &doc_error],
              @"Cannot create document with prop: %@ , error: %@",
              properties, doc_error);
    XCTAssert([document deleteDocument: &error], @"Cannot delete document error: %@",doc_error);
    XCTAssert([database deleteDatabase: &error], @"Cannot delete database: %@",error);
    
    database = nil;
    
}

- (void) testDeleteDatabase {
    NSError* error;
    CBLManager *manager = [CBLManager sharedInstance];
    CBLDatabase *database = [manager databaseNamed: @"cbl-test-db" error: &error];
    
    XCTAssert([database deleteDatabase: &error], @"Cannot delete database: %@",error);
    
    database = nil;
    
}

- (void) testUpdateDocumentWithUpdateMethod {
    NSError *error;
    CBLManager *manager = [CBLManager sharedInstance];
    CBLDatabase *database = [manager databaseNamed: @"cbl-test-db" error: &error];
    
    
    
    NSDictionary* properties = @{@"title":      @"Little, Big",
                                 @"author":     @"John Crowley",
                                 @"published":  @1982};
    
    CBLDocument* doc = [database documentWithID: @"978-0061120053"];
    
    NSError *doc_error;
    
    XCTAssert([doc putProperties: properties error: &doc_error],
              @"Cannot create document with prop: %@ , error: %@",
              properties, doc_error);
    
    if (![doc update: ^BOOL(CBLUnsavedRevision *newRev) {
        newRev[@"title"] = @"new title";
        newRev[@"author"] = @"new author";
        return YES;
    } error: &error]) {
        XCTAssert(NO,@"Unable to update document %@",error);
    }
    
    XCTAssert([database deleteDatabase: &error], @"Cannot delete database: %@",error);
    database = nil;
}

- (void) testAllDocumentQuery {
    NSError *error;
    CBLManager *manager = [[CBLManager alloc]  init];
    CBLDatabase *database = [manager databaseNamed: @"cbl-test-db" error: &error];
    
    for (int i = 0; i < 10; i++) {
        @autoreleasepool {
            NSString* testString = [NSString stringWithFormat:@"teststring-%@", @(i)];
            NSDictionary* props = @{@"testString":testString,
                                    @"value": @1};
            CBLDocument* doc = [database createDocument];
            XCTAssert([doc putProperties: props error: &error],@"!!! Failed to create doc %@ %@", props,error);
        }
    }
    
    CBLQuery* query = [database createAllDocumentsQuery];
    query.allDocsMode = kCBLAllDocs;
    CBLQueryEnumerator* result = [query run: &error];
    XCTAssert(result.count == 10,@"Count did not match");
    
    for (CBLQueryRow* row in result) {
        NSLog(@"documentID: %@ docKey: %@ docValue: %@", row.documentID,row.key,row.value);
    }
    
    XCTAssert([database deleteDatabase: &error], @"Cannot delete database: %@",error);
    database = nil;
    [manager close];
    manager = nil;
}

- (void) testReduceQuery {
    NSError *error;
    CBLManager *manager = [[CBLManager alloc]  init];
    CBLDatabase *database = [manager databaseNamed: @"cbl-test-db" error: &error];
    
    for (int i = 0; i < 10; i++) {
        @autoreleasepool {
            NSString* testString = [NSString stringWithFormat:@"teststring-%@", @(i)];
            NSDictionary* props = @{@"testString":testString,
                                    @"value": @1};
            CBLDocument* doc = [database createDocument];
            XCTAssert([doc putProperties: props error: &error],@"!!! Failed to create doc %@ %@", props,error);
        }
    }
    
    CBLView* view = [database viewNamed: @"testview"];
    
    [view setMapBlock: MAPBLOCK({
        id s = [doc objectForKey: @"testString"];
        id value = [doc objectForKey: @"value"];
        if (s && value) emit(s,value);
    }) reduceBlock: REDUCEBLOCK({return @(values.count);})
              version: @"1"];
    
    CBLQuery* query = [[database viewNamed: @"testview"] createQuery];
    query.mapOnly = NO;
    CBLQueryEnumerator *rowEnum = [query run: &error];
    CBLQueryRow *row = [rowEnum rowAtIndex:0];
    
    NSLog(@"%@",row.value);
    
    XCTAssert([row.value isEqualToNumber: @10]);
    
    [view deleteView];
    XCTAssert([database deleteDatabase: &error], @"Cannot delete database: %@",error);
    database = nil;
    [manager close];
    manager = nil;
}

@end
