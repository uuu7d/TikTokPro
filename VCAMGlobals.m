#import "VCAMGlobals.h"

BOOL vcamEnabled = NO;
BOOL vcamMirror = NO;
NSString *vcamVideoPath = @"/var/mobile/Library/Caches/vcam.mov";
NSString *vcamImagePath = @"/var/mobile/Library/Caches/vcam.jpg";
AVSampleBufferDisplayLayer *vcamPreview = nil;
UIVisualEffectView *vcamBlur = nil;
