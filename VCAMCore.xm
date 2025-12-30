#import "VCAMGlobals.h"
#import <AVFoundation/AVFoundation.h>

@interface VCAMSource : NSObject
+ (CMSampleBufferRef)nextFrame:(CMSampleBufferRef)sb;
+ (CMSampleBufferRef)videoFrame:(CMSampleBufferRef)sb;
+ (CMSampleBufferRef)imageFrame;
@end

@implementation VCAMSource

+ (CMSampleBufferRef)nextFrame:(CMSampleBufferRef)sb {
    if (vcamVideoPath) {
        return [self videoFrame:sb];
    } else if (vcamImagePath) {
        return [self imageFrame];
    }
    return sb;
}

+ (CMSampleBufferRef)videoFrame:(CMSampleBufferRef)sb {
    // هنا يتم جلب إطار من الفيديو الوهمي
    return sb;
}

+ (CMSampleBufferRef)imageFrame {
    // هنا يتم جلب صورة ثابتة كمصدر وهمي
    return nil;
}

@end
