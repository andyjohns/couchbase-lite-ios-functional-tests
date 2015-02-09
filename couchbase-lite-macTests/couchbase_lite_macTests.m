//
//  couchbase_lite_macTests.m
//  couchbase-lite-macTests
//
//  Created by Ashvinder Singh on 1/21/15.
//  Copyright (c) 2015 couchbase. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import <CouchbaseLite/CouchbaseLite.h>
#include  "libcouchbase/couchbase.h"



@interface couchbase_lite_macTests : XCTestCase

@property CBLReplication *push;
@property CBLReplication *pull;

@end

@implementation couchbase_lite_macTests{
    CBLManager *manager;
    CBLDatabase *database;
    bool pushReplicationRunning;
    bool pullReplicationRunning;
    CBLReplication* _currentReplication;
    NSUInteger _expectedChangesCount;
    
}

- (void)setUp {
    [super setUp];
   
    NSError *error;
    
    manager = [[CBLManager alloc] init];
    XCTAssert(manager, @"Could not create manager");
    
    database = [manager databaseNamed: @"gamesim-sample" error: &error];
    XCTAssert(database, @"Cannot create database: %@",error);

}

- (void)tearDown {

    NSError *error;
    XCTAssert([database deleteDatabase: &error], @"Cannot delete database: %@",error);
    database = nil;
    
    [manager close];
    manager = nil;
    
    [super tearDown];

}

- (void) pushReplicationChanged: (NSNotificationCenter*)n {
    // Uncomment the following line to see the progress of replication
    // [self logFormat: @"Completed %d Out of total %d",self.push.completedChangesCount,self.push.changesCount];
    
    if (self.push.status == kCBLReplicationStopped) {
        // If do not see this line, it means there is no error
        if (self.push.lastError)
            //[self logSummary:[NSString stringWithFormat: @"*** Replication Stopped and error found - %@", push.lastError]];
        pushReplicationRunning = NO;
    }
}


- (void) pullReplicationChanged: (NSNotificationCenter*)n {
    // Uncomment the following line to see the progress of pull replication
    NSLog ( @"Pull: completed %d Out of total %d",self.pull.completedChangesCount,self.pull.changesCount);
    if (self.pull.status == kCBLReplicationStopped) {
        if (self.pull.lastError)
            NSLog(@"Pull replication Stopped and error found - %@", self.pull.lastError);
        pullReplicationRunning = NO;
    }
    NSLog(@"Document Count: %ld",database.documentCount);
}

- (void) runReplication: (CBLReplication*)repl expectedChangesCount: (unsigned)expectedChangesCount
{
    NSLog(@"Waiting for %@ to finish...",repl);
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(replChanged:)
                                                 name: kCBLReplicationChangeNotification
                                               object: repl];
    _currentReplication = repl;
    _expectedChangesCount = expectedChangesCount;
    bool started = false, done = false;
    
    [repl start];
    CFAbsoluteTime lastTime = 0;
    while (!done) {
        if (![[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode
                                      beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]])
            break;
        if (repl.running)
            started = true;
        if (started && (repl.status == kCBLReplicationStopped ||
                        repl.status == kCBLReplicationIdle))
            done = true;
        
        // Replication runs on a background thread, so the main runloop should not be blocked.
        // Make sure it's spinning in a timely manner:
        CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
        if (lastTime > 0 && now-lastTime > 0.25)
            NSLog(@"Runloop was blocked for %g sec", now-lastTime);
        lastTime = now;
    }
    NSLog(@"...replicator finished. mode=%u, progress %u/%u, error=%@",
        repl.status, repl.completedChangesCount, repl.changesCount, repl.lastError);
    
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                                    name: kCBLReplicationChangeNotification
                                                  object: _currentReplication];
    _currentReplication = nil;

    
}

- (void) replChanged: (NSNotification*)n {
    XCTAssert(n.object == _currentReplication, @"Wrong replication given to notification");
    NSLog(@"Replication status=%u; completedChangesCount=%u; changesCount=%u",
        _currentReplication.status, _currentReplication.completedChangesCount, _currentReplication.changesCount);
    XCTAssert(_currentReplication.completedChangesCount <= _currentReplication.changesCount, @"Invalid change counts");
    if (_currentReplication.status == kCBLReplicationStopped) {
        XCTAssertEqual(_currentReplication.completedChangesCount, _currentReplication.changesCount);
        if (_expectedChangesCount > 0) {
            XCTAssertNil(_currentReplication.lastError);
            XCTAssertEqual(_currentReplication.changesCount, _expectedChangesCount);
        }
    }
}

// Add Documents to couchbase server bucket using a python script having Couchbase SDK
// Verify all the documents are pull into local cblite db using pull replication

- (void)testAddDocsVerifyPullReplication {
    
    [[NSProcessInfo processInfo] processIdentifier];
    NSPipe *pipe = [NSPipe pipe];
    NSFileHandle *file = pipe.fileHandleForReading;
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/Users/ashvinder/mygit/couchbase_sdk.py";
    task.arguments = @[@"-n", @"10",@"-k",@"k",@"-v",@"v",@"-a"];
    task.standardOutput = pipe;
    
    [task launch];
    [task waitUntilExit];
    
    XCTAssert(task.terminationStatus == 0, @"Expecting 0 term status");
    
    // Give some time for shadow-bucket to catch up with server bucket
    [NSThread sleepForTimeInterval:4.0f];
    
    NSData *data = [file readDataToEndOfFile];
    [file closeFile];
    
    NSString *output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    NSLog (@"command Output:\n%@", output);
    
    
    NSURL* url = [NSURL URLWithString: @"http://10.3.5.183:4984/newbucket"];
    
    CBLReplication *pull = [database createPullReplication: url];
    pull.continuous = YES;
    
    [pull start];
    [self runReplication: pull expectedChangesCount: 10];
    NSLog(@"Document Count: %ld",database.documentCount);
    
}

- (void) testUpdateDocsFromSDKAndPull {
    [[NSProcessInfo processInfo] processIdentifier];
    NSPipe *pipe = [NSPipe pipe];
    NSFileHandle *file = pipe.fileHandleForReading;
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/Users/ashvinder/mygit/couchbase_sdk.py";
    task.arguments = @[@"-n", @"10",@"-k",@"k",@"-v",@"v",@"-u"];
    task.standardOutput = pipe;
    
    [task launch];
    [task waitUntilExit];
    
    XCTAssert(task.terminationStatus == 0, @"Expecting 0 term status");
    
    // Give some time for shadow-bucket to catch up with server bucket
    [NSThread sleepForTimeInterval:4.0f];
    
    NSData *data = [file readDataToEndOfFile];
    [file closeFile];
    
    NSString *output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    NSLog (@"command Output:\n%@", output);
    
    
    NSURL* url = [NSURL URLWithString: @"http://10.3.5.183:4984/newbucket"];
    
    CBLReplication *pull = [database createPullReplication: url];
    pull.continuous = YES;
    
    [pull start];
    [self runReplication: pull expectedChangesCount: 10];
    NSLog(@"Document Count: %ld",database.documentCount);
}

- (void) testDeleteDocsFromSDKAndPull {
    [[NSProcessInfo processInfo] processIdentifier];
    NSPipe *pipe = [NSPipe pipe];
    NSFileHandle *file = pipe.fileHandleForReading;
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/Users/ashvinder/mygit/couchbase_sdk.py";
    task.arguments = @[@"-n", @"10",@"-k",@"k",@"-v",@"v",@"-a"];
    task.standardOutput = pipe;
    
    [task launch];
    [task waitUntilExit];
    
    XCTAssert(task.terminationStatus == 0, @"Expecting 0 term status");
    
    // Give some time for shadow-bucket to catch up with server bucket
    [NSThread sleepForTimeInterval:4.0f];
    
    NSData *data = [file readDataToEndOfFile];
    [file closeFile];
    
    NSString *output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    NSLog (@"command Output:\n%@", output);
    
    
    NSURL* url = [NSURL URLWithString: @"http://10.3.5.183:4984/newbucket"];
    
    CBLReplication *pull = [database createPullReplication: url];
    pull.continuous = YES;
    
    [pull start];
    [self runReplication: pull expectedChangesCount: 10];
    NSLog(@"Document Count: %ld",database.documentCount);
    
}


- (void) testCBLAddDocsPushAndVerifyFromSDK {
    NSMutableString *str = [[NSMutableString alloc] init];
    int sizeOfDocument = 100;
    int numberOfDocs = 10;
    for (int i = 0; i < sizeOfDocument; i++) {
        [str appendString:@"1"];
    }
    
    NSDictionary* props = @{@"k": str};
    
    [database inTransaction:^BOOL{
        for (int j = 0; j < numberOfDocs; j++) {
            @autoreleasepool {
                CBLDocument* doc = [database createDocument];
                NSError* error;
                if (![doc putProperties: props error: &error]) {
                    NSLog(@"!!! Failed to create doc %@", props);
                    
                }
            }
        }
        return YES;
    }];
    
    NSURL* url = [NSURL URLWithString: @"http://10.3.5.183:4984/newbucket"];
    
    CBLReplication *push = [database createPushReplication: url];
    push.continuous = YES;
    
    [push start];
    [self runReplication: push expectedChangesCount: 10];
    NSLog(@"Document Count: %ld",database.documentCount);

    // Give some time for shadow-bucket to catch up with server bucket
    [NSThread sleepForTimeInterval:4.0f];
    
    [[NSProcessInfo processInfo] processIdentifier];
    NSPipe *pipe = [NSPipe pipe];
    NSFileHandle *file = pipe.fileHandleForReading;
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/Users/ashvinder/mygit/couchbase_sdk.py";
    task.arguments = @[@"-n", @"10",@"-k",@"k",@"-v",@"v",@"-c"];
    task.standardOutput = pipe;
    
    [task launch];
    [task waitUntilExit];
    
    XCTAssert(task.terminationStatus == 0, @"Expecting 0 term status");
    
    NSData *data = [file readDataToEndOfFile];
    [file closeFile];
    
    NSString *output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    NSLog (@"command Output:\n%@", output);

    
}

- (void)testCBLUpdateDocsPushAndVerifyFromSDK {
    
    NSMutableString *str = [[NSMutableString alloc] init];
    int sizeOfDocument = 100;
    int numberOfDocs = 10;
    for (int i = 0; i < sizeOfDocument; i++) {
        [str appendString:@"1"];
    }
    
    NSDictionary* props = @{@"k": str};
    
    [database inTransaction:^BOOL{
        for (int j = 0; j < numberOfDocs; j++) {
            @autoreleasepool {
                CBLDocument* doc = [database createDocument];
                NSError* error;
                if (![doc putProperties: props error: &error]) {
                    NSLog(@"!!! Failed to create doc %@", props);
                    
                }
            }
        }
        return YES;
    }];
    
    NSURL* url = [NSURL URLWithString: @"http://10.3.5.183:4984/newbucket"];
    
    CBLReplication *push = [database createPushReplication: url];
    push.continuous = YES;
    
    [push start];
    [self runReplication: push expectedChangesCount: 10];
    NSLog(@"Document Count: %ld",database.documentCount);
    
    // Give some time for shadow-bucket to catch up with server bucket
    [NSThread sleepForTimeInterval:4.0f];
    
    [[NSProcessInfo processInfo] processIdentifier];
    NSPipe *pipe = [NSPipe pipe];
    NSFileHandle *file = pipe.fileHandleForReading;
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/Users/ashvinder/mygit/couchbase_sdk.py";
    task.arguments = @[@"-n", @"10",@"-k",@"k",@"-v",@"v",@"-c"];
    task.standardOutput = pipe;
    
    [task launch];
    [task waitUntilExit];
    
    XCTAssert(task.terminationStatus == 0, @"Expecting 0 term status");
    
    NSData *data = [file readDataToEndOfFile];
    [file closeFile];
    
    NSString *output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    NSLog (@"command Output:\n%@", output);
    
    
}

- (void) testCBLDeleteDocsPushAndVerifyFromSDK {
    
}

- (void) testCBLAddDocsWithAttachmentAndVerifyFromSDK {

}

- (void) testCBLAddDocsDeleteAttachmentAndVerifyFromSDK {
    
}

- (void) testCBLDeleteBucketVerifyShadowBucket {
    
}

- (void) testDeleteShadowedBucket {

}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
