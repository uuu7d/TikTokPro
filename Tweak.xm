#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>

@interface UIView (SaveGram)
- (void)__sg_addDownloadButton;
- (void)__sg_saveImageToPhotos:(UIImage *)image;
- (void)__sg_saveVideoToPhotos:(NSURL *)videoURL;
- (void)__sg_showHUD:(NSString *)message;
- (void)__sg_showAlertWithTitle:(NSString *)title message:(NSString *)message;
@end

@implementation UIView (SaveGram)

#pragma mark - زر التحميل ⬇️
- (void)__sg_addDownloadButton {
    // لا تضف الزر مرتين
    if ([self viewWithTag:987654]) return;

    UIButton *downloadButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [downloadButton setTitle:@"⬇️" forState:UIControlStateNormal];
    downloadButton.frame = CGRectMake(self.bounds.size.width - 45, 10, 35, 35);
    downloadButton.layer.cornerRadius = 10;
    downloadButton.clipsToBounds = YES;
    downloadButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.4];
    downloadButton.tag = 987654;
    downloadButton.tintColor = [UIColor whiteColor];
    [downloadButton addTarget:self action:@selector(__sg_handleDownloadButton) forControlEvents:UIControlEventTouchUpInside];
    downloadButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;

    [self addSubview:downloadButton];
}

#pragma mark - عند الضغط على زر التحميل
- (void)__sg_handleDownloadButton {
    // تحقق من الإصدار (iOS 14 وما فوق)
    if (@available(iOS 14.0, *)) {
        // ابحث عن صورة أو فيديو في الـ view
        UIImageView *imageView = nil;
        NSURL *videoURL = nil;

        for (UIView *sub in self.subviews) {
            if ([sub isKindOfClass:[UIImageView class]]) {
                UIImageView *img = (UIImageView *)sub;
                if (img.image) {
                    imageView = img;
                    break;
                }
            }
            if ([sub isKindOfClass:NSClassFromString(@"AVPlayerView")] ||
                [sub isKindOfClass:NSClassFromString(@"AVPlayerViewControllerContentView")]) {
                AVPlayer *player = [sub valueForKey:@"player"];
                AVAsset *asset = player.currentItem.asset;
                if ([asset isKindOfClass:[AVURLAsset class]]) {
                    videoURL = ((AVURLAsset *)asset).URL;
                    break;
                }
            }
        }

        if (imageView) {
            [self __sg_saveImageToPhotos:imageView.image];
        } else if (videoURL) {
            [self __sg_saveVideoToPhotos:videoURL];
        } else {
            [self __sg_showAlertWithTitle:@"SaveGram" message:@"❌ لا توجد وسائط للحفظ."];
        }
    } else {
        [self __sg_showAlertWithTitle:@"SaveGram" message:@"هذا النظام غير مدعوم. يتطلب iOS 14 أو أحدث."];
    }
}

#pragma mark - حفظ الصورة
- (void)__sg_saveImageToPhotos:(UIImage *)image {
    if (!image) return;
    [self __sg_showHUD:@"💾 جاري حفظ الصورة..."];

    UIImageWriteToSavedPhotosAlbum(image, self, @selector(__sg_image:didFinishSavingWithError:contextInfo:), NULL);
}

- (void)__sg_image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    NSString *msg = error ? @"❌ فشل في حفظ الصورة." : @"✅ تم حفظ الصورة بنجاح.";
    [self __sg_showHUD:msg];
}

#pragma mark - حفظ الفيديو
- (void)__sg_saveVideoToPhotos:(NSURL *)videoURL {
    if (!videoURL) {
        [self __sg_showHUD:@"❌ لم يتم العثور على الفيديو."];
        return;
    }

    [self __sg_showHUD:@"🎥 جاري حفظ الفيديو..."];

    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:videoURL];
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                [self __sg_showHUD:@"✅ تم حفظ الفيديو بنجاح!"];
            } else {
                NSString *msg = [NSString stringWithFormat:@"❌ فشل في حفظ الفيديو: %@", error.localizedDescription ?: @"غير معروف"];
                [self __sg_showAlertWithTitle:@"SaveGram" message:msg];
            }
        });
    }];
}

#pragma mark - تنبيهات و HUD
- (void)__sg_showHUD:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        UILabel *hud = [[UILabel alloc] initWithFrame:CGRectZero];
        hud.text = message;
        hud.textColor = UIColor.whiteColor;
        hud.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
        hud.textAlignment = NSTextAlignmentCenter;
        hud.font = [UIFont boldSystemFontOfSize:14];
        hud.numberOfLines = 2;
        hud.layer.cornerRadius = 10;
        hud.clipsToBounds = YES;
        hud.alpha = 0;
        hud.tag = 999999;

        CGSize textSize = [message sizeWithAttributes:@{NSFontAttributeName: hud.font}];
        CGFloat width = textSize.width + 40;
        CGFloat height = 50;
        hud.frame = CGRectMake((UIScreen.mainScreen.bounds.size.width - width)/2,
                               UIScreen.mainScreen.bounds.size.height - 150,
                               width, height);

        [[UIApplication sharedApplication].keyWindow addSubview:hud];

        [UIView animateWithDuration:0.3 animations:^{ hud.alpha = 1; } completion:^(BOOL finished) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.3 animations:^{ hud.alpha = 0; } completion:^(BOOL finished) {
                    [hud removeFromSuperview];
                }];
            });
        }];
    });
}

- (void)__sg_showAlertWithTitle:(NSString *)title message:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"موافق" style:UIAlertActionStyleDefault handler:nil]];
        UIViewController *root = UIApplication.sharedApplication.keyWindow.rootViewController;
        [root presentViewController:alert animated:YES completion:nil];
    });
}

@end

#pragma mark - Hook رئيسي مع فلترة
%hook UIView

- (void)didMoveToWindow {
    %orig;

    if (!self.window) return;

    // تجنب UISearchBar و UITextField لتفادي الكراش في مربع البحث
    if ([self isKindOfClass:[UISearchBar class]] || [self isKindOfClass:[UITextField class]]) {
        return;
    }

    // تأكد أن الـ view يحتوي على وسائط (صورة أو فيديو)
    BOOL hasMedia = NO;
    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:[UIImageView class]] ||
            [sub isKindOfClass:NSClassFromString(@"AVPlayerView")] ||
            [sub isKindOfClass:NSClassFromString(@"AVPlayerViewControllerContentView")]) {
            hasMedia = YES;
            break;
        }
    }

    if (hasMedia) {
        [self __sg_addDownloadButton];
    }
}

%end
