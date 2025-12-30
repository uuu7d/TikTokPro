#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import "VCAMGlobals.h"

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
        vcamPreview.videoGravity = kCAGravityResizeAspectFill;
        vcamPreview.opacity = 0.0;
        [self addSublayer:vcamPreview];

        vcamBlur = [[UIVisualEffectView alloc]
            initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
        vcamBlur.frame = self.bounds;
        vcamBlur.alpha = 0.0;
        [self.superlayer addSublayer:vcamBlur.layer];
    }
}
%end

#pragma mark - Gesture Control
%hook UIWindow
- (void)didMoveToWindow {
    %orig;

    UILongPressGestureRecognizer *g =
        [[UILongPressGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(vcamToggle)];
    g.minimumPressDuration = 5.0;
    [self addGestureRecognizer:g];
}
%new
- (void)vcamToggle {
    vcamEnabled = !vcamEnabled;
    vcamPreview.opacity = vcamEnabled ? 1.0 : 0.0;
    vcamBlur.alpha = vcamEnabled ? 1.0 : 0.0;
}
%end
