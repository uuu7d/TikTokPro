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
                return;
        }

        UITapGestureRecognizer *twoFingerTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleFingerTap:)];
        twoFingerTap.numberOfTouchesRequired = 2;
        twoFingerTap.numberOfTapsRequired = 1;
        [window addGestureRecognizer:twoFingerTap];

        NSLog(@"📲 [SaveTweak] Two-finger gesture added.");
    });
}

- (void)handleDoubleFingerTap:(UITapGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateRecognized) return;

    UIViewController *rootVC = UIApplication.sharedApplication.keyWindow.rootViewController;
    if (!rootVC) return;

    NSLog(@"👆 [SaveTweak] Two-finger tap detected. Scanning...");

    UIImage *foundImage = [self findImageInView:rootVC.view];
    if (foundImage) {
        [self saveImage:foundImage];
        return;
    }

    NSURL *videoURL = [self deepFindVideoURLInView:rootVC.view];
    if (videoURL) {
        NSLog(@"🎬 [SaveTweak] Found video URL: %@", videoURL);
        [self downloadVideoFromURL:videoURL];
        return;
    }

    [self showToast:@"⚠️ لم يتم العثور على فيديو للحفظ" success:NO];
}

#pragma mark - FIND IMAGE

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

#pragma mark - FIND VIDEO (Deep Search)

- (NSURL *)deepFindVideoURLInView:(UIView *)view {
    NSString *className = NSStringFromClass([view class]);

    // Try AVPlayerLayer first
    for (CALayer *layer in view.layer.sublayers) {
        if ([layer isKindOfClass:[AVPlayerLayer class]]) {
            AVPlayerLayer *playerLayer = (AVPlayerLayer *)layer;
            NSURL *url = [self extractDeepURLFromPlayer:playerLayer.player];
            if (url) return url;
        }
    }

    // Try Story/Video/Player classes
    if ([className containsString:@"Story"] ||
        [className containsString:@"Video"] ||
        [className containsString:@"Player"]) {

        // Try direct keys on the view itself
        NSArray *keys = @[@"player", @"videoPlayer", @"_player", @"avPlayer", @"moviePlayer"];
        for (NSString *key in keys) {
            if ([view respondsToSelector:NSSelectorFromString(key)]) {
                id player = nil;
                @try { player = [view valueForKey:key]; } @catch (...) {}
                if (player && [player isKindOfClass:[AVPlayer class]]) {
                    NSURL *url = [self extractDeepURLFromPlayer:(AVPlayer *)player];
                    if (url) return url;
                }
            }
        }

        // Try known URL-like keys
        NSArray *urlKeys = @[@"_URL", @"URL", @"currentURL", @"streamURL", @"videoURL", @"_videoURL"];
        for (NSString *key in urlKeys) {
            id value = nil;
            @try { value = [view valueForKey:key]; } @catch (...) {}
            if ([value isKindOfClass:[NSURL class]]) return value;
            if ([value isKindOfClass:[NSString class]]) return [NSURL URLWithString:value];
        }
    }

    // Search recursively
    for (UIView *sub in view.subviews) {
        NSURL *url = [self deepFindVideoURLInView:sub];
        if (url) return url;
    }
    return nil;
}

- (NSURL *)extractDeepURLFromPlayer:(AVPlayer *)player {
    if (!player) return nil;

    AVPlayerItem *item = player.currentItem;
    if (!item) return nil;

    // Try direct AVURLAsset
    if ([item.asset isKindOfClass:[AVURLAsset class]]) {
        AVURLAsset *avAsset = (AVURLAsset *)item.asset;
        if (avAsset.URL) return avAsset.URL;
    }

    // Try reflection on item
    NSArray *keys = @[@"asset", @"_asset", @"URL", @"_URL", @"streamURL", @"currentURL"];
    for (NSString *key in keys) {
        id val = nil;
        @try { val = [item valueForKey:key]; } @catch (...) {}
        if ([val isKindOfClass:[NSURL class]]) return val;
        if ([val isKindOfClass:[NSString class]]) return [NSURL URLWithString:val];
    }

    // Try reflection on player
    NSArray *playerKeys = @[@"currentURL", @"streamURL", @"_URL"];
    for (NSString *key in playerKeys) {
        id val = nil;
        @try { val = [player valueForKey:key]; } @catch (...) {}
        if ([val isKindOfClass:[NSURL class]]) return val;
        if ([val isKindOfClass:[NSString class]]) return [NSURL URLWithString:val];
    }

    return nil;
}

#pragma mark - SAVE

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

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSData *data = [NSData dataWithContentsOfURL:url];
        if (!data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showToast:@"⚠️ لم يتمكن من تحميل الفيديو" success:NO];
            });
            return;
        }

        NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"saved_story.mov"];
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
    });
}

#pragma mark - TOAST

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
