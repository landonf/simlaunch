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

#import "PLSimulatorUtils.h"
#import "iPhoneSimulatorRemoteClient.h"

/**
 * @internal
 * Private Utility Functions.
 */
@implementation PLSimulatorUtils

/**
 * Map a set of Apple UIDeviceFamily codes to PLSimulatorDeviceFamily instances.
 *
 * @param deviceCodes An array of NSString or NSNumber UIDeviceFamily values.
 */
+ (NSSet *) deviceFamiliesForDeviceCodes: (NSArray *) deviceCodes {
    NSMutableSet *deviceFamilies = [NSMutableSet setWithCapacity: [deviceCodes count]];

    for (id code in deviceCodes) {
        /* Try to handle string/number confusion. The current plist uses strings, but it's
         * clearly a numeric constant. We assume that if it responds to intValue, it will
         * work as either a NSNumber or NSString */
        if (![code respondsToSelector:@selector(intValue)]) {
            NSLog(@"Unsupported %@ value type while parsing UIDeviceFamily settings: %@", code, deviceCodes);
            continue;
        }
        
        /* Map the Apple family number to our family constants */
        PLSimulatorDeviceFamily *family = [PLSimulatorDeviceFamily deviceFamilyForDeviceCode: [code intValue]];
        if (family == nil)
            NSLog(@"Unsupported %@:%@ value type while parsing UIDeviceFamily value.", code, [code class]);
        else
            [deviceFamilies addObject: family];
    }
    
    /* Save the populated set */
    return deviceFamilies;
}

@end
