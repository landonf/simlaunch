/*
 * Author: Landon Fuller <landonf@plausible.coop>
 *
 * Copyright (c) 2010-2012 Plausible Labs Cooperative, Inc.
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

#import <Foundation/Foundation.h>
#import <mach-o/arch.h>

@interface PLExecutableBinary : NSObject {
    /** The image path */
    NSString *_path;
    
    /** CPU type. */
    cpu_type_t _cpu_type;

    /** CPU subtype */
    cpu_subtype_t _cpu_subtype;
    
    /** Defined rpaths */
    NSArray *_rpaths;
    
    /** Library references. */
    NSArray *_dylibPaths;
}

+ (id) binaryWithPath: (NSString *) path data: (NSData *) data error: (NSError **) outError;
- (id) initWithPath: (NSString *) path data: (NSData *) data error: (NSError **) outError;

- (NSArray *) absoluteRpaths;

/** CPU type of this binary */
@property(nonatomic, readonly) cpu_type_t cpu_type;

/** CPU subtype of this binary */
@property(nonatomic, readonly) cpu_type_t cpu_subtype;

/** LC_RPATH paths defined by this binary */
@property(nonatomic, readonly) NSArray *rpaths;

/** LC_LOAD_DYLIB paths defined by this binary */
@property(nonatomic, readonly) NSArray *dylibPaths;

@end
