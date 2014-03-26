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

#import "PLSimulator.h"

#import "PLSimulatorApplication.h"
#import "PLSimulatorUtils.h"

/* Device Families */
#define DevicesKey @"UIDeviceFamily"

/* Canonical SDK Name */
#define SDKNameKey @"DTSDKName"

/* Display name key */
#define CFBundleDisplayName @"CFBundleDisplayName"

/**
 * Provides access to a Simulator application's meta-data.
 *
 * @par Thread Safety
 * Immutable and thread-safe. May be used from any thread.
 */
@implementation PLSimulatorApplication

@synthesize path = _path;
@synthesize displayName = _displayName;
@synthesize canonicalSDKName = _canonicalSDKName;
@synthesize deviceFamilies = _deviceFamilies;

/**
 * Initialize with the provided application path.
 *
 * @param path Simulator application path (eg, HelloWorld.app)
 * @param error If an error occurs, upon return contains an NSError object that describes the problem.
 *
 * @return Returns an initialized PLSimulatorApplication instance, or nil if the application meta-data can not
 * be parsed or the path appears to not be a valid application.
 */
- (id) initWithPath: (NSString *) path error: (NSError **) outError {
    if ((self = [super init]) == nil) {
        // Shouldn't happen
        plsimulator_populate_nserror(outError, PLSimulatorErrorUnknown, @"Unexpected error", nil);
        return nil;
    }
    
    /* Save the application path */
    _path = path;
    
    /* Verify that the path exists */
    NSFileManager *fm = [NSFileManager new];
    {
        BOOL isDir;
        if (![fm fileExistsAtPath: _path isDirectory: &isDir] || isDir == NO) {
            NSString *desc = NSLocalizedString(@"The provided application path does exist or is not a directory.",
                                               @"Missing/non-directory application path");
            plsimulator_populate_nserror(outError, PLSimulatorErrorInvalidApplication, desc, nil);
            return nil;
        }
    }
    
    /* Load the application Info.plist */
    NSDictionary *plist;
    {
        NSString *plistPath = [_path stringByAppendingPathComponent: @"Info.plist"];
        NSData *plistData = [NSData dataWithContentsOfMappedFile: plistPath];
        NSString *errorDesc;
        
        /* Try to read the plist data */
        id plistInstance = [NSPropertyListSerialization propertyListFromData: plistData
                                                            mutabilityOption: NSPropertyListImmutable
                                                                      format: NULL
                                                            errorDescription: &errorDesc];
        
        /* Invalid format */
        if (plistInstance == nil) {
            NSString *desc = NSLocalizedString(@"The application does not contain a valid property list.",
                                               @"Invalid application plist");
            NSLog(@"Error loading SDK path '%@': %@", _path, errorDesc);
            
            plsimulator_populate_nserror(outError, PLSimulatorErrorInvalidApplication, desc, nil);
            return nil;
        }
        
        /* We expect a dictionary */
        if (![plistInstance isKindOfClass: [NSDictionary class]]) {
            NSString *desc = NSLocalizedString(@"The application's property list uses unsupported data schema.",
                                               @"Unsupported application plist");        
            plsimulator_populate_nserror(outError, PLSimulatorErrorInvalidApplication, desc, nil);
            return nil;
        }
        
        plist = plistInstance;
    }
    
    
    /* Block to fetch a retained key from the plist */
    BOOL (^Get) (NSString *, id *, Class cls, BOOL) = ^(NSString *key, id *value, Class cls, BOOL required) {
        *value = [plist objectForKey: key];


        if (*value != nil && (cls == nil || [*value isKindOfClass: cls]))
            return YES;
        
        /* Populate the error */
        if (required) {
            NSString *desc = NSLocalizedString(@"The application's Info.plist is missing required %@ key.",
                                               @"Unsupported application plist");
            desc = [NSString stringWithFormat: desc, key];
            plsimulator_populate_nserror(outError, PLSimulatorErrorInvalidApplication, desc, nil);
        }
        
        return NO;
    };


    NSString *displayName = nil;
    /* Try to fetch the application's display name. */
    if (!Get((id)CFBundleDisplayName, &displayName, [NSString class], NO)) {
        _displayName = [[path lastPathComponent] stringByDeletingPathExtension];
        if (_displayName == nil) {
            NSString *desc = NSLocalizedString(@"The application's Info.plist is missing CFBundleDisplayName key and a "
                                               @"valid name could not be determined from the application path.",
                                               @"Unsupported application plist");
            plsimulator_populate_nserror(outError, PLSimulatorErrorInvalidApplication, desc, nil);
        }
    }
    _displayName = displayName;

    NSString *canonicalSDKName = nil;
    /* Get the canonical name of the SDK that this app was built with. */
    if (!Get(SDKNameKey, &canonicalSDKName, [NSString class], YES))
        return nil;

    _canonicalSDKName = canonicalSDKName;

    /* Get the list of supported devices */
    {
        NSArray *devices;
        if (Get(DevicesKey, &devices, [NSArray class], NO)) {
            _deviceFamilies = [PLSimulatorUtils deviceFamiliesForDeviceCodes: devices];
        }
        
        /* If no valid settings, assume that this is a <3.2 application and it supports the iPhone family */
        if (_deviceFamilies == nil || [_deviceFamilies count] == 0)
            _deviceFamilies = [NSSet setWithObject: [PLSimulatorDeviceFamily iphoneFamily]];
    }

    return self;
}


@end
