#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>

#pragma mark - Category Declaration

@interface UIView (SaveGram)
- (void)__sg_addDownloadButton;
- (void)__sg_downloadMedia;
- (void)__sg_saveImageToPhotos:(UIImage *)image;
- (void)__sg_saveVideoToPhotos:(NSURL *)videoURL;
- (void)__sg_showHUD:(NSString *)message;
- (void)__sg_showAlertWithTitle:(NSString *)title message:(NSString *)message;
@end


#pragma mark - Hook UIView

%hook UIView

- (void)didMoveToWindow {
    %orig;

    // ✅ تحقق من إصدار iOS قبل إضافة الزر
    if (@available(iOS 13.0, *)) {
        if ([self isKindOfClass:[UIImageView class]] || [self.layer isKindOfClass:[AVPlayerLayer class]]) {
            [self __sg_addDownloadButton];
        }
    }
}

%new
- (void)__sg_addDownloadButton {
    if ([self viewWithTag:99999]) return; // لا تكرر الزر

    UIButton *downloadButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [downloadButton setTitle:@"⬇️" forState:UIControlStateNormal];
    downloadButton.frame = CGRectMake(self.bounds.size.width - 40, 5, 35, 35);
    downloadButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
    downloadButton.tag = 99999;

    downloadButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    [downloadButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    downloadButton.layer.cornerRadius = 8;
    downloadButton.clipsToBounds = YES;

    [downloadButton addTarget:self action:@selector(__sg_downloadMedia) forControlEvents:UIControlEventTouchUpInside];

    [self addSubview:downloadButton];
    self.userInteractionEnabled = YES;
}

%new
- (void)__sg_downloadMedia {
    UIImage *image = nil;
    NSURL *videoURL = nil;

    if ([self isKindOfClass:[UIImageView class]]) {
        image = ((UIImageView *)self).image;
    } else if ([self.layer isKindOfClass:[AVPlayerLayer class]]) {
        AVPlayerLayer *playerLayer = (AVPlayerLayer *)self.layer;
        AVPlayerItem *item = playerLayer.player.currentItem;
        if (item && [item.asset isKindOfClass:[AVURLAsset class]]) {
            videoURL = ((AVURLAsset *)item.asset).URL;
        }
    }

    if (!image && !videoURL) {
        [self __sg_showAlertWithTitle:@"SaveGram" message:@"No media detected."];
        return;
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"SaveGram"
                                                                   message:@"Save this media to Photos?"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if (image) {
            [self __sg_saveImageToPhotos:image];
        } else if (videoURL) {
            [self __sg_saveVideoToPhotos:videoURL];
        }
    }]];

    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    UIViewController *topVC = keyWindow.rootViewController;
    while (topVC.presentedViewController) topVC = topVC.presentedViewController;
    [topVC presentViewController:alert animated:YES completion:nil];
}

%new
- (void)__sg_saveImageToPhotos:(UIImage *)image {
    [self __sg_showHUD:@"Saving image..."];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetChangeRequest creationRequestForAssetFromImage:image];
        } completionHandler:^(BOOL success, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self __sg_showHUD:(success ? @"✅ Image Saved!" : @"❌ Failed to save image.")];
            });
        }];
    });
}

%new
- (void)__sg_saveVideoToPhotos:(NSURL *)videoURL {
    [self __sg_showHUD:@"Saving video..."];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:videoURL];
        } completionHandler:^(BOOL success, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self __sg_showHUD:(success ? @"✅ Video Saved!" : @"❌ Failed to save video.")];
NSLog(@"[SaveGram] videoURL: %@", videoURL);
NSLog(@"[SaveGram] isFileURL: %d", [videoURL isFileURL]);
            });
        }];
    });
}

%new
- (void)__sg_showHUD:(NSString *)message {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    UILabel *hud = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, 40)];
    hud.center = keyWindow.center;
    hud.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
    hud.textColor = [UIColor whiteColor];
    hud.textAlignment = NSTextAlignmentCenter;
    hud.text = message;
    hud.layer.cornerRadius = 10;
    hud.clipsToBounds = YES;

    [keyWindow addSubview:hud];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [hud removeFromSuperview];
    });
}

%new
- (void)__sg_showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];

    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    UIViewController *topVC = keyWindow.rootViewController;
    while (topVC.presentedViewController) topVC = topVC.presentedViewController;
    [topVC presentViewController:alert animated:YES completion:nil];
}

%end
