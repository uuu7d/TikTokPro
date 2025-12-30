#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - Defaults & Globals

static BOOL vcamMirror = NO;
static CIContext *vcamCIContext = nil;

#define kVCAMVideoPath @"/var/mobile/Library/Caches/vcam.mov"
#define kVCAMImagePath @"/var/mobile/Library/Caches/vcam.jpg"

@interface VCAMSource : NSObject
+ (CMSampleBufferRef)nextFrame:(CMSampleBufferRef)origin;
@end

@implementation VCAMSource

+ (CMSampleBufferRef)imageFrame {
    UIImage *img = [UIImage imageWithContentsOfFile:kVCAMImagePath];
    if (!img) return nil;

    CIImage *ci = [[CIImage alloc] initWithImage:img];
    if (vcamMirror) {
        ci = [ci imageByApplyingTransform:
              CGAffineTransformTranslate(
                  CGAffineTransformMakeScale(-1, 1),
                  -ci.extent.size.width, 0)];
    }

    CVPixelBufferRef pb = NULL;
    CVPixelBufferCreate(kCFAllocatorDefault, img.size.width, img.size.height,
                        kCVPixelFormatType_32BGRA, NULL, &pb);

    if (!vcamCIContext) vcamCIContext = [CIContext contextWithOptions:nil];
    [vcamCIContext render:ci toCVPixelBuffer:pb];

    CMVideoFormatDescriptionRef desc = NULL;
    CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pb, &desc);

    CMSampleTimingInfo timing = {CMTimeMake(1, 30), kCMTimeZero, kCMTimeInvalid};
    CMSampleBufferRef sb = NULL;
    CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pb, true, NULL, NULL, desc, &timing, &sb);

    return sb;
}

+ (CMSampleBufferRef)videoFrame:(CMSampleBufferRef)fallback {
    static AVAssetReader *reader = nil;
    static AVAssetReaderTrackOutput *output = nil;

    if (!reader) {
        AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:kVCAMVideoPath]];
        if (!asset) return fallback;

        reader = [AVAssetReader assetReaderWithAsset:asset error:nil];
        AVAssetTrack *track = asset.tracks.firstObject;
        if (!track) return fallback;

        output = [[AVAssetReaderTrackOutput alloc]
                  initWithTrack:track
                  outputSettings:@{(id)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_32BGRA)}];
        output.alwaysCopiesSampleData = NO;
        [reader addOutput:output];
        [reader startReading];
    }

    CMSampleBufferRef sb = [output copyNextSampleBuffer];
    if (!sb) {
        reader = nil;
        output = nil;
        return fallback;
    }
    return sb;
}

+ (CMSampleBufferRef)nextFrame:(CMSampleBufferRef)origin {
    if ([[NSFileManager defaultManager] fileExistsAtPath:kVCAMImagePath]) {
        CMSampleBufferRef img = [self imageFrame];
        if (img) return img;
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:kVCAMVideoPath]) {
        CMSampleBufferRef vid = [self videoFrame:origin];
        if (vid) return vid;
    }
    return origin;
}

@end
