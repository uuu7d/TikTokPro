#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>  // تصحيح الاستيراد الكامل

static AVSampleBufferDisplayLayer *vcamPreview = nil;
static UIVisualEffectView *vcamBlur = nil;

%hook AVCaptureVideoPreviewLayer
- (void)didMoveToSuperlayer {
    %orig;

    if (!vcamPreview) {
        vcamPreview = [AVSampleBufferDisplayLayer new];
        vcamPreview.videoGravity = AVLayerVideoGravityResizeAspectFill;
        vcamPreview.opacity = 0.0;
        [self addSublayer:vcamPreview];

        vcamBlur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
        vcamBlur.frame = self.bounds;
        vcamBlur.alpha = 0.0;
        [self.superlayer addSublayer:vcamBlur.layer];
    }
}
%end

%hook UIWindow
- (void)didMoveToWindow {
    %orig;

    UILongPressGestureRecognizer *g =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(vcamToggle)];
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
