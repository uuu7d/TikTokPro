#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>

@interface UIView (SaveGram)
- (void)__sg_addFloatingButton;
- (void)__sg_removeFloatingButton;
- (void)__sg_handleFloatingButtonTap:(UIButton *)btn;
- (void)__sg_saveImageToPhotos:(UIImage *)image username:(NSString *)username;
- (void)__sg_saveVideoToPhotos:(NSURL *)videoURL username:(NSString *)username;
- (void)__sg_showHUD:(NSString *)message;
- (void)__sg_showAlertWithTitle:(NSString *)title message:(NSString *)message;
@end

@implementation UIView (SaveGram)

#pragma mark - إضافة الزر العائم ⬇️
- (void)__sg_addFloatingButton {
    UIWindow *window = UIApplication.sharedApplication.keyWindow;
    if (!window) return;

    // لا تضف الزر مرتين
    if ([window viewWithTag:0xFA500001]) return;

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.tag = 0xFA500001;
    [btn setTitle:@"⬇️" forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:35 weight:UIFontWeightBold];
    btn.tintColor = UIColor.whiteColor;
    btn.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    btn.layer.cornerRadius = 35 / 2;
    btn.clipsToBounds = YES;
    btn.frame = CGRectMake((UIScreen.mainScreen.bounds.size.width - 70)/2,
                           UIScreen.mainScreen.bounds.size.height - 200,
                           70, 70);
    [btn addTarget:self action:@selector(__sg_handleFloatingButtonTap:) forControlEvents:UIControlEventTouchUpInside];

    [window addSubview:btn];
}

#pragma mark - إزالة الزر بعد الحفظ
- (void)__sg_removeFloatingButton {
    UIWindow *window = UIApplication.sharedApplication.keyWindow;
    if (!window) return;
    UIView *btn = [window viewWithTag:0xFA500001];
    if (btn) {
        [UIView animateWithDuration:0.3 animations:^{
            btn.alpha = 0.0;
        } completion:^(BOOL finished) {
            [btn removeFromSuperview];
        }];
    }
}

#pragma mark - عند الضغط على الزر العائم
- (void)__sg_handleFloatingButtonTap:(UIButton *)btn {
    if (!btn || ![btn isKindOfClass:[UIButton class]]) return;

    if (@available(iOS 14.0, *)) {
        UIWindow *window = UIApplication.sharedApplication.keyWindow;
        if (!window) return;

        UIImageView *targetImageView = nil;
        NSURL *videoURL = nil;
        NSString *username = @"unknown_user";

        UIView *visibleView = window.rootViewController.view;
        if (!visibleView) return;

        // البحث عن صورة أو فيديو
        for (UIView *sub in visibleView.subviews) {
            if ([sub isKindOfClass:[UIImageView class]] && ((UIImageView *)sub).image) {
                targetImageView = (UIImageView *)sub;
                break;
            }
            if ([sub.layer isKindOfClass:[AVPlayerLayer class]]) {
                AVPlayerLayer *playerLayer = (AVPlayerLayer *)sub.layer;
                AVPlayerItem *item = playerLayer.player.currentItem;
                if (item && [item.asset isKindOfClass:[AVURLAsset class]]) {
                    videoURL = ((AVURLAsset *)item.asset).URL;
                    break;
                }
            }
        }

        // محاولة إيجاد اسم المستخدم
        for (UIView *sub in visibleView.subviews) {
            if ([sub isKindOfClass:[UILabel class]]) {
                UILabel *lbl = (UILabel *)sub;
                if (lbl.text.length > 2 && lbl.text.length < 25) {
                    username = lbl.text;
                    break;
                }
            }
        }

        if (targetImageView) {
            [self __sg_saveImageToPhotos:targetImageView.image username:username];
            [self __sg_removeFloatingButton];
        } else if (videoURL) {
            [self __sg_saveVideoToPhotos:videoURL username:username];
            [self __sg_removeFloatingButton];
        } else {
            [self __sg_showAlertWithTitle:@"SaveGram" message:@"❌ لم يتم العثور على وسائط مرئية."];
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

    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
    NSData *data = UIImageJPEGRepresentation(image, 1.0);
    [data writeToFile:path atomically:YES];

    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:[NSURL fileURLWithPath:path]];
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                [self __sg_showHUD:[NSString stringWithFormat:@"✅ تم حفظ الصورة: %@", username]];
            } else {
                [self __sg_showAlertWithTitle:@"SaveGram" message:[NSString stringWithFormat:@"❌ فشل في حفظ الصورة: %@", error.localizedDescription]];
            }
        });
    }];
}

#pragma mark - حفظ الفيديو
- (void)__sg_saveVideoToPhotos:(NSURL *)videoURL username:(NSString *)username {
    if (!videoURL) {
        [self __sg_showAlertWithTitle:@"SaveGram" message:@"❌ لم يتم العثور على الفيديو."];
        return;
    }

    [self __sg_showHUD:@"🎥 جاري حفظ الفيديو..."];

    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:videoURL];
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                [self __sg_showHUD:[NSString stringWithFormat:@"✅ تم حفظ الفيديو: %@", username]];
            } else {
                [self __sg_showAlertWithTitle:@"SaveGram" message:[NSString stringWithFormat:@"❌ فشل في حفظ الفيديو: %@", error.localizedDescription]];
            }
        });
    }];
}

#pragma mark - HUD + Alert
- (void)__sg_showHUD:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *w = UIApplication.sharedApplication.keyWindow;
        if (!w) return;

        UILabel *hud = (UILabel *)[w viewWithTag:0xFA500002];
        if (!hud) {
            hud = [[UILabel alloc] init];
            hud.tag = 0xFA500002;
            hud.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
            hud.textColor = UIColor.whiteColor;
            hud.textAlignment = NSTextAlignmentCenter;
            hud.layer.cornerRadius = 8;
            hud.clipsToBounds = YES;
            hud.numberOfLines = 2;
            hud.font = [UIFont boldSystemFontOfSize:14];
            hud.frame = CGRectMake(40, UIScreen.mainScreen.bounds.size.height - 150,
                                   UIScreen.mainScreen.bounds.size.width - 80, 50);
            [w addSubview:hud];
        }

        hud.text = message;
        hud.alpha = 1.0;
        [UIView animateWithDuration:0.3 animations:^{
            hud.alpha = 1.0;
        } completion:^(BOOL finished) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.3 animations:^{
                    hud.alpha = 0.0;
                }];
            });
        }];
    });
}

- (void)__sg_showAlertWithTitle:(NSString *)title message:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *root = UIApplication.sharedApplication.keyWindow.rootViewController;
        if (root.presentedViewController) root = root.presentedViewController;

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"موافق" style:UIAlertActionStyleDefault handler:nil]];
        [root presentViewController:alert animated:YES completion:nil];
    });
}

@end

#pragma mark - Hook رئيسي مع الإخفاء الذكي للزر
%hook UIView

- (void)didMoveToWindow {
    %orig;
    if (!self.window) return;

    // تجاهل العناصر النصية أو الأزرار أو مربعات البحث
    if ([self isKindOfClass:[UISearchBar class]] ||
        [self isKindOfClass:[UITextField class]] ||
        [self isKindOfClass:[UIButton class]]) return;

    BOOL hasMedia = NO;
    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:[UIImageView class]] ||
            [sub.layer isKindOfClass:[AVPlayerLayer class]]) {
            hasMedia = YES;
            break;
        }
    }

    if (hasMedia) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            @try {
                [self __sg_addFloatingButton];
            } @catch (NSException *e) {
                NSLog(@"[SaveGram] Exception while adding ⬇️ button: %@", e.reason);
            }
        });
    } else {
        // لو الشاشة الجديدة بدون وسائط نخفي الزر
        [self __sg_removeFloatingButton];
    }
}

%end
