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

#import <Cocoa/Cocoa.h>

#import "PLSimulatorSDK.h"

@interface PLSimulatorPlatform : NSObject {
@private
    /** The path to the enclosing Xcode.app bundle, or nil if this platform was not found within an application bundle. */
    NSString *_xcodePath;

    /** Platform SDK path. */
    NSString *_path;

    /** The list of PLSimulatorSDKs included with the platform SDK. */
    NSArray *_sdks;

    /** The loaded iPhoneSimulatorRemoteClient bundle, or nil if not loaded. */
    NSBundle *_remoteClient;
}

- (id) initWithPath: (NSString *) path xcodePath: (NSString *) xcodePath error: (NSError **) outError;

- (BOOL) loadPrivateFrameworks: (NSError **) outError;

/** The path to the enclosing Xcode.app bundle, or nil if this platform was not found within an application bundle. */
@property(readonly) NSString *xcodePath;

/** The full path to the platform SDK. */
@property(readonly) NSString *path;

/** The list of PLSimulatorSDKs included with the platform SDK. */
@property(readonly) NSArray *sdks;

@end
