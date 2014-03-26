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

#import "PLSimulatorSDK.h"

#import "PLSimulator.h"
#import "PLSimulatorUtils.h"

/* Relative path to the setting plist */
#define SDK_SETTINGS_PLIST @"SDKSettings.plist"

/*
 * SDKSettings keys.
 */

/* SDK Version */
#define VersionKey @"Version"

/* Device Families (pre-4.0 configuration) */
#define DevicesKey @"UIDeviceFamily"

/* Default Properties (4.0+ configuration) */
#define DefaultPropertiesKey @"DefaultProperties"

/* Supported Device Families (4.0+ configuration) */
#define SupportedDeviceFamiliesKey @"SUPPORTED_DEVICE_FAMILIES"

/* Canonical name */
#define CanonicalNameKey @"CanonicalName"

/* Device family constants used by Apple */
enum {
    iPhoneFamily = 1,
    iPadFamily = 2
};

/**
 * Meta-data for a specific Simulator SDK version.
 *
 * @par Thread Safety
 * Immutable and thread-safe. May be used from any thread.
 */
@implementation PLSimulatorSDK

@synthesize version = _version;
@synthesize canonicalName = _canonicalName;
@synthesize deviceFamilies = _deviceFamilies;

/**
 * Initialize with the provided SDK path.
 *
 * @param path Simulator SDK path (eg, /Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator3.1.sdk)
 * @param error If an error occurs, upon return contains an NSError object that describes the problem.
 *
 * @return Returns an initialized PLSimulatorSDK instance, or nil if the SDK meta-data can not
 * be parsed or the path appears to not be a valid SDK.
 */
- (id) initWithPath: (NSString *) path error: (NSError **) outError {
    if ((self = [super init]) == nil) {
        // Shouldn't happen
        plsimulator_populate_nserror(outError, PLSimulatorErrorUnknown, @"Unexpected error", nil);
        return nil;
    }

    /* Save the SDK path */
    _path = path;
    
    /* Verify that the path exists */
    NSFileManager *fm = [NSFileManager new];
    {
        BOOL isDir;
        if (![fm fileExistsAtPath: _path isDirectory: &isDir] || isDir == NO) {
            NSString *desc = NSLocalizedString(@"The provided SDK path does exist or is not a directory.",
                                               @"Missing/non-directory SDK path");
            plsimulator_populate_nserror(outError, PLSimulatorErrorInvalidSDK, desc, nil);
            return nil;
        }
    }

    /* Load the SDK settings plist */
    NSDictionary *plist;
    {
        NSString *plistPath = [_path stringByAppendingPathComponent: SDK_SETTINGS_PLIST];
        NSData *plistData = [NSData dataWithContentsOfMappedFile: plistPath];
        NSString *errorDesc;

        /* Try to read the plist data */
        id plistInstance = [NSPropertyListSerialization propertyListFromData: plistData
                                                            mutabilityOption: NSPropertyListImmutable
                                                                      format: NULL
                                                            errorDescription: &errorDesc];

        /* Invalid format */
        if (plistInstance == nil) {
            NSString *desc = NSLocalizedString(@"The provided SDK does not contain a valid SDKSettings property list.",
                                               @"Missing/non-directory SDK path");
            NSLog(@"Error loading SDK path '%@': %@", _path, errorDesc);

            plsimulator_populate_nserror(outError, PLSimulatorErrorInvalidSDK, desc, nil);
            return nil;
        }

        /* We expect a dictionary */
        if (![plistInstance isKindOfClass: [NSDictionary class]]) {
            NSString *desc = NSLocalizedString(@"The provided SDK SDKSettings property list uses an unsupported data schema.",
                                               @"Missing/non-directory SDK path");        
            plsimulator_populate_nserror(outError, PLSimulatorErrorInvalidSDK, desc, nil);
            return nil;
        }
        
        plist = plistInstance;
    }

    /* Block to fetch a key from the plist */
    BOOL (^Get) (NSString *, id *, Class cls, BOOL);
    Get = ^(NSString *key, id *value, Class cls, BOOL required) {
        *value = [plist objectForKey: key];

        if (*value != nil && (cls == nil || [*value isKindOfClass: cls]))
            return YES;
    
        /* Populate the error */
        if (required) {
            NSString *desc = NSLocalizedString(@"The provided SDK's SDKSettings property list schema is missing required %@ key.",
                                               @"Missing/non-directory SDK path");
            desc = [NSString stringWithFormat: desc, key];
            plsimulator_populate_nserror(outError, PLSimulatorErrorInvalidSDK, desc, nil);
        }

        return NO;
    };

    NSString *version = nil;
    /* Fetch required values */
    if (!Get(VersionKey, &version, [NSString class], YES))
        return nil;
    _version = version;

    NSString *canonicalName = nil;
    if (!Get(CanonicalNameKey, &canonicalName, [NSString class], YES))
        return nil;
    _canonicalName = canonicalName;

    /* Get the list of supported devices */
    {
        NSArray *devices;
        NSDictionary *defaultProperties;
        
        if (Get(DevicesKey, &devices, [NSArray class], NO)) {
            _deviceFamilies = [PLSimulatorUtils deviceFamiliesForDeviceCodes: devices];
        } else if (Get(DefaultPropertiesKey, &defaultProperties, [NSDictionary class], NO)) {
            /* Use the meta-data format introduced in iOS 4.0 */
            devices = [defaultProperties objectForKey: SupportedDeviceFamiliesKey];
            if (devices != nil && [devices isKindOfClass: [NSArray class]]) {
                _deviceFamilies = [PLSimulatorUtils deviceFamiliesForDeviceCodes: devices];
            }
        }

        /* If no valid settings, assume that this is a <3.2 SDK and it supports the iPhone family */
        if (_deviceFamilies == nil || [_deviceFamilies count] == 0) {
            _deviceFamilies = [NSSet setWithObject: [PLSimulatorDeviceFamily iphoneFamily]];
        }
    }

    return self;
}


@end
