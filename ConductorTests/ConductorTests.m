//
//  ConductorTests.m
//  ConductorTests
//
//  Created by Andrew Smith on 10/21/11.
//  Copyright (c) 2011 Andrew B. Smith ( http://github.com/drewsmits ). All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy 
// of this software and associated documentation files (the "Software"), to deal 
// in the Software without restriction, including without limitation the rights 
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies 
// of the Software, and to permit persons to whom the Software is furnished to do so, 
// subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included 
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "ConductorTests.h"

#import "CDOperation.h"
#import "CDTestOperation.h"
#import "CDLongRunningTestOperation.h"

@implementation ConductorTests

- (void)testConductorAddOperation {
    
    __block BOOL hasFinished = NO;
    
    void (^completionBlock)(void) = ^(void) {
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            hasFinished = YES;        
        });
    };         
    
    CDTestOperation *op = [CDTestOperation operation];
    op.completionBlock = completionBlock;
    
    [conductor addOperation:op];
    
    STAssertNotNil([conductor getQueueForOperation:op], @"Conductor should have queue for operation");
    
    NSDate *loopUntil = [NSDate dateWithTimeIntervalSinceNow:0.2];
    while (conductor.hasQueues) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:loopUntil];
    }    
            
    STAssertTrue(hasFinished, @"Conductor should add and complete test operation");
}

- (void)testConductorAddOperationToQueueNamed {
    
    __block BOOL hasFinished = NO;
    
    void (^completionBlock)(void) = ^(void) {
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            hasFinished = YES;        
        });
    };         
    
    CDTestOperation *op = [CDTestOperation operation];
    op.completionBlock = completionBlock;
    
    [conductor addOperation:op toQueueNamed:@"CustomQueueName"];
            
    STAssertNotNil([conductor getQueueNamed:@"CustomQueueName"], @"Conductor should have queue for operation");
    
    NSDate *loopUntil = [NSDate dateWithTimeIntervalSinceNow:0.2];
    while (conductor.hasQueues) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:loopUntil];
    }    
    
    STAssertTrue(hasFinished, @"Conductor should add and complete test operation");
}

- (void)testConductorAddOperationThreeTimes
{    
    CDTestOperation *op1 = [CDLongRunningTestOperation operation];
    CDTestOperation *op2 = [CDLongRunningTestOperation operation];
    CDTestOperation *op3 = [CDLongRunningTestOperation operation];

    [conductor addOperation:op1];
    [conductor addOperation:op2];
    [conductor addOperation:op3];

    STAssertEquals(conductor.queues.count, 1U, @"Conducter should only have one queue");
}

- (void)testConductorUpdateQueuePriority
{
    
}

- (void)testConductorIsExecuting
{    
    CDTestOperation *op = [CDTestOperation operation];
    
    [conductor addOperation:op];
    
    STAssertTrue([conductor isExecuting], @"Conductor should be running");
    
    NSDate *loopUntil = [NSDate dateWithTimeIntervalSinceNow:0.2];
    while ([conductor isExecuting]) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:loopUntil];
    }    
    
    STAssertFalse([conductor isExecuting], @"Conductor should not be executing");
}

- (void)testConducturIsQueueExecutingNamed
{
    NSString *customQueue = @"CustomQueueName";
    CDTestOperation *op = [CDTestOperation operation];
    [conductor addOperation:op toQueueNamed:customQueue];
    
    BOOL isExecuting = [conductor isQueueExecutingNamed:customQueue];
    STAssertTrue(isExecuting, @"Queue named should be executing");
    
    [conductor waitForQueueNamed:customQueue];
    
    isExecuting = [conductor isQueueExecutingNamed:customQueue];
    STAssertFalse(isExecuting, @"Queue named should be executing");
}

- (void)testConductorCancelAllOperations {
        
    CDLongRunningTestOperation *op = [CDLongRunningTestOperation operation];
    
    [conductor addOperation:op toQueueNamed:@"CustomQueueName"];
    
    [conductor cancelAllOperations];
        
    STAssertTrue(op.isCancelled, @"Operation should be cancelled");
}

- (void)testConductureCancelAllOperationsInQueueNamed {
    CDLongRunningTestOperation *op = [CDLongRunningTestOperation operation];
    
    [conductor addOperation:op toQueueNamed:@"CustomQueueName"];
    
    [conductor cancelAllOperationsInQueueNamed:@"CustomQueueName"];
    
    STAssertTrue(op.isCancelled, @"Operation should be cancelled");
}

- (void)testConductorSuspendAllQueues {
    CDLongRunningTestOperation *op = [CDLongRunningTestOperation operation];
    
    [conductor addOperation:op toQueueNamed:@"CustomQueueName"];
    
    [conductor suspendAllQueues];
    
    CDOperationQueue *queue = [conductor getQueueNamed:@"CustomQueueName"];
    
    STAssertTrue(queue.isSuspended, @"Operation queue should be suspended");
}

- (void)testConductorSuspendQueueNamed {
    CDLongRunningTestOperation *op = [CDLongRunningTestOperation operation];
    
    [conductor addOperation:op toQueueNamed:@"CustomQueueName"];
    
    [conductor suspendQueueNamed:@"CustomQueueName"];
    
    CDOperationQueue *queue = [conductor getQueueNamed:@"CustomQueueName"];
    
    STAssertTrue(queue.isSuspended, @"Operation queue should be suspended");    
}

- (void)testConductorResumeAllQueues
{
    NSString *customQueue = @"CustomQueueName";

    __block BOOL hasFinished = NO;
    void (^completionBlock)(void) = ^(void) {
        hasFinished = YES;        
    };         
    
    CDLongRunningTestOperation *op = [CDLongRunningTestOperation longRunningOperationWithDuration:2.0];
    op.completionBlock = completionBlock;
    
    [conductor addOperation:op toQueueNamed:customQueue];
    
    [conductor suspendAllQueues];
    [conductor resumeAllQueues];
    
    // Loop until queue finishes
    NSDate *loopUntil = [NSDate dateWithTimeIntervalSinceNow:0.5];
    while (hasFinished == NO) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:loopUntil];
    }
    
    STAssertTrue(hasFinished, @"Conductor should add and complete test operation");
}

- (void)testConductorResumeQueueNamed
{
    NSString *customQueue = @"CustomQueueName";
    
    __block BOOL hasFinished = NO;
    void (^completionBlock)(void) = ^(void) {
        hasFinished = YES;        
    };         
    
    CDLongRunningTestOperation *op = [CDLongRunningTestOperation longRunningOperationWithDuration:2.0];
    op.completionBlock = completionBlock;
    
    [conductor addOperation:op toQueueNamed:customQueue];
    
    [conductor suspendQueueNamed:customQueue];
    [conductor resumeQueueNamed:customQueue];
    
    // Loop until queue finishes
    NSDate *loopUntil = [NSDate dateWithTimeIntervalSinceNow:0.5];
    while (hasFinished == NO) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:loopUntil];
    }
    
    STAssertTrue(hasFinished, @"Conductor should add and complete test operation");
}

//- (void)testConductorTryToBreakIt {
//    
//    NSString *customQueueName = @"CustomQueueName2";
//    
//    [conductor setMaxConcurrentOperationCount:1 forQueueNamed:customQueueName];
//    
////    [conductor addProgressObserverToQueueNamed:customQueueName
////                             withProgressBlock:nil
////                            andCompletionBlock:completionBlock];
//
//    
//    for (int i = 0; i < 50; i++) {
//        CDLongRunningTestOperation *op = [CDLongRunningTestOperation longRunningOperationWithDuration:0.3];
//        [conductor addOperation:op toQueueNamed:customQueueName];
//    }
//    
//    [conductor cancelAllOperations];
//    
//    
//    __block BOOL completionBlockDidRun = NO;
//    
//    CDOperationQueueProgressObserverCompletionBlock completionBlock = ^(void) {
//        completionBlockDidRun = YES;
//    };
//    
//    [conductor addProgressObserverToQueueNamed:customQueueName
//                             withProgressBlock:nil
//                            andCompletionBlock:completionBlock];
//    
//    CDLongRunningTestOperation *op = [CDLongRunningTestOperation longRunningOperationWithDuration:5.0];
//    [conductor addOperation:op toQueueNamed:customQueueName];
//        
//    CDOperationQueue *queue = [conductor queueForQueueName:customQueueName shouldCreate:NO];
//    
//    NSDate *loopUntil = [NSDate dateWithTimeIntervalSinceNow:0.1];
//    while (completionBlockDidRun == NO) {
//        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
//                                 beforeDate:loopUntil];
//    }
//    
//    NSDate *loopUntil2 = [NSDate dateWithTimeIntervalSinceNow:0.2];
//    while (queue.isExecuting == YES) {
//        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
//                                 beforeDate:loopUntil2];
//    }
//    
//    NSLog(@"finished!");
//}

@end
