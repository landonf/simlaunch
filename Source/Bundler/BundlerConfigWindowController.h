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
#import "PLSimulator.h"

@class BundlerConfigWindowController;

/**
 * BundlerConfigWindowController delegate.
 */
@protocol BundlerConfigWindowControllerDelegate

/**
 * Called when the user cancel's the bundling configuration.
 *
 * @param config The sender.
 */
- (void) bundlerConfigDidCancel: (BundlerConfigWindowController *) bundlerConfig;

/**
 * Called when the user selects a device family.
 *
 * @param config The sender.
 * @param family The selected PLSimulatorDeviceFamily, or nil if no preset family was selected.
 */
- (void) bundlerConfig: (BundlerConfigWindowController *) bundlerConfig didSelectDeviceFamily: (PLSimulatorDeviceFamily *) family;

@end

@interface BundlerConfigWindowController : NSWindowController {
@private
    /** Device family button. */
    IBOutlet NSPopUpButton *_deviceFamilyButton;
    
    /** Select at launch checkbox. */
    IBOutlet NSButton *_selectAtLaunch;

    /** User message */
    IBOutlet NSTextField *_messageField;

    /** The app to configure. */
    PLSimulatorApplication *_app;

    /** Device families to be selected from. */
    NSArray *_deviceFamilies;

    /** Delegate */
    id<BundlerConfigWindowControllerDelegate> __weak _delegate;
}

- (id) initWithSimulatorApp: (PLSimulatorApplication *) app;

/** Configured application. */
@property(readonly) PLSimulatorApplication *application;

/** Controller delegate. */
@property(weak) id<BundlerConfigWindowControllerDelegate> delegate;

- (IBAction) cancel: (id) sender;
- (IBAction) createBundle: (id) sender;
- (IBAction) checkedSelectAtLaunch: (id) sender;

@end
