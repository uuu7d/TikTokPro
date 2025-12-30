#import <Foundation/Foundation.h>

#define kVCAMEnabledKey      @"vcam_enabled"
#define kVCAMFirstRunKey     @"vcam_first_run"
#define kVCAMMediaPathKey   @"vcam_media_path"

static inline NSUserDefaults *VCAMDefaults() {
    return [NSUserDefaults standardUserDefaults];
}

static inline BOOL VCAMIsFirstRun() {
    return ![VCAMDefaults() boolForKey:kVCAMFirstRunKey];
}

static inline void VCAMMarkConfigured() {
    [VCAMDefaults() setBool:YES forKey:kVCAMFirstRunKey];
}
