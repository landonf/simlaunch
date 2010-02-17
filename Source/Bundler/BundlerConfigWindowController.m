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

    /* Save the supported device families, sorting alphabetically */
    NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey: @"localizedName" 
                                                         ascending: YES 
                                                          selector: @selector(localizedCompare:)];
    _deviceFamilies = [[_app.deviceFamilies allObjects] sortedArrayUsingDescriptors: [NSArray arrayWithObject: sort]];
    
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
    
    /* Set the "choose at launch" message */
    msgFmt = NSLocalizedString(@"Choose the device when %@ is launched.", @"App configuration dialog message");
    [_selectAtLaunch setTitle: [NSString stringWithFormat: msgFmt, _app.displayName]];

    /* Add all supported device types */
    [_deviceFamilyButton removeAllItems];
    for (PLSimulatorDeviceFamily *family in _deviceFamilies)
        [_deviceFamilyButton addItemWithTitle: family.localizedName];

}

- (IBAction) cancel: (id) sender {
    [_delegate bundlerConfigDidCancel: self];
}

- (IBAction) createBundle: (id) sender {
    PLSimulatorDeviceFamily *family = [_deviceFamilies objectAtIndex: [_deviceFamilyButton indexOfSelectedItem]];
    [_delegate bundlerConfig: self didSelectDeviceFamily: family];
}

- (IBAction) checkedSelectAtLaunch: (id) sender {
    if ([_selectAtLaunch state] == NSOnState) {
        [_deviceFamilyButton setEnabled: NO];
    } else {
        [_deviceFamilyButton setEnabled: YES];
    }
}

@end
