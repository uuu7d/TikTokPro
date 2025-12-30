#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import "VCAMGlobals.h"

#pragma mark - Frame Source

@interface VCAMSource : NSObject
+ (CMSampleBufferRef)nextFrame:(CMSampleBufferRef)origin;
@end

@implementation VCAMSource

+ (CMSampleBufferRef)imageFrame {
    UIImage *img = [UIImage imageWithContentsOfFile:vcamImagePath];
    if (!img) return nil;

    CIImage *ci = [[CIImage alloc] initWithImage:img];

    if (vcamMirror) {
        ci = [ci imageByApplyingTransform:
              CGAffineTransformTranslate(
                  CGAffineTransformMakeScale(-1, 1),
                  -ci.extent.size.width,
                  0)];
    }

    CVPixelBufferRef pb = NULL;
    CVPixelBufferCreate(
        kCFAllocatorDefault,
        img.size.width,
        img.size.height,
        kCVPixelFormatType_32BGRA,
        NULL,
        &pb
    );

    CIContext *ctx = [CIContext context];
    [ctx render:ci toCVPixelBuffer:pb];

    CMVideoFormatDescriptionRef desc = NULL;
    CMVideoFormatDescriptionCreateForImageBuffer(
        kCFAllocatorDefault,
        pb,
        &desc
    );

    CMSampleTimingInfo timing = {
        .duration = CMTimeMake(1,30),
        .presentationTimeStamp = kCMTimeZero,
        .decodeTimeStamp = kCMTimeInvalid
    };

    CMSampleBufferRef sb = NULL;
    CMSampleBufferCreateForImageBuffer(
        kCFAllocatorDefault,
        pb,
        true,
        NULL,
        NULL,
        desc,
        &timing,
        &sb
    );

    return sb;
}

+ (CMSampleBufferRef)videoFrame:(CMSampleBufferRef)fallback {
    static AVAssetReader *reader = nil;
    static AVAssetReaderTrackOutput *output = nil;

    if (!reader) {
        AVAsset *asset =
            [AVAsset assetWithURL:[NSURL fileURLWithPath:vcamVideoPath]];
        if (!asset) return fallback;

        reader = [AVAssetReader assetReaderWithAsset:asset error:nil];
        AVAssetTrack *track = asset.tracks.firstObject;
        if (!track) return fallback;

        output = [[AVAssetReaderTrackOutput alloc]
            initWithTrack:track
            outputSettings:@{
                (id)kCVPixelBufferPixelFormatTypeKey:
                    @(kCVPixelFormatType_32BGRA)
            }];

        [reader addOutput:output];
        [reader startReading];
    }

    CMSampleBufferRef sb = [output copyNextSampleBuffer];
    if (!sb) {
        reader = nil;
        return fallback;
    }

    return sb;
}

+ (CMSampleBufferRef)nextFrame:(CMSampleBufferRef)origin {
    if ([[NSFileManager defaultManager] fileExistsAtPath:vcamImagePath]) {
        CMSampleBufferRef img = [self imageFrame];
        if (img) return img;
    }

    if ([[NSFileManager defaultManager] fileExistsAtPath:vcamVideoPath]) {
        CMSampleBufferRef vid = [self videoFrame:origin];
        if (vid) return vid;
    }

    return origin;
}

@end
