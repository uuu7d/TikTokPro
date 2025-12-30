#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>

@interface VCAMSource : NSObject
+ (CMSampleBufferRef)nextFrame:(CMSampleBufferRef)origin;
@end
