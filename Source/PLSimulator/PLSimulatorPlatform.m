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

#import "PLSimulatorPlatform.h"

#import "PLSimulator.h"
#import "PLUniversalBinary.h"

/**
 * Global variable used to track if the iPhoneSimulatorRemoteClient has already been loaded by any instance of this class.
 * The framework must not be loaded multiple times.
 */
static BOOL isBundleLoaded = NO;

/* Relative path to the set of platform sub-SDKs */
#define PLATFORM_SUBSDK_PATH @"Developer/SDKs/"

/* Relative path to the iPhoneSimulatorRemoteClient framework */
#define REMOTE_CLIENT_FRAMEWORK @"Developer/Library/PrivateFrameworks/DVTiPhoneSimulatorRemoteClient.framework"

/**
 * Manages a Simulator Platform SDK, allows querying of the bundled PLSimulatorSDK meta-data.
 *
 * @par Thread Safety
 * Immutable and thread-safe. May be used from any thread.
 *
 * As an exception to the above, the bundle loading API is not thread-safe and should only be
 * accessed from the main thread.
 */
@implementation PLSimulatorPlatform

@synthesize path = _path;
@synthesize xcodePath = _xcodePath;
@synthesize sdks = _sdks;

/**
 * Initialize with the provided simulator platform SDK path.
 *
 * @param path Simulator platform SDK path (eg, /Developer/Platforms/iPhoneSimulator.platform)
 * @param xcodePath The path to the enclosing Xcode.app bundle, or nil if this platform was not found within an application bundle.
 * @param error If an error occurs, upon return contains an NSError object that describes the problem.
 *
 * @return Returns an initialized PLSimulatorPlatform instance, or nil if the simulator meta-data can not
 * be parsed or the path appears to not be a valid platform SDK.
 */
- (id) initWithPath: (NSString *) path xcodePath: (NSString *) xcodePath error: (NSError **) outError {
    if ((self = [super init]) == nil) {
        // Shouldn't happen
        plsimulator_populate_nserror(outError, PLSimulatorErrorUnknown, @"Unexpected error", nil);
        return nil;
    }

    _path = path;
    _xcodePath = xcodePath;

    /* Verify that the path exists */
    NSFileManager *fm = [NSFileManager new];
    BOOL isDir;
    if (![fm fileExistsAtPath: _path isDirectory: &isDir] || isDir == NO) {
        NSString *desc = NSLocalizedString(@"The provided Platform SDK path does exist or is not a directory.",
                                           @"Missing/non-directory SDK path");
        plsimulator_populate_nserror(outError, PLSimulatorErrorInvalidSDK, desc, nil);
        return nil;
    }


    /* Load all SDKs */
    NSError *error;
    NSString *sdkDir = [_path stringByAppendingPathComponent: PLATFORM_SUBSDK_PATH];
    NSArray *sdkPaths = [fm contentsOfDirectoryAtPath: sdkDir error: &error];
    
    if (sdkPaths == nil) {
        NSString *desc = NSLocalizedString(@"The provided Platform SDK does not contain any SDKs",
                                           @"Missing/non-directory SDK sub-path");
        plsimulator_populate_nserror(outError, PLSimulatorErrorInvalidSDK, desc, error);
        return nil;
    }

    /* Iterate and load the SDK subdirectories */
    NSMutableArray *sdks = [NSMutableArray arrayWithCapacity: [sdkPaths count]];
    _sdks = sdks;

    for (NSString *sdkPath in sdkPaths) {
        NSString *absolutePath = [sdkDir stringByAppendingPathComponent: sdkPath];

        PLSimulatorSDK *sdk = [[PLSimulatorSDK alloc] initWithPath: absolutePath error: &error];

        /* Simply skip unparsable SDKs */
        if (sdk == nil) {
            NSLog(@"Skipping bad SDK %@: %@", absolutePath, error);
            continue;
        }

        [sdks addObject: sdk];
    }

    return self;
}


/**
 * Attempt to load Apple's iPhoneSimulatorRemoteClient framework from this platform SDK.
 *
 * @param error If an error occurs, upon return contains an NSError object that describes the problem.
 * @return Returns YES on success, or NO on failure.
 *
 * @warning Only one instance of the iPhoneSimulatorRemoteClient framework may be loaded across the entire lifetime
 * of the process. Attempting to load the framework again will trigger a PLSimulatorException. 
 */
- (BOOL) loadClientFramework: (NSError **) outError {
    /* Verify that it is not loaded */
    if (isBundleLoaded)
        [NSException raise: PLSimulatorException format: @"Attempted to load the iPhoneSimulatorRemoteClient twice"];
    
    /* Attempt to load absolute LC_RPATH values from the Xcode binary corresponding to this platform instance, if
     * available. */
    NSArray *rpaths = nil;
    if (_xcodePath != nil) {
        NSBundle *xcodeBundle = [NSBundle bundleWithPath: _xcodePath];
        if (xcodeBundle != nil) {
            NSError *error;
            PLUniversalBinary *ub = [PLUniversalBinary binaryWithPath: [xcodeBundle executablePath] error: &error];

            if (ub != nil) {
                PLExecutableBinary *xcodeBinary = [ub executableMatchingCurrentArchitecture];
                if (xcodeBinary != nil) {
                    rpaths = [xcodeBinary absoluteRpaths];
                }
            } else {
                NSLog(@"Failed to load Xcode binary: %@", error);
            }
            
            /* In addition to automatic @rpath support, we need to add 'OtherFrameworks', which Xcode does not include
             * by default */
            rpaths = [rpaths arrayByAddingObject: [_xcodePath stringByAppendingPathComponent: @"Contents/OtherFrameworks"]];
        }
    }

    /* Determine the path */
    NSString *path = [_path stringByAppendingPathComponent: REMOTE_CLIENT_FRAMEWORK];
    _remoteClient = [NSBundle bundleWithPath: path];

    /* Load the bundle */
    NSString *libraryPath = [_remoteClient executablePath];
    PLUniversalBinary *ub = [PLUniversalBinary binaryWithPath: libraryPath error: outError];
    if (ub == nil)
        return false;

    return [ub loadLibraryWithRPaths: rpaths error: outError];
}

@end
