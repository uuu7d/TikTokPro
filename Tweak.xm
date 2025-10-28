// Tweak.xm
#pragma clang diagnostic ignored "-Wunused-variable"
#pragma clang diagnostic ignored "-Wunused-but-set-variable"

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <objc/runtime.h>

@interface FloatingDownloadButton : UIButton
+ (instancetype)sharedButton;
- (void)show;
- (void)hide;
@end

@implementation FloatingDownloadButton

+ (instancetype)sharedButton {
    static FloatingDownloadButton *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [FloatingDownloadButton buttonWithType:UIButtonTypeCustom];
        shared.frame = CGRectMake(UIScreen.mainScreen.bounds.size.width - 70,
                                  UIScreen.mainScreen.bounds.size.height/2 - 25,
                                  50, 50);
        shared.layer.cornerRadius = 25;
        shared.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];
        [shared setTitle:@"📥" forState:UIControlStateNormal];
        [shared addTarget:shared action:@selector(downloadContent)
          forControlEvents:UIControlEventTouchUpInside];
        shared.hidden = YES;
        [[NSNotificationCenter defaultCenter] addObserver:shared
                                                 selector:@selector(checkVisibleContent)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
    });
    return shared;
}

- (void)show {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.hidden = NO;
        UIWindow *window = UIApplication.sharedApplication.keyWindow ?: UIApplication.sharedApplication.windows.firstObject;
        if (self.superview != window) [window addSubview:self];
    });
}

- (void)hide {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.hidden = YES;
    });
}

- (void)checkVisibleContent {
    UIViewController *topVC = UIApplication.sharedApplication.keyWindow.rootViewController;
    if (!topVC) return;

    BOOL foundMedia = [self findMediaInView:topVC.view];
    if (foundMedia) [self show];
    else [self hide];
}

- (BOOL)findMediaInView:(UIView *)view {
    for (UIView *sub in view.subviews) {
        if ([sub isKindOfClass:[UIImageView class]]) return YES;
        if ([sub.layer isKindOfClass:[AVPlayerLayer class]]) return YES;
        if ([self findMediaInView:sub]) return YES;
    }
    return NO;
}

- (void)downloadContent {
    UIViewController *rootVC = UIApplication.sharedApplication.keyWindow.rootViewController;
    UIImage *foundImage = [self findImageInView:rootVC.view];
    AVPlayerItem *foundVideo = [self findVideoInView:rootVC.view];

    if (foundImage) {
        [self saveImage:foundImage];
    } else if (foundVideo) {
        NSURL *url = ((AVURLAsset *)foundVideo.asset).URL;
        [self downloadVideoFromURL:url];
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"⚠️"
                                                                       message:@"لم يتم العثور على محتوى قابل للتحميل"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"حسنًا" style:UIAlertActionStyleCancel handler:nil]];
        [rootVC presentViewController:alert animated:YES completion:nil];
    }
}

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

- (AVPlayerItem *)findVideoInView:(UIView *)view {
    for (CALayer *layer in view.layer.sublayers) {
        if ([layer isKindOfClass:[AVPlayerLayer class]]) {
            AVPlayerLayer *playerLayer = (AVPlayerLayer *)layer;
            return playerLayer.player.currentItem;
        }
    }
    for (UIView *sub in view.subviews) {
        AVPlayerItem *item = [self findVideoInView:sub];
        if (item) return item;
    }
    return nil;
}

- (void)saveImage:(UIImage *)image {
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromImage:image];
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        NSLog(@"📸 Image saved: %@", success ? @"YES" : @"NO");
    }];
}

- (void)downloadVideoFromURL:(NSURL *)url {
    if (!url) return;
    NSData *videoData = [NSData dataWithContentsOfURL:url];
    if (!videoData) return;
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"downloaded.mov"];
    [videoData writeToFile:tempPath atomically:YES];
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:[NSURL fileURLWithPath:tempPath]];
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        NSLog(@"🎬 Video saved: %@", success ? @"YES" : @"NO");
    }];
}

@end

%ctor {
    [[FloatingDownloadButton sharedButton] checkVisibleContent];
}
