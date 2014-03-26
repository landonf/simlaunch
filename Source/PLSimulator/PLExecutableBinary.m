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

#import "PLExecutableBinary.h"

#import "PLSimulator.h"
#import "PLMachO.h"


#import <mach-o/arch.h>
#import <mach-o/loader.h>
#import <mach-o/fat.h>

/**
 * @internal
 *
 * Implements reading of Mach-O non-universal binaries.
 *
 * @par Thread Safety
 * Immutable and thread-safe. May be used from any thread.
 *
 * As a caveat to the above, multiple threads must involve synchronization to avoid issues with
 * loading conflicting libraries.
 */
@implementation PLExecutableBinary

@synthesize cpu_type = _cpu_type;
@synthesize cpu_subtype = _cpu_subtype;
@synthesize rpaths = _rpaths;
@synthesize dylibPaths = _dylibPaths;

/* Some byteswap wrappers */
static uint32_t macho_swap32 (uint32_t input) {
    return OSSwapInt32(input);
}

static uint32_t macho_nswap32(uint32_t input) {
    return input;
}


/**
 * Create and initialize a new instance with the provided Mach-O @a data.
 *
 * @param path The binary path for this image, used to handle image-relative DYLD_DYLIB references.
 * @param data A buffer containing a full Mach-O binary.
 * @param outError If an error occurs, upon return contains an NSError object that describes the problem.
 *
 * @return Returns an initialized PLExecutableBinary instance, or nil if binary can not
 * be parsed.
 */
+ (id) binaryWithPath: (NSString *) path data: (NSData *) data error: (NSError **) outError {
    return [[self alloc] initWithPath: path data: data error: outError];
}

/**
 * Initialize a new instance with the provided Mach-O @a data.
 *
 * @param path The binary path for this image, used to handle image-relative DYLD_DYLIB references.
 * @param data A buffer containing a full Mach-O binary.
 * @param outError If an error occurs, upon return contains an NSError object that describes the problem.
 *
 * @return Returns an initialized PLExecutableBinary instance, or nil if binary can not
 * be parsed.
 */
- (id) initWithPath: (NSString *) path data: (NSData *) data error: (NSError **) outError {
    if ((self = [super init]) == nil)
        return nil;
    
    _path = path;
    
    /* Configure parser */
    macho_input_t input;
    input.data = [data bytes];
    input.length = [data length];
    
    /* Read the file type. */
    const uint32_t *magic = pl_macho_read(&input, input.data, sizeof(uint32_t));
    if (magic == NULL) {
        NSString *desc = NSLocalizedString(@"Could not read Mach-O magic.", @"Invalid binary");
        plsimulator_populate_nserror(outError, PLSimulatorErrorInvalidBinary, desc, nil);        
        return nil;
    }
    
    /* Parse the Mach-O header */
    bool m64 = false;
    uint32_t (*swap32)(uint32_t) = macho_nswap32;

    const struct mach_header *header;
    const struct mach_header_64 *header64;
    size_t header_size;
    
    switch (*magic) {
        case MH_CIGAM:
            swap32 = macho_swap32;
            // Fall-through
            
        case MH_MAGIC:
            
            header_size = sizeof(*header);
            header = pl_macho_read(&input, input.data, header_size);
            if (header == NULL) {
                NSString *desc = NSLocalizedString(@"Could not read Mach-O header.", @"Invalid binary");
                plsimulator_populate_nserror(outError, PLSimulatorErrorInvalidBinary, desc, nil);        
                return nil;
            }
            break;

        case MH_CIGAM_64:
            swap32 = macho_swap32;
            // Fall-through
            
        case MH_MAGIC_64:
            header_size = sizeof(*header64);
            header64 = pl_macho_read(&input, input.data, sizeof(*header64));
            if (header64 == NULL) {
                NSString *desc = NSLocalizedString(@"Could not read Mach-O header.", @"Invalid binary");
                plsimulator_populate_nserror(outError, PLSimulatorErrorInvalidBinary, desc, nil);        
                return nil;
            }
            
            /* The 64-bit header is a direct superset of the 32-bit header */
            header = (struct mach_header *) header64;

            m64 = true;
            break;
            
        default: {
            NSString *desc = NSLocalizedString(@"Unknown Mach-O magic value.", @"Invalid binary");
            plsimulator_populate_nserror(outError, PLSimulatorErrorInvalidBinary, desc, nil);        
            return nil;
        }
    }

    /* Save the CPU subtypes */
    _cpu_type = header->cputype;
    _cpu_subtype = header->cpusubtype;
    
    /* Parse the Mach-O load commands */
    const struct load_command *cmd = pl_macho_offset(&input, header, header_size, sizeof(struct load_command));
    if (cmd == NULL) {
        NSString *desc = NSLocalizedString(@"Could not fetch Mach-O load command.", @"Invalid binary");
        plsimulator_populate_nserror(outError, PLSimulatorErrorInvalidBinary, desc, nil);        
        return nil;
    }
    uint32_t ncmds = swap32(header->ncmds);
    
    /* Iterate over the load commands */
    NSMutableArray *rpaths = [NSMutableArray array];
    _rpaths = rpaths;

    NSMutableArray *dylibs = [NSMutableArray array];
    _dylibPaths = dylibs;
    
    for (uint32_t i = 0; i < ncmds; i++) {
        /* Load the full command */
        uint32_t cmdsize = swap32(cmd->cmdsize);
        cmd = pl_macho_read(&input, cmd, cmdsize);
        if (cmd == NULL) {
            NSString *desc = NSLocalizedString(@"Could not read Mach-O load command.", @"Invalid binary");
            plsimulator_populate_nserror(outError, PLSimulatorErrorInvalidBinary, desc, nil);        
            return nil;
        }
        
        /* Handle known types */
        uint32_t cmd_type = swap32(cmd->cmd);
        switch (cmd_type) {
            case LC_RPATH: {
                /* Fetch the path */
                if (cmdsize < sizeof(struct rpath_command)) {
                    NSString *desc = NSLocalizedString(@"LC_RPATH has an invalid size", @"Invalid binary");
                    plsimulator_populate_nserror(outError, PLSimulatorErrorInvalidBinary, desc, nil);        
                    return nil;
                }
                
                size_t pathlen = cmdsize - sizeof(struct rpath_command);
                const void *pathptr = pl_macho_offset(&input, cmd, sizeof(struct rpath_command), pathlen);
                if (pathptr == NULL) {
                    NSString *desc = NSLocalizedString(@"Could not read path name from LC_RPATH", @"Invalid binary");
                    plsimulator_populate_nserror(outError, PLSimulatorErrorInvalidBinary, desc, nil);        
                    return nil;
                }
                
                NSString *path = [[NSString alloc] initWithBytes: pathptr
                                                          length: strnlen(pathptr, pathlen)
                                                        encoding: NSUTF8StringEncoding];
                [rpaths addObject: path];
                break;
            }
                
            case LC_LOAD_DYLIB: {
                // const struct dylib_command *dylib_cmd = (const struct dylib_command *) cmd;
                
                /* Extract the install name */
                if (cmdsize < sizeof(struct dylib_command)) {
                    NSString *desc = NSLocalizedString(@"LC_LOAD_DYLIB has invalid size", @"Invalid binary");
                    plsimulator_populate_nserror(outError, PLSimulatorErrorInvalidBinary, desc, nil);        
                    return nil;
                }
                
                size_t namelen = cmdsize - sizeof(struct dylib_command);
                const void *nameptr = pl_macho_offset(&input, cmd, sizeof(struct dylib_command), namelen);
                if (nameptr == NULL) {
                    NSString *desc = NSLocalizedString(@"Could not read path name from LC_LOAD_DYLIB", @"Invalid binary");
                    plsimulator_populate_nserror(outError, PLSimulatorErrorInvalidBinary, desc, nil);        
                    return nil;
                }
                
                NSString *name = [[NSString alloc] initWithBytes: nameptr
                                                          length: strnlen(nameptr, namelen)
                                                        encoding: NSUTF8StringEncoding];
                [dylibs addObject: name];

                break;
            }
                
            default:
                break;
        }
        
        /* Load the next command */
        cmd = pl_macho_offset(&input, cmd, cmdsize, sizeof(struct load_command));
        if (cmd == NULL) {
            NSString *desc = NSLocalizedString(@"Could not fetch next Mach-O load command.", @"Invalid binary");
            plsimulator_populate_nserror(outError, PLSimulatorErrorInvalidBinary, desc, nil);        
            return nil;
        }
    }

    return self;
}

/**
 * Return the array of the receiver's defined LC_RPATH values, replacing @executable_path and @loader_path
 * with the real executable path.
 */
- (NSArray *) absoluteRpaths {
    /* Formulate the correct @rpath candidates from the Xcode bundle, if available */
    NSMutableArray *absolutePaths = [NSMutableArray array];
    for (NSString *rpath in _rpaths) {
        NSMutableArray *pathComponents = [[rpath pathComponents] mutableCopy];
        NSMutableArray *result = [NSMutableArray arrayWithCapacity: [pathComponents count]];
        
        /* Replace all special dylib paths */
        for (NSString *component in pathComponents) {
            if ([component isEqualToString: @"@executable_path"] || [component isEqualToString: @"@loader_path"]) {
                [result addObjectsFromArray: [_path pathComponents]];
            } else {
                [result addObject: component];
            }
        }

        /* Strip out '..' paths. These are used to reference paths above the image path. */
        pathComponents = result;
        result = [NSMutableArray arrayWithCapacity: [pathComponents count]];
        while ([pathComponents count] > 0) {
            /* Pop the first component */
            NSString *top = [pathComponents objectAtIndex: 0];
            [pathComponents removeObjectAtIndex: 0];

            if ([top isEqualToString: @".."]) {
                /* Handle backtracking (assuming there is data to backtrack) */
                if ([result count] < 2)
                    continue;
                
                [result removeLastObject];
                [result removeLastObject];

            } else if ([top isEqualToString: @"."]) {
                /* Skip empty nodes */
                
            } else {
                /* Otherwise, add standard paths to the target */
                [result addObject: top];
            }
        }

        [absolutePaths addObject: [NSString pathWithComponents: result]];
    }
    
    return absolutePaths;
}


@end
