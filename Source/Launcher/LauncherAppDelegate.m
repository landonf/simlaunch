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

#import "LauncherAppDelegate.h"
#import "PLSimulator.h"

/* Resource subdirectory for the embedded application */
#define APP_DIR @"EmbeddedApp"

/* Full application-relative path to the embeddedapp dir */
#define FULL_APP_DIR @"Contents/Resources/" APP_DIR

@implementation LauncherAppDelegate

- (void) applicationDidFinishLaunching: (NSNotification *) aNotification {
    NSError *error;

    /* Display a fatal configuration error modaly */
    void (^ConfigError)(NSString *) = ^(NSString *text) {
        NSAlert *alert = [NSAlert alertWithMessageText: @"The launcher has not been correctly configured." 
                                         defaultButton: @"Quit"
                                       alternateButton: nil 
                                           otherButton: nil
                             informativeTextWithFormat: text];
        [alert runModal];
        [[NSApplication sharedApplication] terminate: self];
    };

    /* Find the embedded application dir */
    NSString *appContainer = [[NSBundle mainBundle] pathForResource: APP_DIR ofType: nil];
    if (appContainer == nil) {
        ConfigError(@"Missing the " FULL_APP_DIR " directory.");
        return;
    }

    /* Scan for applications */
    NSArray *appPaths = [[NSFileManager defaultManager] contentsOfDirectoryAtPath: appContainer error: &error];
    if (appPaths == nil) {
        ConfigError(FULL_APP_DIR " could not be read.");
        return;
    } else if ([appPaths count] == 0) {
        ConfigError(@"No applications found in " FULL_APP_DIR ".");
        return;
    } else if ([appPaths count] > 1) {
        ConfigError(@"More than one application found in " FULL_APP_DIR ".");
        return;
    }

    /* Load the app meta-data */
    NSString *appPath = [appContainer stringByAppendingPathComponent: [appPaths objectAtIndex: 0]];
    PLSimulatorApplication *app = [[PLSimulatorApplication alloc] initWithPath: appPath error: &error];
    if (app == nil) {
        [[NSAlert alertWithError: error] runModal];
        [[NSApplication sharedApplication] terminate: self];
        return;
    }

    /* Find the matching platform SDKs */
    NSSet *families = [NSSet setWithObjects: PLSimulatorDeviceFamilyiPad, nil];
    _discovery = [[PLSimulatorDiscovery alloc] initWithMinimumVersion: @"3.0"
                                                       deviceFamilies: families];
    _discovery.delegate = self;
    [_discovery startQuery];
    
}

// from PLSimulatorDiscoveryDelegate protocol
- (void) simulatorDiscovery: (PLSimulatorDiscovery *) discovery didFindMatchingSimulatorPlatforms: (NSArray *) platforms {
    for (PLSimulatorPlatform *platform in platforms) {
        NSLog(@"Found matching platform SDK at %@", platform.path);
    }
}

@end
