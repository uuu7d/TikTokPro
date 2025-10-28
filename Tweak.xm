#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>

@interface FileSaverButton : UIButton
@end

@implementation FileSaverButton
@end

static FileSaverButton *floatingButton;

%hook UIView

- (void)didMoveToWindow {
    %orig;

    if (!floatingButton && self.window) {
        floatingButton = [FileSaverButton buttonWithType:UIButtonTypeCustom];
        [floatingButton setTitle:@"📥" forState:UIControlStateNormal];
        floatingButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];
        floatingButton.layer.cornerRadius = 30;
        floatingButton.frame = CGRectMake(UIScreen.mainScreen.bounds.size.width - 80,
                                          UIScreen.mainScreen.bounds.size.height / 2 - 30,
                                          60, 60);
        floatingButton.layer.zPosition = FLT_MAX;
        [floatingButton addTarget:self action:@selector(saveVisibleMedia) forControlEvents:UIControlEventTouchUpInside];

        [[UIApplication sharedApplication].keyWindow addSubview:floatingButton];
        floatingButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    }
}

%new
- (void)saveVisibleMedia {
    UIView *topView = [UIApplication sharedApplication].keyWindow.rootViewController.view;
    NSURL *videoURL = [self findVideoURLInView:topView];
    UIImage *image = [self findImageInView:topView];

    if (videoURL) {
        [self saveVideoFromURL:videoURL];
    } else if (image) {
        [self saveImage:image];
    } else {
        [self showAlert:@"لم يتم العثور على صورة أو فيديو"];
    }
}

%new
- (UIImage *)findImageInView:(UIView *)view {
    if ([view isKindOfClass:[UIImageView class]]) {
        UIImageView *iv = (UIImageView *)view;
        if (iv.image) return iv.image;
    }
    for (UIView *subview in view.subviews) {
        UIImage *found = [self findImageInView:subview];
        if (found) return found;
    }
    return nil;
}

%new
- (NSURL *)findVideoURLInView:(UIView *)view {
    if ([view.layer isKindOfClass:[AVPlayerLayer class]]) {
        AVPlayerLayer *layer = (AVPlayerLayer *)view.layer;
        AVPlayerItem *item = layer.player.currentItem;
        if ([item.asset isKindOfClass:[AVURLAsset class]]) {
            return [(AVURLAsset *)item.asset URL];
        }
    }
    for (UIView *sub in view.subviews) {
        NSURL *found = [self findVideoURLInView:sub];
        if (found) return found;
    }
    return nil;
}

%new
- (void)saveImage:(UIImage *)image {
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromImage:image];
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showAlert:success ? @"تم حفظ الصورة بنجاح ✅" : @"فشل حفظ الصورة ❌"];
        });
    }];
}

%new
- (void)saveVideoFromURL:(NSURL *)url {
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:url];
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showAlert:success ? @"تم حفظ الفيديو بنجاح ✅" : @"فشل حفظ الفيديو ❌"];
        });
    }];
}

%new
- (void)showAlert:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"FileSaver"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"تم" style:UIAlertActionStyleDefault handler:nil]];
    [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
}

%end
