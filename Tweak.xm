// Tweak.xm
#pragma clang diagnostic ignored "-Wunused-variable"
#pragma clang diagnostic ignored "-Wunused-but-set-variable"

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <objc/runtime.h>

@interface ScreenSaverManager : NSObject
+ (instancetype)shared;
- (void)setupGesture;
@end

@implementation ScreenSaverManager

+ (instancetype)shared {
    static ScreenSaverManager *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[ScreenSaverManager alloc] init];
    });
    return shared;
}

- (void)setupGesture {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = UIApplication.sharedApplication.keyWindow ?: UIApplication.sharedApplication.windows.firstObject;
        if (!window) return;

        for (UIGestureRecognizer *g in window.gestureRecognizers) {
            if ([g isKindOfClass:[UITapGestureRecognizer class]] &&
                ((UITapGestureRecognizer *)g).numberOfTouchesRequired == 2)
                return; // gesture already exists
        }

        UITapGestureRecognizer *twoFingerTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleFingerTap:)];
        twoFingerTap.numberOfTouchesRequired = 2;
        twoFingerTap.numberOfTapsRequired = 1;
        [window addGestureRecognizer:twoFingerTap];

        NSLog(@"📲 [SaveTweak] Two-finger tap gesture initialized.");
    });
}

- (void)handleDoubleFingerTap:(UITapGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateRecognized) return;

    UIViewController *rootVC = UIApplication.sharedApplication.keyWindow.rootViewController;
    if (!rootVC) return;

    NSLog(@"👆 [SaveTweak] Double-finger tap detected. Searching for media...");

    UIImage *foundImage = [self findImageInView:rootVC.view];
    if (foundImage) {
        [self saveImage:foundImage];
        return;
    }

    NSURL *videoURL = [self findVideoURLInView:rootVC.view];
    if (videoURL) {
        [self downloadVideoFromURL:videoURL];
        return;
    }

    [self showToast:@"⚠️ لم يتم العثور على محتوى قابل للحفظ" success:NO];
}

#pragma mark - MEDIA DETECTION

- (UIImage *)findImageInView:(UIView *)view {
    if ([view isKindOfClass:[UIImageView class]]) {
        UIImageView *imgView = (UIImageView *)view;
        if (imgView.image) return imgView.image;
    }
    for (UIView *sub in view.subviews) {
        UIImage *img = [self findImageInView:sub];
        if (img) return img;
    }
    return nil;
}

- (NSURL *)findVideoURLInView:(UIView *)view {
    // ✅ أولاً نحاول عبر AVPlayerLayer
    for (CALayer *layer in view.layer.sublayers) {
        if ([layer isKindOfClass:[AVPlayerLayer class]]) {
            AVPlayerLayer *playerLayer = (AVPlayerLayer *)layer;
            NSURL *url = [self extractURLFromPlayer:playerLayer.player];
            if (url) return url;
        }
    }

    // ✅ بعدها نحاول مع الواجهات الخاصة مثل StoryVideo
    NSString *className = NSStringFromClass([view class]);
    if ([className containsString:@"Story"] ||
        [className containsString:@"Video"] ||
        [className containsString:@"Player"]) {

        id player = nil;
        @try { player = [view valueForKey:@"player"]; } @catch (...) {}
        if (player && [player isKindOfClass:[AVPlayer class]]) {
            NSURL *url = [self extractURLFromPlayer:(AVPlayer *)player];
            if (url) return url;
        }

        NSArray *possibleKeys = @[@"_URL", @"URL", @"currentURL", @"streamURL", @"videoURL"];
        for (NSString *key in possibleKeys) {
            if ([view respondsToSelector:NSSelectorFromString(key)]) {
                id value = nil;
                @try { value = [view valueForKey:key]; } @catch (...) {}
                if ([value isKindOfClass:[NSURL class]]) return value;
                if ([value isKindOfClass:[NSString class]]) return [NSURL URLWithString:value];
            }
        }
    }

    // ✅ البحث داخل الـ subviews
    for (UIView *sub in view.subviews) {
        NSURL *url = [self findVideoURLInView:sub];
        if (url) return url;
    }
    return nil;
}

- (NSURL *)extractURLFromPlayer:(AVPlayer *)player {
    if (!player) return nil;
    AVPlayerItem *item = player.currentItem;
    if (!item) return nil;

    if ([item.asset isKindOfClass:[AVURLAsset class]]) {
        return ((AVURLAsset *)item.asset).URL;
    }

    NSArray *keys = @[@"asset", @"_asset", @"URL", @"_URL"];
    for (NSString *key in keys) {
        id value = nil;
        @try { value = [item valueForKey:key]; } @catch (...) {}
        if ([value isKindOfClass:[NSURL class]]) return value;
        if ([value isKindOfClass:[NSString class]]) return [NSURL URLWithString:value];
    }
    return nil;
}

#pragma mark - SAVE MEDIA

- (void)saveImage:(UIImage *)image {
    NSLog(@"📸 [SaveTweak] Saving image...");
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromImage:image];
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success)
                [self showToast:@"✅ تم حفظ الصورة في الألبوم" success:YES];
            else
                [self showToast:[NSString stringWithFormat:@"❌ فشل حفظ الصورة: %@", error.localizedDescription] success:NO];
        });
    }];
}

- (void)downloadVideoFromURL:(NSURL *)url {
    if (!url) return;
    NSLog(@"🎬 [SaveTweak] Downloading video from %@", url.absoluteString);
    NSData *data = [NSData dataWithContentsOfURL:url];
    if (!data) {
        [self showToast:@"⚠️ لم يتمكن من تحميل الفيديو" success:NO];
        return;
    }

    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"saved_video.mov"];
    [data writeToFile:path atomically:YES];
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:[NSURL fileURLWithPath:path]];
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success)
                [self showToast:@"🎥 تم حفظ الفيديو بنجاح" success:YES];
            else
                [self showToast:[NSString stringWithFormat:@"❌ خطأ في حفظ الفيديو: %@", error.localizedDescription] success:NO];
        });
    }];
}

#pragma mark - TOAST MESSAGE

- (void)showToast:(NSString *)message success:(BOOL)success {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = UIApplication.sharedApplication.keyWindow ?: UIApplication.sharedApplication.windows.firstObject;
        if (!window) return;

        UILabel *toast = [[UILabel alloc] initWithFrame:CGRectZero];
        toast.text = message;
        toast.textColor = [UIColor whiteColor];
        toast.backgroundColor = success ? [[UIColor systemGreenColor] colorWithAlphaComponent:0.85]
                                        : [[UIColor blackColor] colorWithAlphaComponent:0.75];
        toast.textAlignment = NSTextAlignmentCenter;
        toast.numberOfLines = 2;
        toast.layer.cornerRadius = 10;
        toast.clipsToBounds = YES;
        toast.font = [UIFont boldSystemFontOfSize:15];

        CGFloat width = window.bounds.size.width * 0.8;
        toast.frame = CGRectMake((window.bounds.size.width - width)/2,
                                 window.bounds.size.height - 120,
                                 width, 50);

        [window addSubview:toast];

        [UIView animateWithDuration:0.5 delay:2.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
            toast.alpha = 0;
        } completion:^(BOOL finished) {
            [toast removeFromSuperview];
        }];
    });
}

@end

%ctor {
    [[ScreenSaverManager shared] setupGesture];
}
