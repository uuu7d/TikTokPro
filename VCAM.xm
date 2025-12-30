#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#pragma mark - Globals

static BOOL vcamEnabled = NO;
static BOOL vcamMirror = NO;

static NSString *vcamVideoPath = @"/var/mobile/Library/Caches/vcam.mov";
static NSString *vcamImagePath = @"/var/mobile/Library/Caches/vcam.jpg";

static AVSampleBufferDisplayLayer *vcamPreview = nil;
static UIVisualEffectView *vcamBlur = nil;

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
    CVReturn status = CVPixelBufferCreate(
        kCFAllocatorDefault,
        img.size.width,
        img.size.height,
        kCVPixelFormatType_32BGRA,
        NULL,
        &pb
    );
    if (status != kCVReturnSuccess) return nil;

    CIContext *ctx = [CIContext context];
    [ctx render:ci toCVPixelBuffer:pb];

    CMVideoFormatDescriptionRef desc = NULL;
    CMVideoFormatDescriptionCreateForImageBuffer(
        kCFAllocatorDefault,
        pb,
        &desc
    );

    CMSampleTimingInfo timing = {CMTimeMake(1,30), kCMTimeZero, kCMTimeInvalid};
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

    CFRelease(pb);
    CFRelease(desc);

    return sb;
}

+ (CMSampleBufferRef)videoFrame:(CMSampleBufferRef)fallback {
    static AVAssetReader *reader = nil;
    static AVAssetReaderTrackOutput *output = nil;

    if (!reader) {
        AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:vcamVideoPath]];
        if (!asset) return fallback;

        reader = [AVAssetReader assetReaderWithAsset:asset error:nil];
        AVAssetTrack *track = asset.tracks.firstObject;
        if (!track) return fallback;

        output = [[AVAssetReaderTrackOutput alloc] initWithTrack:track
            outputSettings:@{(id)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_32BGRA)}];

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

#pragma mark - Stream Injection

%hook AVCaptureVideoDataOutput
- (void)setSampleBufferDelegate:(id)delegate queue:(dispatch_queue_t)queue {
    %orig;

    SEL sel = @selector(captureOutput:didOutputSampleBuffer:fromConnection:);
    Method m = class_getInstanceMethod([delegate class], sel);
    if (!m) return;

    IMP origIMP = method_getImplementation(m);

    method_setImplementation(
        m,
        imp_implementationWithBlock(^(
            id self,
            AVCaptureOutput *out,
            CMSampleBufferRef sb,
            AVCaptureConnection *conn
        ) {
            if (vcamEnabled) {
                CMSampleBufferRef fake = [VCAMSource nextFrame:sb];
                if (fake) {
                    ((void(*)(id,SEL,id,CMSampleBufferRef,id))
                        origIMP)(self, sel, out, fake, conn);
                    CFRelease(fake);
                    return;
                }
            }

            ((void(*)(id,SEL,id,CMSampleBufferRef,id))
                origIMP)(self, sel, out, sb, conn);
        })
    );
}
%end

#pragma mark - Auto Mirror

%hook AVCaptureDeviceInput
- (instancetype)initWithDevice:(AVCaptureDevice *)device
                         error:(NSError **)error {
    vcamMirror = (device.position == AVCaptureDevicePositionFront);
    return %orig;
}
%end

#pragma mark - Preview + Blur

%hook AVCaptureVideoPreviewLayer
- (void)didMoveToSuperlayer {
    %orig;

    if (!vcamPreview) {
        vcamPreview = [AVSampleBufferDisplayLayer new];
        vcamPreview.videoGravity = AVLayerVideoGravityResizeAspectFill;
        vcamPreview.opacity = 0.0;
        vcamPreview.frame = self.bounds;
        [self addSublayer:vcamPreview];

        vcamBlur = [[UIVisualEffectView alloc]
            initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
        vcamBlur.frame = self.bounds;
        vcamBlur.alpha = 0.0;
        [self.superlayer addSublayer:vcamBlur.layer];
    } else {
        vcamPreview.frame = self.bounds;
        vcamBlur.frame = self.bounds;
    }
}
%end

#pragma mark - Gesture Control

%hook UIWindow
- (void)didMoveToWindow {
    %orig;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UILongPressGestureRecognizer *g = [[UILongPressGestureRecognizer alloc]
            initWithTarget:self action:@selector(vcamToggle)];
        g.minimumPressDuration = 5.0;
        [self addGestureRecognizer:g];
    });
}
%new
- (void)vcamToggle {
    vcamEnabled = !vcamEnabled;
    vcamPreview.opacity = vcamEnabled ? 1.0 : 0.0;
    vcamBlur.alpha = vcamEnabled ? 1.0 : 0.0;
}
%end
