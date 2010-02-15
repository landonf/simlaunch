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

/**
 * Provides access to a Simulator application's meta-data.
 *
 * @par Thread Safety
 * Immutable and thread-safe. May be used from any thread.
 */
@implementation PLSimulatorApplication

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
            NSString *desc = NSLocalizedString(@"The provided SDK path does exist or is not a directory.",
                                               @"Missing/non-directory SDK path");
            plsimulator_populate_nserror(outError, PLSimulatorErrorInvalidSDK, desc, nil);
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
    
    return self;
}

@end
