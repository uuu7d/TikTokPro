#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

static AVSampleBufferDisplayLayer *vcamPreview = nil;
static UIVisualEffectView *vcamBlur = nil;

#define kVCAMBadgeX @"vcam_badge_x"
#define kVCAMBadgeY @"vcam_badge_y"

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
    extern BOOL vcamEnabled;
    vcamEnabled = !vcamEnabled;

    if (!vcamEnabled) return;

    static UIButton *vcamBadge = nil;
    if (!vcamBadge) {
        vcamBadge = [UIButton buttonWithType:UIButtonTypeCustom];
        [vcamBadge setTitle:@"📸" forState:UIControlStateNormal];
        [vcamBadge setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        vcamBadge.frame = CGRectMake(
            [[NSUserDefaults standardUserDefaults] floatForKey:kVCAMBadgeX] ?: 20,
            [[NSUserDefaults standardUserDefaults] floatForKey:kVCAMBadgeY] ?: 120,
            44,44
        );
        vcamBadge.layer.zPosition = 1000;
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:nil action:@selector(vcamBadgeDrag:)];
        [vcamBadge addGestureRecognizer:pan];
        [self addSubview:vcamBadge];
    }

    vcamPreview.opacity = 1.0;
    vcamBlur.alpha = 1.0;
}

%new
- (void)vcamBadgeDrag:(UIPanGestureRecognizer *)g {
    UIView *v = g.view;
    CGPoint t = [g translationInView:v.superview];
    v.center = CGPointMake(v.center.x + t.x, v.center.y + t.y);
    [g setTranslation:CGPointZero inView:v.superview];

    if (g.state == UIGestureRecognizerStateEnded) {
        [[NSUserDefaults standardUserDefaults] setFloat:v.frame.origin.x forKey:kVCAMBadgeX];
        [[NSUserDefaults standardUserDefaults] setFloat:v.frame.origin.y forKey:kVCAMBadgeY];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}
%end
