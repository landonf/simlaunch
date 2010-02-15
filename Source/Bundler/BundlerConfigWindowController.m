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


#import "BundlerConfigWindowController.h"

/**
 * Presents a configuration UI for bundled applications.
 */
@implementation BundlerConfigWindowController

@synthesize application = _app;
@synthesize delegate = _delegate;

/**
 * Initialize a configuration window for the given application.
 *
 * @param app The app to be configured.
 */
- (id) initWithSimulatorApp: (PLSimulatorApplication *) app {
    if ((self = [super initWithWindowNibName: @"AppConfig"]) == nil)
        return nil;
    
    _app = app;

    return self;
}

// from NSWindowController
- (void) windowDidLoad {
    /* Set the title */
    [[self window] setTitle: _app.displayName];
    
    /* Set the user message */
    NSString *msgFmt = NSLocalizedString(@"%@ is a universal application. What device would you like to simulate when it is launched?",
                                         @"App configuration message.");
    [_messageField setStringValue: [NSString stringWithFormat: msgFmt, _app.displayName]];

    
    NSMutableDictionary *nameMap = [NSMutableDictionary dictionary];
    _deviceNameMap = nameMap;

    /* Add all supported device types */
    [_deviceFamilyButton removeAllItems];
    for (NSString *family in _app.deviceFamilies) {
        if ([family isEqualTo: PLSimulatorDeviceFamilyiPad]) {
            NSString *name = NSLocalizedString(@"iPad", @"iPad device name");

            [nameMap setObject: PLSimulatorDeviceFamilyiPad forKey: name];
            [_deviceFamilyButton addItemWithTitle: name];

        } else if ([family isEqualTo: PLSimulatorDeviceFamilyiPhone]) {
            NSString *name = NSLocalizedString(@"iPhone", @"iPhone device name");
            
            [nameMap setObject: PLSimulatorDeviceFamilyiPhone forKey: name];
            [_deviceFamilyButton addItemWithTitle: name];
        }
    }
}

- (IBAction) cancel: (id) sender {
    [_delegate bundlerConfigDidCancel: self];
}

- (IBAction) createBundle: (id) sender {
    NSString *family = [_deviceNameMap objectForKey: [_deviceFamilyButton titleOfSelectedItem]];
    [_delegate bundlerConfig: self didSelectDeviceFamily: family];
}


@end
