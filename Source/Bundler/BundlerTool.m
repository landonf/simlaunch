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

#import "BundlerTool.h"

/* Resource-relative launcher template path. */
#define TEMPLATE_APP @"Launcher.app"

/* Resource-relative script to execute. */
#define BUNDLE_TOOL @"bundle-tool.sh"

@interface BundlerTool (PrivateMethods)
- (void) taskCompleted: (NSNotification *) notification;
@end

/**
 * Wraps execution of the command line bundler script.
 */
@implementation BundlerTool

- (id) init {
    if ((self = [super init]) == nil)
        return nil;
    
    _taskBlocks = [NSMapTable mapTableWithStrongToStrongObjects];

    return self;
}

/**
 * Execute the bundler tool.
 *
 * @param app Application to bundle.
 * @param deviceFamily Device family to target.
 */
- (void) executeWithSimulatorApp: (PLSimulatorApplication *) app deviceFamily: (NSString *) deviceFamily block: (BundlerToolCompletedBlock) block {
    NSBundle *bundle = [NSBundle bundleForClass: [self class]];

    /* Fetch the template path */
    NSString *template = [bundle pathForResource: TEMPLATE_APP ofType: nil];
    assert(template != nil);

    /* Create the task */
    NSTask *task = [NSTask new];
    NSString *tool = [bundle pathForAuxiliaryExecutable: BUNDLE_TOOL];
    assert(tool != nil);

    [task setLaunchPath: tool];
    [task setArguments: [NSArray arrayWithObjects: app.path, deviceFamily, template, nil]];

    /* Watch for completion */
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver: self 
           selector: @selector(taskCompleted:)
               name: NSTaskDidTerminateNotification 
             object: task];

    [_taskBlocks setObject: [block copy] forKey: task];

    /* Execute */
    [task launch];
}

@end


@implementation BundlerTool (PrivateMethods)

// NSTaskDidTerminateNotification 
- (void) taskCompleted: (NSNotification *) notification {
    NSTask *task = [notification object];

    /* Disable listening */
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver: self name: NSTaskDidTerminateNotification object: task];
    
    /* Check for error */
    // TODO - Improve error reporting by defining additional error codes.
    BOOL succeeded = YES;
    if ([task terminationStatus] != 0)
        succeeded = NO;

    /* Fetch and execute callback */
    BundlerToolCompletedBlock block = [_taskBlocks objectForKey: task];
    assert(block != NULL);
    block(succeeded);
}

@end