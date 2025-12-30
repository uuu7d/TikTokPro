#import "VCAMGlobals.h"
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

%hook UIWindow

- (void)vcamToggle {
    vcamEnabled = !vcamEnabled;

    if (vcamPreview) {
        vcamPreview.opacity = vcamEnabled ? 1.0 : 0.0;
    }

    if (vcamBlur) {
        vcamBlur.alpha = vcamEnabled ? 1.0 : 0.0;
    }
}

%end

%hook AVCaptureVideoPreviewLayer

- (void)didMoveToSuperlayer {
    if (!vcamPreview) {
        vcamPreview = [AVSampleBufferDisplayLayer new];
        vcamPreview.videoGravity = AVLayerVideoGravityResizeAspectFill;
    }

    if (!vcamBlur) {
        UIVisualEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        vcamBlur = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        vcamBlur.frame = self.bounds;
        [self.superlayer addSublayer:vcamBlur.layer];
    }
}

%end
