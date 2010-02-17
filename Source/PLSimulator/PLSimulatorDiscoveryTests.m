/*
 * Author: Landon Fuller <landonf@plausiblelabs.com>
 *
 * Copyright (c) 2010 Plausible Labs Cooperative, Inc.
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

#import "PLSimulator.h"
#import "PLSimulatorDiscovery.h"

@interface PLSimulatorDiscoveryTests : PLTestCase <PLSimulatorDiscoveryDelegate> {
@private
    NSArray *_foundSDKs;
}
@end

@implementation PLSimulatorDiscoveryTests

- (void) testQuery {
    NSSet *families = [NSSet setWithObject: [PLSimulatorDeviceFamily iphoneFamily]];
    PLSimulatorDiscovery *query = [[PLSimulatorDiscovery alloc] initWithMinimumVersion: @"3.0"
                                                                      canonicalSDKName: nil
                                                                        deviceFamilies: families];
    query.delegate = self;
    [query startQuery];

    /* Spin until the SDK results are available */
    [self spinRunloopWithTimeout: 60.0 predicate: ^{ return (BOOL) (_foundSDKs != nil); }];
    STAssertNotNil(_foundSDKs, @"Timed out waiting for query results");
}

// from PLSimulatorDiscoveryDelegate protocol
- (void) simulatorDiscovery: (PLSimulatorDiscovery *) discovery didFindMatchingSimulatorPlatforms: (NSArray *) sdks {
    _foundSDKs = sdks;
}

@end
