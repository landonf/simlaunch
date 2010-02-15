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

#import <Foundation/Foundation.h>

/**
 * @defgroup functions Functions Reference
 */

/**
 * @defgroup types Data Types Reference
 */

/**
 * @defgroup constants Constants Reference
 */

extern NSString *PLSimulatorDeviceFamilyiPhone;
extern NSString *PLSimulatorDeviceFamilyiPad;

/**
 * @defgroup internal Internal Documentation
 */

/**
 * @defgroup enums Enumerations
 * @ingroup constants
 */

/**
 * @defgroup globals Global Variables
 * @ingroup constants
 */

/**
 * @defgroup exceptions Exceptions
 * @ingroup constants
 */

/* Exceptions */
extern NSString *PLSimulatorException;

/* Error Domain and Codes */
extern NSString *PLSimulatorErrorDomain;

/**
 * NSError codes in the Plausible Simulator error domain.
 * @ingroup enums
 */
typedef enum {
    /** No error occured (Success). */
    PLSimulatorErrorNone = 0,
    
    /** An unknown error has occured. If this code is received, it is a bug, and should be reported. */
    PLSimulatorErrorUnknown = 1,
    
    /** An Mach or POSIX operating system error has occured. The underlying NSError cause may be fetched from the userInfo
     * dictionary using the NSUnderlyingErrorKey key. */
    PLSimulatorErrorOperatingSystem = 2,

    /** The provided path is not a valid SDK. */
    PLSimulatorErrorInvalidSDK = 3
} PLSimulatorError;


NSError *plsimulator_nserror (PLSimulatorError code, NSString *description, NSError *cause);
void plsimulator_populate_nserror (NSError **error, PLSimulatorError code, NSString *description, NSError *cause);

/* Library Imports */
#import "PLSimulatorSDK.h"
#import "PLSimulatorPlatform.h"
#import "PLSimulatorDiscovery.h"
#import "PLSimulatorApplication.h"

/**
 * @mainpage Plausible Simulator Client
 *
 * @section intro_sec Introduction
 *
 * Plausible Simulator implements a higher-level wrapper around Apple's iPhoneSimulatorRemoteClient private API.
 *
 * @section doc_sections Documentation Sections
 * - @subpage error_handling
 */

/**
 * @page error_handling Error Handling Programming Guide
 *
 * Where a method may return an error, PLSimulator provides access to the underlying
 * cause via an optional PLSimulator argument.
 *
 * All returned errors will be a member of one of the below defined domains, however, new domains and
 * error codes may be added at any time. If you do not wish to report on the error cause, many methods
 * support a simple form that requires no NSError argument.
 *
 * @section Error Domains, Codes, and User Info
 *
 * @subsection plsimulator_errors Plausible Simulator Errors
 *
 * Any errors in Plausible Simulator use the #PLSimulatorErrorDomain error domain, and and one
 * of the error codes defined in #PLSimulatorError.
 */
