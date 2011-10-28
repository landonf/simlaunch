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

#import "PLSimulatorDeviceFamily.h"
#import "iPhoneSimulatorRemoteClient.h"

@interface PLSimulatorDeviceFamilyTests : PLTestCase {
@private
}
@end

@implementation PLSimulatorDeviceFamilyTests

- (void) testDeviceFamilyForCode {
    STAssertEqualObjects([PLSimulatorDeviceFamily iphoneFamily],
                         [PLSimulatorDeviceFamily deviceFamilyForDeviceCode: DTiPhoneSimulatoriPhoneFamily],
                         @"Should be equal");

    STAssertEqualObjects([PLSimulatorDeviceFamily ipadFamily],
                         [PLSimulatorDeviceFamily deviceFamilyForDeviceCode: DTiPhoneSimulatoriPadFamily],
                         @"Should be equal");
}

// Sanity test isEqual/hash
- (void) testEquality {
    STAssertEqualObjects([PLSimulatorDeviceFamily iphoneFamily], [PLSimulatorDeviceFamily iphoneFamily], @"Should be equal");
    STAssertEquals([[PLSimulatorDeviceFamily iphoneFamily] hash], [[PLSimulatorDeviceFamily iphoneFamily] hash], @"Should be equal");

    STAssertEqualObjects([PLSimulatorDeviceFamily ipadFamily], [PLSimulatorDeviceFamily ipadFamily], @"Should be equal");
    STAssertEquals([[PLSimulatorDeviceFamily ipadFamily] hash], [[PLSimulatorDeviceFamily ipadFamily] hash], @"Should be equal");

    STAssertFalse([[PLSimulatorDeviceFamily iphoneFamily] isEqual: [PLSimulatorDeviceFamily ipadFamily]], @"Should not be equal");
}

@end
