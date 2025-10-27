#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>

@interface UIView (SaveGram)
- (void)__sg_addDownloadButton;
- (void)__sg_handleDownloadButton;
- (void)__sg_saveImageToPhotos:(UIImage *)image username:(NSString *)username;
- (void)__sg_saveVideoToPhotos:(NSURL *)videoURL username:(NSString *)username;
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
    if (@available(iOS 14.0, *)) {
        UIImageView *imageView = nil;
        NSURL *videoURL = nil;
        NSString *username = @"unknown_user";

        // محاولة إيجاد اسم المستخدم (من label أو text أو placeholder)
        for (UIView *sub in self.subviews) {
            if ([sub isKindOfClass:[UILabel class]]) {
                UILabel *lbl = (UILabel *)sub;
                if (lbl.text.length > 2 && lbl.text.length < 30 && ![lbl.text containsString:@"@"] && ![lbl.text containsString:@"http"]) {
                    username = lbl.text;
                }
            }
        }

        // البحث عن صورة أو فيديو
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
                @try {
                    AVPlayer *player = [sub valueForKey:@"player"];
                    if (player.currentItem) {
                        AVAsset *asset = player.currentItem.asset;
                        if ([asset isKindOfClass:[AVURLAsset class]]) {
                            videoURL = ((AVURLAsset *)asset).URL;
                            break;
                        }
                    }
                } @catch (NSException *e) {
                    NSLog(@"[SaveGram] Exception while fetching video: %@", e.reason);
                }
            }
        }

        if (imageView) {
            [self __sg_saveImageToPhotos:imageView.image username:username];
        } else if (videoURL) {
            [self __sg_saveVideoToPhotos:videoURL username:username];
        } else {
            [self __sg_showAlertWithTitle:@"SaveGram" message:@"❌ لا توجد وسائط متاحة للحفظ."];
        }
    } else {
        [self __sg_showAlertWithTitle:@"SaveGram" message:@"⚠️ يتطلب iOS 14 أو أحدث."];
    }
}

#pragma mark - حفظ الصورة
- (void)__sg_saveImageToPhotos:(UIImage *)image username:(NSString *)username {
    if (!image) return;

    [self __sg_showHUD:@"💾 جاري حفظ الصورة..."];

    NSString *timestamp = [[NSDate date] description];
    timestamp = [timestamp stringByReplacingOccurrencesOfString:@" " withString:@"_"];
    timestamp = [timestamp stringByReplacingOccurrencesOfString:@":" withString:@"-"];
    NSString *filename = [NSString stringWithFormat:@"%@_%@.jpg", username, timestamp];

    // حفظ مؤقت إلى Documents ثم نقل إلى Photos
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
    NSData *data = UIImageJPEGRepresentation(image, 1.0);
    [data writeToFile:path atomically:YES];

    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:[NSURL fileURLWithPath:path]];
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                [self __sg_showHUD:[NSString stringWithFormat:@"✅ تم حفظ الصورة باسم %@", filename]];
            } else {
                [self __sg_showAlertWithTitle:@"SaveGram" message:[NSString stringWithFormat:@"❌ فشل في حفظ الصورة: %@", error.localizedDescription]];
            }
        });
    }];
}

#pragma mark - حفظ الفيديو
- (void)__sg_saveVideoToPhotos:(NSURL *)videoURL username:(NSString *)username {
    if (!videoURL) {
        [self __sg_showHUD:@"❌ لم يتم العثور على الفيديو."];
        return;
    }

    [self __sg_showHUD:@"🎥 جاري حفظ الفيديو..."];

    NSString *timestamp = [[NSDate date] description];
    timestamp = [timestamp stringByReplacingOccurrencesOfString:@" " withString:@"_"];
    timestamp = [timestamp stringByReplacingOccurrencesOfString:@":" withString:@"-"];
    NSString *filename = [NSString stringWithFormat:@"%@_%@.mp4", username, timestamp];

    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:videoURL];
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                [self __sg_showHUD:[NSString stringWithFormat:@"✅ تم حفظ الفيديو باسم %@", filename]];
            } else {
                NSString *msg = [NSString stringWithFormat:@"❌ فشل في حفظ الفيديو: %@", error.localizedDescription ?: @"غير معروف"];
                [self __sg_showAlertWithTitle:@"SaveGram" message:msg];
            }
        });
    }];
}

#pragma mark - واجهة المستخدم (HUD + Alerts)
- (void)__sg_showHUD:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        UILabel *hud = [[UILabel alloc] initWithFrame:CGRectZero];
        hud.text = message;
        hud.textColor = UIColor.whiteColor;
        hud.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
        hud.textAlignment = NSTextAlignmentCenter;
        hud.font = [UIFont boldSystemFontOfSize:14];
        hud.numberOfLines = 2;
        hud.layer.cornerRadius = 10;
        hud.clipsToBounds = YES;
        hud.alpha = 0;

        CGSize textSize = [message sizeWithAttributes:@{NSFontAttributeName: hud.font}];
        CGFloat width = textSize.width + 40;
        CGFloat height = 50;
        hud.frame = CGRectMake((UIScreen.mainScreen.bounds.size.width - width)/2,
                               UIScreen.mainScreen.bounds.size.height - 150,
                               width, height);

        UIWindow *keyWindow = UIApplication.sharedApplication.keyWindow;
        if (!keyWindow) return;
        [keyWindow addSubview:hud];

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
        if (root.presentedViewController) root = root.presentedViewController;
        [root presentViewController:alert animated:YES completion:nil];
    });
}

@end

#pragma mark - Hook مع حماية من الكراش
%hook UIView

- (void)didMoveToWindow {
    %orig;

    if (!self.window) return;

    // تجاهل العناصر النصية ومربع البحث لتفادي الكراش
    if ([self isKindOfClass:[UISearchBar class]] ||
        [self isKindOfClass:[UITextField class]] ||
        [self isKindOfClass:[UIButton class]]) {
        return;
    }

    // التأكد من أن الـ view يحتوي على صورة أو فيديو
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
        @try {
            [self __sg_addDownloadButton];
        } @catch (NSException *e) {
            NSLog(@"[SaveGram] Exception while adding button: %@", e.reason);
        }
    }
}

%end
