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

#import "PLSimulatorDeviceFamily.h"

#import "iPhoneSimulatorRemoteClient.h"

static PLSimulatorDeviceFamily *iPhoneSingleton = nil;
static PLSimulatorDeviceFamily *iPadSingleton = nil;

@interface PLSimulatorDeviceFamily (PrivateMethods)
- (id) initWithLocalizedName: (NSString *) localizedName deviceFamilyCode: (DTiPhoneSimulatorFamily) deviceFamilyCode;
@end

/**
 * Simulator Device Family
 *
 * @par Thread Safety
 * Immutable and thread-safe. May be used from any thread.
 */
@implementation PLSimulatorDeviceFamily

@synthesize localizedName = _localizedName;
@synthesize deviceFamilyCode = _deviceFamilyCode;

+ (void) initialize {
    /* Subclass guard */
    if ([self class] != [PLSimulatorDeviceFamily class])
        return;

    /* Create our singletons */
    iPhoneSingleton = [[PLSimulatorDeviceFamily alloc] initWithLocalizedName: NSLocalizedString(@"iPhone", @"iPhone Device Family")
                                                            deviceFamilyCode: DTiPhoneSimulatoriPhoneFamily];

    iPadSingleton = [[PLSimulatorDeviceFamily alloc] initWithLocalizedName: NSLocalizedString(@"iPad", @"iPad Device Family")
                                                          deviceFamilyCode: DTiPhoneSimulatoriPadFamily];
}


/**
 * Return the device family corresponding to the provided Apple Developer Tools device family code. If the code is unknown,
 * will return nil.
 *
 * @param deviceCode The device family code used by the Apple Developer tools for both the UIDeviceFamily bundle key and the
 * iPhoneSimulatorRemoteClient API.
 *
 * @return Returns the corresponding device family, or nil if the code is unknown.
 */
+ (PLSimulatorDeviceFamily *) deviceFamilyForDeviceCode: (NSInteger) deviceCode {
    /* Switch on the typed value so that GCC will inform us if we miss one. */
    switch ((DTiPhoneSimulatorFamily) deviceCode) {
        case DTiPhoneSimulatoriPhoneFamily:
            return [self iphoneFamily];
        case DTiPhoneSimulatoriPadFamily: 
            return [self ipadFamily];
    }

    /* Unknown */
    return nil;
}

/**
 * Return the iPhone (DTiPhoneSimulatorFamilyiPhone) device family.
 */
+ (PLSimulatorDeviceFamily *) iphoneFamily {
    return iPhoneSingleton;
}

/**
 * Return the iPad (DTiPhoneSimulatorFamilyiPad) device family.
 */
+ (PLSimulatorDeviceFamily *) ipadFamily {
    return iPadSingleton;
}

// from NSObject protocol
- (BOOL) isEqual: (id) anObject {
    if (anObject == self)
        return YES;

    if (anObject == nil)
        return NO;
    
    if (![anObject isKindOfClass: [self class]])
        return NO;

    PLSimulatorDeviceFamily *other = anObject;
    return (other.deviceFamilyCode == self.deviceFamilyCode);
}

// from NSObject protocol
- (NSUInteger) hash {
    return self.deviceFamilyCode;
}

// from NSObject protocol
- (NSString *) description {
    return [NSString stringWithFormat: @"%@ - %@ (UIDeviceFamily=%ld)", [self class], self.localizedName, (long) self.deviceFamilyCode];
}

@end

/**
 * @internal
 */
@implementation PLSimulatorDeviceFamily (PrivateMethods)

/**
 * Initialize a new device family instance.
 *
 * @param localizedName The localized name for this device family.
 * @param deviceFamilyCode The device family code used by the Apple Developer tools.
 */
- (id) initWithLocalizedName: (NSString *) localizedName deviceFamilyCode: (DTiPhoneSimulatorFamily) deviceFamilyCode {
    if ((self = [super init]) == nil)
        return nil;

    _localizedName = localizedName;
    _deviceFamilyCode = deviceFamilyCode;

    return self;
}

@end
