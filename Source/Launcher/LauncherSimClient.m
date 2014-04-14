/*
 * Author: Landon Fuller <landonf@plausiblelabs.com>
 *
 * Copyright (c) 2008-2010 Plausible Labs Cooperative, Inc.
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

#import "LauncherSimClient.h"

#import <ScriptingBridge/ScriptingBridge.h>

/* App bundle ID. Used to request that the simulator be brought to the foreground */
#define SIM_APP_BUNDLE_ID @"com.apple.iphonesimulator"

/* Load a class from the runtime-loaded iPhoneSimulatorRemoteClient framework */
#define C(name) NSClassFromString(@"" #name)

/**
 * Implements loading of the iPhoneSimulatorRemoteClient framework and attempts
 * to launch a given simulator application.
 */
@implementation LauncherSimClient

/**
 * Initialize with the given simulator platform and application.
 *
 * @param platform Platform to use for launching.
 * @param app Application to be launched.
 * @param defaultDeviceFamily The device family to use by default, or nil if none specified.
 */
- (id) initWithPlatform: (PLSimulatorPlatform *) platform
                    app: (PLSimulatorApplication *) app 
    defaultDeviceFamily: (PLSimulatorDeviceFamily *) defaultDeviceFamily
{
    if ((self = [super init]) == nil)
        return nil;
    
    _platform = platform;
    _app = app;
    _defaultDeviceFamily = defaultDeviceFamily;

    return self;
}

/**
 * Display a launch error alert and request program termination.
 * 
 * @param text Informative text.
 */
- (void) displayLaunchError: (NSString *) text {
    NSAlert *alert = [NSAlert new];
    [alert setMessageText: NSLocalizedString(@"Could not launch the iPad/iPhone application.", @"Launch failure alert title")];
    [alert setInformativeText: text];
    [alert runModal];
    
    [[NSApplication sharedApplication] terminate: self];
}

/**
 * Attempt to launch the application. This is a single-shot operation, and the application
 * will terminate on error.
 */
- (void) launch {
    DTiPhoneSimulatorApplicationSpecifier *appSpec;
    DTiPhoneSimulatorSystemRoot *sdkRoot;
    DTiPhoneSimulatorSessionConfig *config;
    DTiPhoneSimulatorSession *session;
    NSError *error;
    
    /* Load the framework */
    if (![_platform loadPrivateFrameworks: &error]) {
        NSLog(@"Failed to load private Simulator frameworks: %@", error);
        [self displayLaunchError: NSLocalizedString(@"A failure occured loading the Simulator's private frameworks.",
                                                    @"Failed to load private framework alert text")];
    }
    
    
    /* Find and load all Xcode platform SDKs; without this, the iPhoneSimulatorRemoteClient API will be unable to locate
     * SDK roots via DTiPhoneSimulatorSystemRoot. */
    if (![C(DVTPlatform) loadAllPlatformsReturningError: &error]) {
        NSLog(@"Failed to load platform SDKs: %@", error);
        return;
    }

    /* Create the app specifier */
    appSpec = [C(DTiPhoneSimulatorApplicationSpecifier) specifierWithApplicationPath: _app.path];
    if (appSpec == nil) {
        NSLog(@"Could not load application specification for %@\n", _app.path);
    
        NSString *text = NSLocalizedString(@"The iPhone application specification could not be loaded. This launcher may be misconfigured.", 
                                           @"App load failure");
        [self displayLaunchError: text];
        return;
    }

    NSLog(@"App Spec: %@\n", appSpec);

    /* Fetch the SDK to be used */
    PLSimulatorSDK *sdk = nil;
    for (PLSimulatorSDK *anSDK in _platform.sdks) {
        if ([anSDK.canonicalName isEqual: _app.canonicalSDKName]) {
            sdk = anSDK;
            break;
        }
    }

    /* Load the SDK root */
    if (sdk != nil) {
        sdkRoot = [C(DTiPhoneSimulatorSystemRoot) rootWithSDKVersion: sdk.version];
        if (sdkRoot == nil) {
            NSString *fmt = NSLocalizedString(@"The iPhoneSimulator %@ SDK was not found. Please install the SDK and try again.",
                                              @"SDK load failure alert info");
            NSLog(@"Can't find SDK system root for version %@\n", sdk.version);
            [self displayLaunchError: [NSString stringWithFormat: fmt, sdk.version]];
            return;
        }
    } else {
        sdkRoot = [C(DTiPhoneSimulatorSystemRoot) defaultRoot];
    }
    
    NSLog(@"SDK Root: %@\n", sdkRoot);
    
    /* Set up the session configuration */
    config = [[C(DTiPhoneSimulatorSessionConfig) alloc] init];
    [config setApplicationToSimulateOnStart: appSpec];
    [config setSimulatedSystemRoot: sdkRoot];
    [config setSimulatedApplicationShouldWaitForDebugger: NO];
    
    [config setSimulatedApplicationLaunchArgs: [NSArray array]];
    [config setSimulatedApplicationLaunchEnvironment: [NSDictionary dictionary]];

    /* Configure the target device info */
    {
        ISHDeviceVersions *deviceVersions = [C(ISHDeviceVersions) sharedInstance];
        DTiPhoneSimulatorFamily productType;

        /*
         * Determine best available product type. The ISHDeviceVersions product type seems to be based on,
         * and use the same constant values as, the DTiPhoneSimulatorFamily constants
         */
        NSArray *productTypes = [deviceVersions productTypes];
        if (_defaultDeviceFamily != nil && [productTypes containsObject: @(_defaultDeviceFamily.deviceFamilyCode)]) {
            productType = _defaultDeviceFamily.deviceFamilyCode;
        } else {
            productType = DTiPhoneSimulatoriPhoneFamily;
        }
        
        /*
         * Map to a device info instance.
         * TODO: This is where we could properly support 1x, 2x, 32-bit, and 64-bit, but doing so requires that we have a way
         * to pass these configuration items to the launcher. For now, we hard code the device info selection.
         */
        NSString *deviceInfo;
        switch (productType) {
            case DTiPhoneSimulatoriPadFamily:
                deviceInfo = [deviceVersions deviceInfoForProductType: productType displayScale: 1.0 displayHeight: 1024 wordSize: 4];
                break;
            case DTiPhoneSimulatoriPhoneFamily:
                deviceInfo = [deviceVersions deviceInfoForProductType: productType displayScale: 2.0 displayHeight: 568 wordSize: 4];
                break;
        }

        [config setSimulatedDeviceInfoName: deviceInfo];
    }

    [config setLocalizedClientName: @"SimLauncher"];

    /* Start the session */
    session = [[C(DTiPhoneSimulatorSession) alloc] init];
    [session setDelegate: self];
    [session setSimulatedApplicationPID: [NSNumber numberWithInt: 35]];
    
    if (![session requestStartWithConfig: config timeout: 30.0 error: &error]) {
        NSLog(@"Could not start simulator session: %@", error);

        NSString *text = NSLocalizedString(@"The iPhone Simulator could not be started. If another Simulator application "
                                           "is currently running, please close the Simulator and try again.", 
                                           @"Simulator error alert info");
        [self displayLaunchError: text];
    }
}


// from DTiPhoneSimulatorSessionDelegate protocol
- (void) session: (DTiPhoneSimulatorSession *) session didEndWithError: (NSError *) error {
    // Do we care about this?
    NSLog(@"Did end with error: %@", error);
}

// from DTiPhoneSimulatorSessionDelegate protocol
- (void) session: (DTiPhoneSimulatorSession *) session didStart: (BOOL) started withError: (NSError *) error {
    /* If the application starts successfully, we can exit */
    if (started) {
        NSLog(@"Did start app %@ successfully, exiting", _app.path);

        /* Bring simulator to foreground */
        [[SBApplication applicationWithBundleIdentifier: SIM_APP_BUNDLE_ID] activate];

        /* Exit */
        [[NSApplication sharedApplication] terminate: self];
        return;
    }

    /* Otherwise, an error occured. Inform the user. */
    NSLog(@"Simulator session did not start: %@", error);
    NSString *text = NSLocalizedString(@"The iPhone Simulator could not be started. If another Simulator application "
                                       "is currently running, please close the Simulator and try again.", 
                                       @"Simulator error alert info");
    [self displayLaunchError: text];
}

@end
