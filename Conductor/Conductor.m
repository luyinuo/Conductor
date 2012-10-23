//
//  Conductor.m
//  Conductor
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

#import "Conductor.h"

@implementation Conductor

- (id)init
{
    self = [super init];
    if (self) {
        _queues = [[NSMutableDictionary alloc] init];
        self.removeQueuesWhenEmpty = YES;
    }
    return self;
}

+ (id)sharedInstance
{
    static Conductor *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [self conductor];
    });
    return _sharedInstance;
}

+ (Conductor *)conductor
{
    return [self new];
}

#pragma mark - Queues

- (void)removeQueue:(CDOperationQueue *)queue
{
    if (!self.removeQueuesWhenEmpty) return;
    if (!queue || queue.isExecuting) return;

    NSAssert(queue.name, @"Queue should have a name!");
    
    @synchronized (self.queues) {
        ConductorLogTrace(@"Removing queue: %@", queue.name);
        [self.queues removeObjectForKey:queue.name];
    }
}

- (NSArray *)allQueueNames
{
    return [self.queues allKeys];
}

- (BOOL)hasQueues
{
    return (self.queues.count > 0);
}

#pragma mark - Operations

- (void)addOperation:(CDOperation *)operation
{
    [self addOperation:operation atPriority:operation.queuePriority];
}

- (void)addOperation:(CDOperation *)operation 
          atPriority:(NSOperationQueuePriority)priority
{    
    NSString *queueName = [self queueNameForOperation:operation];
    
    [self addOperation:operation
          toQueueNamed:queueName
            atPriority:priority];
}

- (void)addOperation:(CDOperation *)operation 
        toQueueNamed:(NSString *)queueName
{        
    [self addOperation:operation 
          toQueueNamed:queueName 
            atPriority:operation.queuePriority];
}

- (void)addOperation:(CDOperation *)operation 
        toQueueNamed:(NSString *)queueName 
          atPriority:(NSOperationQueuePriority)priority
{        
    CDOperationQueue *queue = nil;
    
    if (queueName) {
        queue = [self queueForQueueName:queueName shouldCreate:YES];
    } else {
        queue = [self queueForOperation:operation shouldCreate:YES];
    }
    
    ConductorLogTrace(@"Adding operation to queue: %@", queue.name);
        
    // Add and start operation
    [queue addOperation:operation atPriority:priority];
}

- (BOOL)updatePriorityOfOperationWithIdentifier:(NSString *)identifier 
                                  toNewPriority:(NSOperationQueuePriority)priority
{    
    __block BOOL didUpdate = NO;
    
    [self.queues enumerateKeysAndObjectsUsingBlock:^(id queueName, CDOperationQueue *queue, BOOL *stop) {
        if ([queue updatePriorityOfOperationWithIdentifier:queue toNewPriority:priority]) {
            didUpdate = YES;
            *stop = YES;
        }
    }];

    return didUpdate;
}

- (BOOL)hasOperationWithIdentifier:(NSString *)identifier 
                      inQueueNamed:(NSString *)queueName
{
    if (!identifier) return NO;
    
    CDOperationQueue *queue = [self queueForQueueName:queueName shouldCreate:NO];
    
    if (!queue) return NO;
    
    return ([queue getOperationWithIdentifier:identifier] != nil);
}

#pragma mark - Executing

- (BOOL)isExecuting
{
    __block BOOL isExecuting = NO;
    
    // Make sure queues don't change while determining execution status
    @synchronized (self.queues)
    {
        [self.queues enumerateKeysAndObjectsUsingBlock:^(id queueName, CDOperationQueue *queue, BOOL *stop) {
            if (queue.isExecuting) {
                isExecuting = YES;
                *stop = YES;
            }
        }];
        
    };
    
    return isExecuting;
}

- (BOOL)isQueueExecutingNamed:(NSString *)queueName
{
    CDOperationQueue *queue = [self queueForQueueName:queueName shouldCreate:NO];
    if (!queue) return NO;
    return queue.isExecuting;
}

- (NSUInteger)numberOfOperationsInQueueNamed:(NSString *)queueName
{
    CDOperationQueue *queue = [self queueForQueueName:queueName shouldCreate:NO];
    if (!queue) return 0;
    return [queue operationCount];
}

#pragma mark - Cancel

- (void)cancelAllOperations
{
    ConductorLogTrace(@"Cancel all operations");
    
    // Grabbing queue names prevents mutation while enumeration of queues dict
    NSArray *queuesNamesToCancel = [self allQueueNames]; 
    
    for (NSString *queueName in queuesNamesToCancel) {
        [self cancelAllOperationsInQueueNamed:queueName];
    }
}

- (void)cancelAllOperationsInQueueNamed:(NSString *)queueName
{
    if (!queueName) return;
    ConductorLogTrace(@"Cancel all operations in queue: %@", queueName);
    CDOperationQueue *queue = [self getQueueNamed:queueName];
    [queue cancelAllOperations];
    [self removeQueue:queue];
}

#pragma mark - Suspend

- (void)suspendAllQueues
{
    ConductorLogTrace(@"Suspend all queues");
    
    // Grabbing queue names prevents mutation while enumeration of queues dict
    NSArray *queuesNamesToSuspend = [self allQueueNames]; 
    
    for (NSString *queueName in queuesNamesToSuspend) {
        [self suspendQueueNamed:queueName];
    }
}

- (void)suspendQueueNamed:(NSString *)queueName
{
    if (!queueName) return;
    ConductorLogTrace(@"Suspend queue: %@", queueName);
    CDOperationQueue *queue = [self getQueueNamed:queueName];;
    [queue setSuspended:YES];
}

#pragma mark - Resume

- (void)resumeAllQueues
{
    ConductorLogTrace(@"Resume all queues");
    
    // Grabbing queue names prevents mutation while enumeration of queues dict
    NSArray *queuesNamesToResume = [self allQueueNames];
    
    for (NSString *queueName in queuesNamesToResume) {
        [self resumeQueueNamed:queueName];
    }    
}

- (void)resumeQueueNamed:(NSString *)queueName
{
    if (!queueName) return;
    ConductorLogTrace(@"Resume queue: %@", queueName);
    CDOperationQueue *queue = [self getQueueNamed:queueName];;
    [queue setSuspended:NO];    
}

#pragma mark - Wait

- (void)waitForQueueNamed:(NSString *)queueName
{
    /**
     This is really only meant for testing async code.  This could be dangerous
     in production.
     */
    
    CDOperationQueue *queue = [self queueForQueueName:queueName shouldCreate:NO];
    if (!queue) return;
    if (!queue.isExecuting) return;
    
    // Loop until queue finishes
    NSDate *loopUntil = [NSDate dateWithTimeIntervalSinceNow:0.5];
    while (queue.isExecuting == YES) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:loopUntil];
    }
}

#pragma mark - CDOperationQueueDelegate

- (void)queueDidFinish:(CDOperationQueue *)queue
{
    [self removeQueue:queue];
}

#pragma mark - Queue Progress

- (void)addProgressObserverToQueueNamed:(NSString *)queueName 
                     withProgressBlock:(CDOperationQueueProgressObserverProgressBlock)progressBlock 
                    andCompletionBlock:(CDOperationQueueProgressObserverCompletionBlock)completionBlock
{        
    CDOperationQueue *queue = [self queueForQueueName:queueName shouldCreate:YES];
    
    [queue addProgressObserverWithProgressBlock:progressBlock 
                            andCompletionBlock:completionBlock];
}

- (void)addQueueOperationObserver:(id)observer
                     toQueueNamed:(NSString *)queueName
{
    CDOperationQueue *queue = [self queueForQueueName:queueName shouldCreate:YES];
    queue.operationsObserver = observer;
}

- (void)removeQueuedOperationObserver:(id)observer
                       fromQueueNamed:(NSString *)queueName
{
    CDOperationQueue *queue = [self queueForQueueName:queueName shouldCreate:NO];
    queue.operationsObserver = nil;
}

#pragma mark - Accessors

- (void)setMaxConcurrentOperationCount:(NSInteger)count 
                         forQueueNamed:(NSString *)queueName
{
    if (!queueName) return;
    ConductorLogTrace(@"Setting max concurency count to %i for queue: %@", count, queueName);
    CDOperationQueue *queue = [self queueForQueueName:queueName shouldCreate:YES];
    [queue setMaxConcurrentOperationCount:count];
}

- (void)setMaxQueuedOperationCount:(NSUInteger)count
                     forQueueNamed:(NSString *)queueName
{
    if (!queueName) return;
    ConductorLogTrace(@"Setting max queued count to %i for queue: %@", count, queueName);
    CDOperationQueue *queue = [self queueForQueueName:queueName shouldCreate:YES];
    [queue setMaxQueuedOperationsCount:count];
}

#pragma mark - Private

- (NSString *)queueNameForOperation:(NSOperation *)operation
{
    if (!operation) return nil;
    NSString *className = NSStringFromClass([operation class]);
    return [NSString stringWithFormat:@"%@_operation_queue", className];
}

- (CDOperationQueue *)queueForOperation:(NSOperation *)operation
                           shouldCreate:(BOOL)create
{
    NSString *queueName = [self queueNameForOperation:operation];
    return [self queueForQueueName:queueName shouldCreate:create];
}

- (CDOperationQueue *)getQueueForOperation:(NSOperation *)operation
{
    NSString *queueName = [self queueNameForOperation:operation];
    return [self getQueueNamed:queueName];    
}

- (CDOperationQueue *)getQueueNamed:(NSString *)queueNamed
{
    return [self queueForQueueName:queueNamed shouldCreate:NO];
}

- (CDOperationQueue *)queueForQueueName:(NSString *)queueName 
                           shouldCreate:(BOOL)create
{
    if (!queueName) return nil;
    
    @synchronized (self.queues) {
        id queue = [self.queues objectForKey:queueName];
    
        if (!queue && create) {
            queue = [self createQueueWithName:queueName];
        }
    
        return (CDOperationQueue *)queue;
    }
}

- (CDOperationQueue *)createQueueWithName:(NSString *)queueName
{
    if (!queueName) return nil;
    
    ConductorLogTrace(@"Creating queue: %@", queueName);

    CDOperationQueue *queue = [CDOperationQueue queueWithName:queueName];
    queue.delegate = self;

    [self.queues setObject:queue forKey:queueName];
    
    return queue;
}

@end
