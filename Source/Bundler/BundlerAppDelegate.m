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

#import "BundlerAppDelegate.h"
#import "PLSimulator.h"



@interface BundlerAppDelegate (PrivateMethods)

- (void) addActiveTask;
- (void) removeActiveTask;

- (void) displayOpenPanel;

- (void) openApplicationWithPath: (NSString *) path;
- (void) executeBundlerWithSimulatorApp: (PLSimulatorApplication *) app deviceFamily: (PLSimulatorDeviceFamily *) family;

@end

@implementation BundlerAppDelegate

- (void) awakeFromNib {
    _appConfigControllers = [NSMutableSet set];
    _tool = [BundlerTool new];
}

// from NSApplicationDelegate protocol
- (void) applicationDidFinishLaunching: (NSNotification *) aNotification {
    /* Since we're a droplet, if no files were received we just display the open panel */
    if (!_receivedDroppedFiles)
        [self displayOpenPanel];
}

// from NSApplicationDelegate protocol
- (BOOL) application: (NSApplication *) theApplication openFile: (NSString *) filename {
    /* Note that we received a file */
    _receivedDroppedFiles = YES;

    /* Open the file */
    [self openApplicationWithPath: filename];

    return YES;
}

// from BundlerConfigWindowControllerDelegate protocol
- (void) bundlerConfigDidCancel: (BundlerConfigWindowController *) bundlerConfig {
    /* Hide the window */
    [[bundlerConfig window] close];

    /* Remove from the active list, and decrement the active task count */
    [_appConfigControllers removeObject: bundlerConfig];
    [self removeActiveTask];
}

// from BundlerConfigWindowControllerDelegate protocol
- (void) bundlerConfig: (BundlerConfigWindowController *) bundlerConfig didSelectDeviceFamily: (PLSimulatorDeviceFamily *) family {
    /* Start the bundler tool */
    [self executeBundlerWithSimulatorApp: bundlerConfig.application deviceFamily: family];

    /* Hide the window */
    [[bundlerConfig window] close];
    
    /* Remove bundler from the active list, and decrement the active task count */
    [_appConfigControllers removeObject: bundlerConfig];
    [self removeActiveTask];
}


// Display a new file open panel
- (IBAction) openFile: (id) sender {
    [self displayOpenPanel];
}

@end

/**
 * @internal
 */
@implementation BundlerAppDelegate (PrivateMethods)

/**
 * Display a generic error alert and request program termination.
 * 
 * @param message Alert message.
 * @param info Informative text.
 */
- (void) displayErrorWithMessage: (NSString *) message info: (NSString *) info {
    NSAlert *alert = [NSAlert new];
    [alert setMessageText: message];
    [alert setInformativeText: info];
    [alert runModal];
    
    [[NSApplication sharedApplication] terminate: self];
}

/**
 * Display a launch error alert and request program termination.
 * 
 * @param info Informative text.
 */
- (void) displayBundlingError: (NSString *) info {
    NSAlert *alert = [NSAlert new];
    [alert setMessageText: NSLocalizedString(@"Could not bundle the application for distribution.", @"No files alert message text")];
    [alert setInformativeText: info];
    [alert runModal];
    
    [[NSApplication sharedApplication] terminate: self];
}

/**
 * Display the open panel and allow the user to select application(s) to convert.
 */
- (void) displayOpenPanel {
    /* Configure our panel */
    NSOpenPanel *panel = [NSOpenPanel openPanel];    
    [panel setAllowsMultipleSelection: YES];
    
    /* Run */
    if ([panel runModalForTypes: [NSArray arrayWithObject: @"app"]] != NSOKButton) {
        [[NSApplication sharedApplication] terminate: self];
        return;
    }
    
    /* Open selected applications */
    for (NSURL *url in [panel URLs])
        [self openApplicationWithPath: [url path]]; 
}

/**
 * Open and attempt to bundle the provided application.
 *
 * @param path Path to the application.
 */
- (void) openApplicationWithPath: (NSString *) path {
    NSError *error;
    
    /* Load the application info */
    PLSimulatorApplication *app = [[PLSimulatorApplication alloc] initWithPath: path error: &error];
    if (app == nil) {
        NSLog(@"Could not load simulator app info: %@", error);
        
        /* Inform the user */
        NSString *textFmt = NSLocalizedString(@"%@ does not appear to be a valid iPhone application.", @"Alert error info");
        [self displayErrorWithMessage: NSLocalizedString(@"Could not read application property list.", @"Alert error message")
                                 info: [NSString stringWithFormat: textFmt, [path lastPathComponent]]];
        return;
    }
    
    /* If the app supports multiple device families, request the preferred family from the user */
    if ([app.deviceFamilies count] > 1) {
        /* Display the config UI */
        BundlerConfigWindowController *controller = [[BundlerConfigWindowController alloc] initWithSimulatorApp: (PLSimulatorApplication *) app];
        [controller setDelegate: self];
        [controller showWindow: self];
        [[controller window] makeKeyWindow];
        
        /* Save the controller reference */
        [_appConfigControllers addObject: controller];
        
        /* Note that a task is active */
        [self addActiveTask];
    } else {
        /* Otherwise, package the application immediately */
        [self executeBundlerWithSimulatorApp: app deviceFamily: [app.deviceFamilies anyObject]];
    }    
}

/**
 * Increment count of active tasks.
 */
- (void) addActiveTask {
    _activeTasks++;
}

/**
 * Decrement count of active tasks. If the active task value hits 0 and we were opened as a droplet,
 * the application will terminate.
 */
- (void) removeActiveTask {
    _activeTasks--;
    if (_activeTasks == 0 && _receivedDroppedFiles)
        [[NSApplication sharedApplication] terminate: self];
}


/**
 * Execute the bundler tool.
 *
 * @param app Application to be bundled.
 * @param family Device family to use when launching the app.
 */
- (void) executeBundlerWithSimulatorApp: (PLSimulatorApplication *) app deviceFamily: (PLSimulatorDeviceFamily *) family {
    /* Mark active */
    [self addActiveTask];

    /* Execute */
    [_tool executeWithSimulatorApp: app deviceFamily: family block: ^(BOOL success) {
        /* Unusual, but could happen */
        if (!success)
            [self displayBundlingError: @"Failed to create the application bundle. Consult the console log for more details."];

        /* Set task complete */
        [self removeActiveTask];
    }];
}

@end
