#import <UIKit/UIKit.h>
#import "MBProgressHUD.h"
#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>

%hook UIView

// اعتراض long press على أي UIView
- (void)addGestureRecognizer:(UIGestureRecognizer *)gesture {
    %orig;

    if ([self isKindOfClass:[UIImageView class]] || [self.layer isKindOfClass:[AVPlayerLayer class]]) {
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(__sg_handleLongPress:)];
        longPress.minimumPressDuration = 0.5;
        [self addGestureRecognizer:longPress];
        self.userInteractionEnabled = YES;
    }
}

- (void)__sg_handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;

    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    UIViewController *topVC = keyWindow.rootViewController;
    while (topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }

    // التحقق إن كانت الصورة موجودة
    UIImage *image = nil;
    NSURL *videoURL = nil;

    if ([gesture.view isKindOfClass:[UIImageView class]]) {
        image = ((UIImageView *)gesture.view).image;
    } else if ([gesture.view.layer isKindOfClass:[AVPlayerLayer class]]) {
        AVPlayerLayer *playerLayer = (AVPlayerLayer *)gesture.view.layer;
        AVPlayerItem *item = playerLayer.player.currentItem;
        if (item && [item.asset isKindOfClass:[AVURLAsset class]]) {
            videoURL = ((AVURLAsset *)item.asset).URL;
        }
    }

    if (!image && !videoURL) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"SaveGram"
                                                                   message:@"Save this media?"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if (image) {
            [self __sg_saveImageToPhotos:image];
        } else if (videoURL) {
            [self __sg_saveVideoToPhotos:videoURL];
        }
    }]];

    [topVC presentViewController:alert animated:YES completion:nil];
}

- (void)__sg_saveImageToPhotos:(UIImage *)image {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:keyWindow animated:YES];
    hud.labelText = @"Saving image...";

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetChangeRequest creationRequestForAssetFromImage:image];
        } completionHandler:^(BOOL success, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                hud.labelText = success ? @"Saved!" : @"Failed!";
                [hud hide:YES afterDelay:1.0];
            });
        }];
    });
}

- (void)__sg_saveVideoToPhotos:(NSURL *)videoURL {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:keyWindow animated:YES];
    hud.labelText = @"Saving video...";

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:videoURL];
        } completionHandler:^(BOOL success, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                hud.labelText = success ? @"Saved!" : @"Failed!";
                [hud hide:YES afterDelay:1.0];
            });
        }];
    });
}

%end
