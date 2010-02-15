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

#import "PLSimulatorDiscovery.h"

@interface PLSimulatorDiscovery (PrivateMethods)
- (void) queryFinished: (NSNotification *) notification;
@end

/**
 * Implements automatic discovery of local Simulator Platform SDKs.
 *
 * @par Thread Safety
 * Mutable and may not be shared across threads.
 */
@implementation PLSimulatorDiscovery

@synthesize delegate = _delegate;

/**
 * Initialize a new query with the requested minumum simulator SDK version.
 *
 * @param version The required minumum simulator SDK version (3.0, 3.1.2, 3.2, etc).
 * @param deviceFamilies The set of requested device families. Platform SDKs that match any of these device
 * families will be returned. See \ref plsimulator_device_family Device Family Constants.
 */
- (id) initWithMinimumVersion: (NSString *) version deviceFamilies: (NSSet *) deviceFamilies {
    if ((self = [super init]) == nil)
        return nil;
    
    _version = [version copy];
    _deviceFamilies = deviceFamilies;
    _query = [NSMetadataQuery new];

    /* Set up a query for all iPhoneSimulator platform directories. We use kMDItemDisplayName rather than
     * the more correct kMDItemFSName for performance reasons -- */
    NSArray *predicates = [NSArray arrayWithObjects:
                           [NSPredicate predicateWithFormat: @"kMDItemDisplayName == 'iPhoneSimulator.platform'"],
                           [NSPredicate predicateWithFormat: @"kMDItemContentTypeTree == 'public.directory'"],
                           nil];
    [_query setPredicate: [NSCompoundPredicate andPredicateWithSubpredicates: predicates]];

    /* We want to search the root volume for the developer tools. */
    NSURL *root = [NSURL fileURLWithPath: @"/" isDirectory: YES];
    [_query setSearchScopes: [NSArray arrayWithObject: root]];

    /* Configure result listening */
    NSNotificationCenter *nf = [NSNotificationCenter defaultCenter];
    [nf addObserver: self 
           selector: @selector(queryFinished:)
               name: NSMetadataQueryDidFinishGatheringNotification 
             object: _query];

    [_query setDelegate: self];

    return self;
}

/**
 * Start the query. A query can't be started if one is already running.
 */
- (void) startQuery {
    assert(_running == NO);
    _running = YES;

    [_query startQuery];
}

@end

/**
 * @internal
 */
@implementation PLSimulatorDiscovery (PrivateMethods)

// NSMetadataQueryDidFinishGatheringNotification
- (void) queryFinished: (NSNotification *) note {
    /* Received the full spotlight query result set. No longer running */
    _running = NO;

    /* Convert the items into PLSimulatorPlatform instances, filtering out results that don't match the minimum version
     * and supported device families. */
    NSArray *results = [_query results];
    NSMutableArray *platformSDKs = [NSMutableArray arrayWithCapacity: [results count]];

    for (NSMetadataItem *item in results) {
        PLSimulatorPlatform *platform;
        NSString *path;
        NSError *error;

        path = [[item valueForAttribute: (NSString *) kMDItemPath] stringByResolvingSymlinksInPath];
        platform = [[PLSimulatorPlatform alloc] initWithPath: path error: &error];
        if (platform == nil) {
            NSLog(@"Skipping platform discovery result '%@', failed to load platform SDK meta-data: %@", path, error);
            continue;
        }

        /* Check the minimum version and device families */
        BOOL hasMinVersion = NO;
        BOOL hasDeviceFamily = NO;
        for (PLSimulatorSDK *sdk in platform.sdks) {
            /* If greater than or equal to the minimum version, this platform SDK meets the requirements */
            if (rpm_vercomp([sdk.version UTF8String], [_version UTF8String]) >= 0)
                hasMinVersion = YES;

            /* If any our requested families are included, this platform SDK meets the requirements. */
            for (NSString *family in _deviceFamilies) {
                if ([sdk.deviceFamilies containsObject: family]) {
                    hasDeviceFamily = YES;
                    continue;
                }
            }
        }

        if (!hasMinVersion || !hasDeviceFamily)
            continue;

        [platformSDKs addObject: platform];
    }
    
    /* Inform the delegate */
    [_delegate simulatorDiscovery: self didFindMatchingSimulatorPlatforms: platformSDKs];
}

@end