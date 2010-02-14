/*
 * Author: Landon Fuller <landonf@plausiblelabs.com>
 *
 * Copyright (c) 2008-2010 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

#import "PLTestCase.h"

/**
 * Abstract application test case.
 */
@implementation PLTestCase

/**
 * Return the full path to the given test resource. Test resources are located in
 * TestBundle/Resources/Tests/TestName/ResourceName
 *
 * @param resource Relative resource path.
 */
- (NSString *) pathForResource: (NSString *) resource {
    NSString *className = NSStringFromClass([self class]);
    NSString *resources = [[NSBundle bundleForClass: [self class]] resourcePath];
    NSString *testResources = [resources stringByAppendingPathComponent: @"Tests"];
    NSString *root = [testResources stringByAppendingPathComponent: className];

    return [root stringByAppendingPathComponent: resource];
}

/**
 * Spin the runloop until timeout is reached or the provided predicate returns YES.
 *
 * @param timeout Maximum amount of time to wait for the predicate returns YES.
 * @param predicate Predicate to test.
 */
- (void) spinRunloopWithTimeout: (NSTimeInterval) timeout predicate: (BOOL (^)()) predicate {
    /* Determine the date at which timeout will occur */
    NSDate *future = [NSDate dateWithTimeIntervalSinceNow: timeout];
    
    /* Run until the predicate is YES or the timout is reached */
    while (predicate() == NO && [[NSDate date] earlierDate: future] != future)
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, YES);
}

@end
