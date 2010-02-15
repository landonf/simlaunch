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

/* Device family constants used by Apple */
enum {
    iPhoneFamily = 1,
    iPadFamily = 2
};

/**
 * @internal
 * Private Utility Functions.
 */
@implementation PLSimulatorUtils

/**
 * Map an Apple UIDeviceFamily code to PLSimulatorDeviceFamily constant.
 *
 * @param deviceCode An NSString or NSNumber UIDeviceFamily value.
 * @return Returns a device family constant, or nil if the device code is unknown.
 */
+ (NSString *) deviceFamilyForDeviceCode: (id) deviceCode {
    /* Map the Apple family number to our family constants */
    switch ([(NSString *)deviceCode intValue]) {
        case iPhoneFamily:
            return PLSimulatorDeviceFamilyiPhone;
        case iPadFamily:
            return PLSimulatorDeviceFamilyiPad;
        default:
            NSLog(@"Unsupported %@:%@ value type while parsing UIDeviceFamily value.", deviceCode, [deviceCode class]);
            return nil;
    }
}

/**
 * Map a set of Apple UIDeviceFamily codes to PLSimulatorDeviceFamily constants.
 *
 * @param deviceCodes An array of NSString or NSNumber UIDeviceFamily values.
 */
+ (NSSet *) deviceFamiliesForDeviceCodes: (NSArray *) deviceCodes {
    NSMutableSet *deviceFamilies = [NSMutableSet setWithCapacity: [deviceCodes count]];

    for (NSString *str in deviceCodes) {
        /* Try to handle string/number confusion. The current plist uses strings, but it's
         * clearly a numeric constant. We assume that if it responds to intValue, it will
         * work as either a NSNumber or NSString */
        if (![str isKindOfClass: [NSString class]] && [str isKindOfClass: [NSNumber class]]) {
            NSLog(@"Unsupported %@ value type while parsing UIDeviceFamily settings: %@", str, deviceCodes);
            continue;
        }
        
        /* Map the Apple family number to our family constants */
        NSString *constant = [self deviceFamilyForDeviceCode: str];
        if (constant != nil)
            [deviceFamilies addObject: constant];
    }
    
    /* Save the populated set */
    return deviceFamilies;
}

@end
