/*
 * Author: Landon Fuller <landonf@plausible.coop>
 *
 * Copyright (c) 2011 Landon Fuller <landonf@bikemonkey.org>
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

#import <objc/runtime.h>

#import "PLUniversalBinary.h"
#import "PLSimulator.h"
#import "PLMachO.h"

#import <dlfcn.h>

#import <inttypes.h>

#import <unistd.h>
#import <fcntl.h>
#import <sys/stat.h>
#import <sys/mman.h>

#import <mach-o/arch.h>
#import <mach-o/loader.h>
#import <mach-o/fat.h>

/**
 * @internal
 *
 * Implements reading of Mach-O universal binaries, and mapping of architecture-specific data.
 *
 * @par Thread Safety
 * Immutable and thread-safe. May be used from any thread.
 */
@implementation PLUniversalBinary

@synthesize executables = _executables;

/**
 * Create and initialize a new instance with the provided binary path.
 *
 * @param path Path to the Mach-O binary. If non-universal, the receiver will parse the binary and vend
 * a single PLExecutbleBinary instance.
 * @param error If an error occurs, upon return contains an NSError object that describes the problem.
 *
 * @return Returns an initialized PLUniversalBinary instance, or nil if binary can not
 * be parsed.
 */
+ (id) binaryWithPath: (NSString *) path error: (NSError **) outError {
    return [[[self alloc] initWithPath: path error: outError] autorelease];
}

/**
 * Initialize with the provided binary path.
 *
 * @param path Path to the Mach-O binary. If non-universal, the receiver will parse the binary and vend
 * a single PLExecutbleBinary instance.
 * @param error If an error occurs, upon return contains an NSError object that describes the problem.
 *
 * @return Returns an initialized PLUniversalBinary instance, or nil if binary can not
 * be parsed.
 */
- (id) initWithPath: (NSString *) path error: (NSError **) outError {
    if ((self = [super init]) == nil) {
        // Shouldn't happen
        plsimulator_populate_nserror(outError, PLSimulatorErrorUnknown, @"Unexpected error", nil);
        return nil;
    }
    
    _path = [path retain];
    
    /* Verify that the path exists */
    NSFileManager *fm = [NSFileManager new];
    BOOL isDir;
    if (![fm fileExistsAtPath: _path isDirectory: &isDir] || isDir == YES) {
        NSString *desc = NSLocalizedString(@"The provided library path does not exist or is a directory.",
                                           @"Missing/non-directory library path");
        plsimulator_populate_nserror(outError, PLSimulatorErrorInvalidBinary, desc, nil);
        
        [self release];
        return nil;
    }
    
    /* Open the file */
    NSData *mapped = [NSData dataWithContentsOfMappedFile: _path];
    if (mapped == nil) {
        NSError *posixErr = [NSError errorWithDomain: NSPOSIXErrorDomain code: errno userInfo: nil];
        NSString *desc = NSLocalizedString(@"Could not mmap() binary.", @"Invalid library path");
        plsimulator_populate_nserror(outError, PLSimulatorErrorInvalidBinary, desc, posixErr);
        
        [self release];
        return nil;
    }

    /* Configure parser */
    macho_input_t input;
    input.data = [mapped bytes];
    input.length = [mapped length];

    /* Read the file type. */
    const uint32_t *magic = pl_macho_read(&input, input.data, sizeof(uint32_t));
    if (magic == NULL) {
        NSString *desc = NSLocalizedString(@"Could not read Mach-O magic.", @"Invalid binary");
        plsimulator_populate_nserror(outError, PLSimulatorErrorInvalidBinary, desc, nil);        
        [self release];
        return nil;
    }
    
    /* Parse the Mach-O header */
    BOOL universal = false;
    const struct fat_header *fat_header;
    
    switch (*magic) {
        case MH_CIGAM:
        case MH_MAGIC:
        case MH_CIGAM_64:
        case MH_MAGIC_64:
            /* Non-universal */
            break;
            
        case FAT_CIGAM:
        case FAT_MAGIC:
            fat_header = pl_macho_read(&input, input.data, sizeof(*fat_header));
            universal = true;
            break;
            
        default: {
            NSString *desc = NSLocalizedString(@"Unknown Mach-O magic value.", @"Invalid binary");
            plsimulator_populate_nserror(outError, PLSimulatorErrorInvalidBinary, desc, nil);        
            [self release];
            return nil;
        }
    }
    
    /* Parse out executables available in the universal file. */
    NSMutableArray *executableData = [NSMutableArray array];
    if (universal) {
        uint32_t nfat = OSSwapBigToHostInt32(fat_header->nfat_arch);
        const struct fat_arch *archs = pl_macho_offset(&input, fat_header, sizeof(struct fat_header), sizeof(struct fat_arch));
        if (archs == NULL) {
            NSString *desc = NSLocalizedString(@"Could not read Mach-O universal architecture list.", @"Invalid binary");
            plsimulator_populate_nserror(outError, PLSimulatorErrorInvalidBinary, desc, nil);        
            [self release];
            return nil;
        }
        
        for (uint32_t i = 0; i < nfat; i++) {
            const struct fat_arch *arch = pl_macho_read(&input, archs + i, sizeof(struct fat_arch));
            if (arch == NULL) {
                NSString *desc = NSLocalizedString(@"Could not read Mach-O universal architecture.", @"Invalid binary");
                plsimulator_populate_nserror(outError, PLSimulatorErrorInvalidBinary, desc, nil);        
                [self release];
                return nil;
            }
            
            /* Fetch a pointer to the architecture's Mach-O data. */
            macho_input_t arch_input;
            arch_input.length = OSSwapBigToHostInt32(arch->size);
            arch_input.data = pl_macho_offset(&input, input.data, OSSwapBigToHostInt32(arch->offset), arch_input.length);
            if (arch_input.data == NULL) {
                NSString *desc = NSLocalizedString(@"Could not read Mach-O universal executable.", @"Invalid binary");
                plsimulator_populate_nserror(outError, PLSimulatorErrorInvalidBinary, desc, nil);        
                [self release];
                return nil;
            }
            
            /* Set up a zero-copy subrange of the mapped data. We use an associated object to prevent the mapped
             * data from being deallocated out from underneath us. In theory there is a private API internal
             * to NSData that will do exactly this, but there are no guarantees regarding when it will be used */
            NSData *data = [NSData dataWithBytesNoCopy: (void *) arch_input.data length: arch_input.length freeWhenDone: NO];
            static const char *key = "key";
            objc_setAssociatedObject(data, &key, mapped, OBJC_ASSOCIATION_RETAIN);
        
            [executableData addObject: data];
        }        
    } else {
        /* Only one executable */
        [executableData addObject: mapped];
    }
    
    /* Parse out the executable data */
    NSMutableArray *executables = [NSMutableArray arrayWithCapacity: [executableData count]];
    
    for (NSData *data in executableData) {
        NSError *error;
        PLExecutableBinary *binary = [PLExecutableBinary binaryWithData: data error: &error];
        if (binary == nil) {
            NSLog(@"Skipping invalid member of universal binary: %@", error);
            continue;
        }

        [executables addObject: binary];
    }
    
    _executables = [executables retain];

    return self;
}

- (void) dealloc {
    [_path release];
    [_executables release];

    [super dealloc];
}

/**
 * Load the binary represented by the receiver using dlopen().
 *
 * TODO: Document @rpath behavior.
 *
 * @param error If an error occurs, upon return contains an NSError object that describes the problem.
 * @return Returns YES on success, or NO on failure.
 */
- (BOOL) loadLibrary: (NSError **) outError {
    const NXArchInfo *archInfo = NXGetLocalArchInfo();

    PLExecutableBinary *matchedExec = nil;
    for (PLExecutableBinary *exec in self.executables) {
        if (exec.cpu_type == archInfo->cputype) {
            if (matchedExec == nil) {
                matchedExec = exec;
            } else if (exec.cpu_subtype == archInfo->cpusubtype) {
                matchedExec = exec;
            }
        }
    }
    
    if (matchedExec == nil) {
        NSString *desc = NSLocalizedString(@"This binary is not supported by the current architecture.", @"Invalid binary");
        plsimulator_populate_nserror(outError, PLSimulatorErrorInvalidBinary, desc, nil);        
        return NO;
    }

    /* Recursively link @rpath-requiring libraries */
    for (NSString *dylib in matchedExec.dylibPaths) {
        if ([dylib rangeOfString: @"@rpath/"].location != NSNotFound) {
            // XXX - Implement real search paths
            dylib = [dylib stringByReplacingOccurrencesOfString: @"@rpath/" withString: @"/Applications/Xcode.app/Contents/OtherFrameworks/"];
            
        }

        /* Load the target */
        PLUniversalBinary *linkTarget = [PLUniversalBinary binaryWithPath: dylib error: outError];
        if (linkTarget == nil)
            return NO;
        
        if (![linkTarget loadLibrary: outError])
            return NO;
    }
    
    /* Perform our own link */
    if (dlopen([_path fileSystemRepresentation], RTLD_GLOBAL) == NULL) {
        NSString *descFmt = NSLocalizedString(@"Failed to load library: %s.", @"Invalid binary");
        NSString *desc = [NSString stringWithFormat: descFmt, dlerror()];
        plsimulator_populate_nserror(outError, PLSimulatorErrorInvalidBinary, desc, nil);   
    }

    return YES;
}

@end
