#import "VCAMGlobals.h"
#import <AVFoundation/AVFoundation.h>

%hook UIApplication

- (void)applicationDidBecomeActive:(UIApplication *)application {
    if (vcamEnabled) {
        // بدء تسجيل الشاشة
    }
}

%end
