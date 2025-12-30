#import "VCAMConfig.h"

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        if (VCAMIsFirstRun()) {
            [[NSNotificationCenter defaultCenter]
                postNotificationName:@"VCAMShowSetup"
                object:nil];
        }
    });
}
