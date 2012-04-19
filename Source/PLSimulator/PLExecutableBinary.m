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

/* Some byteswap wrappers */
static uint32_t macho_swap32 (uint32_t input) {
    return OSSwapInt32(input);
}

static uint32_t macho_nswap32(uint32_t input) {
    return input;
}

/* return a human readable formatted version number. the result must be free()'d. */
static char *macho_format_dylib_version (uint32_t version) {
    char *result;
    asprintf(&result, "%"PRIu32".%"PRIu32".%"PRIu32, (version >> 16) & 0xFF, (version >> 8) & 0xFF, version & 0xFF);
    return result;
}


/**
 * Create and initialize a new instance with the provided Mach-O @a data.
 *
 * @param data A buffer containing a full Mach-O binary.
 * @param outError If an error occurs, upon return contains an NSError object that describes the problem.
 *
 * @return Returns an initialized PLExecutableBinary instance, or nil if binary can not
 * be parsed.
 */
+ (id) binaryWithData: (NSData *) data error: (NSError **) outError {
    return [[[self alloc] initWithData: data error: outError] autorelease];
}

/**
 * Initialize a new instance with the provided Mach-O @a data.
 *
 * @param data A buffer containing a full Mach-O binary.
 * @param outError If an error occurs, upon return contains an NSError object that describes the problem.
 *
 * @return Returns an initialized PLExecutableBinary instance, or nil if binary can not
 * be parsed.
 */
- (id) initWithData: (NSData *) data error: (NSError **) outError {
    if ((self = [super init]) == nil)
        return nil;
    
    /* Configure parser */
    macho_input_t input;
    input.data = [data bytes];
    input.length = [data length];
    
    /* Read the file type. */
    const uint32_t *magic = pl_macho_read(&input, input.data, sizeof(uint32_t));
    if (magic == NULL) {
        NSString *desc = NSLocalizedString(@"Could not read Mach-O magic.", @"Invalid binary");
        plsimulator_populate_nserror(outError, PLSimulatorErrorInvalidBinary, desc, nil);        
        [self release];
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
                [self release];
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
                [self release];
                return nil;
            }
            
            /* The 64-bit header is a direct superset of the 32-bit header */
            header = (struct mach_header *) header64;

            m64 = true;
            break;
            
        default: {
            NSString *desc = NSLocalizedString(@"Unknown Mach-O magic value.", @"Invalid binary");
            plsimulator_populate_nserror(outError, PLSimulatorErrorInvalidBinary, desc, nil);        
            [self release];
            return nil;
        }
    }
    
    /* Parse the Mach-O load commands */
    const struct load_command *cmd = pl_macho_offset(&input, header, header_size, sizeof(struct load_command));
    if (cmd == NULL)
        return false;
    uint32_t ncmds = swap32(header->ncmds);
    
    /* Iterate over the load commands */
    for (uint32_t i = 0; i < ncmds; i++) {
        /* Load the full command */
        uint32_t cmdsize = swap32(cmd->cmdsize);
        cmd = pl_macho_read(&input, cmd, cmdsize);
        if (cmd == NULL)
            return false;
        
        /* Handle known types */
        uint32_t cmd_type = swap32(cmd->cmd);
        switch (cmd_type) {
            case LC_RPATH: {
                /* Fetch the path */
                if (cmdsize < sizeof(struct rpath_command)) {
                    // TODO
                    // warnx("Incorrect cmd size");
                    return false;
                }
                
                size_t pathlen = cmdsize - sizeof(struct rpath_command);
                const void *pathptr = pl_macho_offset(&input, cmd, sizeof(struct rpath_command), pathlen);
                if (pathptr == NULL)
                    return false;
                
                char *path = malloc(pathlen);
                strlcpy(path, pathptr, pathlen);
                fprintf(stderr, "[rpath] path=%s\n", path);
                free(path);
                break;
            }
                
            case LC_ID_DYLIB:
            case LC_LOAD_WEAK_DYLIB:
            case LC_REEXPORT_DYLIB:
            case LC_LOAD_DYLIB: {
                const struct dylib_command *dylib_cmd = (const struct dylib_command *) cmd;
                
                /* Extract the install name */
                if (cmdsize < sizeof(struct dylib_command)) {
                    // TODO
                    // warnx("Incorrect name size");
                    return false;
                }
                
                size_t namelen = cmdsize - sizeof(struct dylib_command);
                const void *nameptr = pl_macho_offset(&input, cmd, sizeof(struct dylib_command), namelen);
                if (nameptr == NULL)
                    return false;
                
                char *name = malloc(namelen);
                strlcpy(name, nameptr, namelen);
                
                /* Print the dylib info */
                char *current_version = macho_format_dylib_version(swap32(dylib_cmd->dylib.current_version));
                char *compat_version = macho_format_dylib_version(swap32(dylib_cmd->dylib.compatibility_version));
                
                switch (cmd_type) {
                    case LC_ID_DYLIB:
                        fprintf(stderr, "[dylib] ");
                        break;
                    case LC_LOAD_WEAK_DYLIB:
                        fprintf(stderr, "[weak] ");
                        break;
                    case LC_LOAD_DYLIB:
                        fprintf(stderr, "[load] ");
                        break;
                    case LC_REEXPORT_DYLIB:
                        fprintf(stderr, "[reexport] ");
                        break;
                    default:
                        fprintf(stderr, "[%"PRIx32"] ", cmd_type);
                        break;
                }
                
                /* This is a dyld library identifier */
                fprintf(stderr, "install_name=%s (compatibility_version=%s, version=%s)\n", name, compat_version, current_version);
                
                free(name);
                free(current_version);
                free(compat_version);
                break;
            }
                
            default:
                break;
        }
        
        /* Load the next command */
        cmd = pl_macho_offset(&input, cmd, cmdsize, sizeof(struct load_command));
        if (cmd == NULL)
            return false;
    }

    return self;
}

@end
