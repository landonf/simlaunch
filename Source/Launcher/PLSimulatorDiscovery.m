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
 */
@implementation PLSimulatorDiscovery

/**
 * Initialize a new query with the requested minumum simulator SDK version.
 *
 * @param version The required simulator SDK version (3.0, 3.1.2, 3.2, etc).
 */
- (id) initWithVersion: (NSString *) version {
    if ((self = [super init]) == nil)
        return nil;
    
    _version = [version copy];
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

    /* Convert the items into NSString paths. */
    NSArray *results = [_query results];
    NSMutableArray *paths = [NSMutableArray arrayWithCapacity: results];

    for (NSMetadataItem *item in results) {
        NSString *path = [[item valueForAttribute: (NSString *) kMDItemPath] stringByResolvingSymlinksInPath];
        [paths addObject: path];
    }
    
    NSLog(@"Got paths");

}

@end