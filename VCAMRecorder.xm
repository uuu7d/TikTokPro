#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

extern BOOL vcamMirror;
extern BOOL vcamEnabled;
@class VCAMSource;

%hook AVCaptureVideoDataOutput
- (void)setSampleBufferDelegate:(id)delegate queue:(dispatch_queue_t)queue {
    %orig;

    static BOOL vcamHooked = NO;
    if (vcamHooked) return;
    vcamHooked = YES;

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
                    ((void(*)(id,SEL,id,CMSampleBufferRef,id)) origIMP)(self, sel, out, fake, conn);
                    return;
                }
            }
            ((void(*)(id,SEL,id,CMSampleBufferRef,id)) origIMP)(self, sel, out, sb, conn);
        })
    );
}
%end

%hook AVCaptureDeviceInput
- (instancetype)initWithDevice:(AVCaptureDevice *)device
                         error:(NSError **)error {
    vcamMirror = (device.position == AVCaptureDevicePositionFront);
    return %orig;
}
%end
