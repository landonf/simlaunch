#import "DVTiPhoneSimulatorRemoteClient.h"

/** Device family constants  */
typedef enum {
    /** iPhone/iPod Devices. */
    DTiPhoneSimulatoriPhoneFamily = 1,
    
    /** iPad Devices */
    DTiPhoneSimulatoriPadFamily = 2
} DTiPhoneSimulatorFamily;

/** Platform API */
@interface DVTPlatform : NSObject

/** Load all platform SDKs */
+ (BOOL)loadAllPlatformsReturningError:(id*)arg1;

@end