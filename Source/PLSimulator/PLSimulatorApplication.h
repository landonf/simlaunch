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


@interface PLSimulatorApplication : NSObject {
@private
    /** Application's display name (as shown on the device) */
    NSString *_displayName;

    /** Application path */
    NSString *_path;

    /** Canonical name of the SDK used to build this application. */
    NSString *_canonicalSDKName;

    /** Set of PLSimulatorDeviceFamily types supported by this application. */
    NSSet *_deviceFamilies;
}

- (id) initWithPath: (NSString *) path error: (NSError **) outError;

/** The application display name (as shown on the device) */
@property(readonly) NSString *displayName;

/** Application path */
@property(readonly) NSString *path;

/** Return the canonical name of the SDK used to build this application. */
@property(readonly) NSString *canonicalSDKName;

/**
 * Return the set of PLSimulatorDeviceFamily values supported by this application.
 */
@property(readonly) NSSet *deviceFamilies;

@end
