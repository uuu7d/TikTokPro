#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>

@interface UIView (SaveGram)
- (void)__sg_addFloatingButton;
- (void)__sg_handleFloatingButtonTap:(UIButton *)btn;
@end

@implementation UIView (SaveGram)

// إنشاء زر التحميل إن لم يكن موجود
- (UIButton *)__sg_floatingButton {
    UIWindow *window = UIApplication.sharedApplication.keyWindow;
    return (UIButton *)[window viewWithTag:0xFA500001];
}

- (void)__sg_addFloatingButton {
    UIWindow *window = UIApplication.sharedApplication.keyWindow;
    if (!window) return;

    // تأكد من عدم وجود الزر مسبقًا
    if ([window viewWithTag:0xFA500001]) return;

    // تجاهل الواجهات غير المدعومة (مثل مربعات البحث)
    if ([self isKindOfClass:[UISearchBar class]] || [self isKindOfClass:[UITextField class]]) {
        return;
    }

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.tag = 0xFA500001;
    btn.frame = CGRectMake(window.bounds.size.width - 70, window.bounds.size.height - 160, 56, 56);
    [btn setTitle:@"⬇️" forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:28];
    btn.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6];
    btn.layer.cornerRadius = 28;
    btn.clipsToBounds = YES;
    [btn addTarget:self action:@selector(__sg_handleFloatingButtonTap:) forControlEvents:UIControlEventTouchUpInside];
    [window addSubview:btn];
}

// عند الضغط على الزر ⬇️
- (void)__sg_handleFloatingButtonTap:(UIButton *)btn {
    NSLog(@"[SaveGram] ⬇️ Download button tapped");

    // فحص إصدار النظام (يجب أن يكون ≥ iOS 13)
    if (@available(iOS 13.0, *)) {
        // لا شيء، النظام مدعوم
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"⚠️ غير مدعوم"
                                                                       message:@"هذه الأداة تحتاج iOS 13 أو أحدث."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"حسنًا" style:UIAlertActionStyleCancel handler:nil]];
        UIViewController *root = UIApplication.sharedApplication.keyWindow.rootViewController;
        [root presentViewController:alert animated:YES completion:nil];
        return;
    }

    // عرض نافذة الحفظ
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"SaveGram"
                                                                   message:@"اختر نوع المحتوى الذي تريد حفظه:"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    // حفظ الصورة
    [alert addAction:[UIAlertAction actionWithTitle:@"📸 حفظ الصورة" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UIImage *targetImage = nil;

        // البحث عن صورة في الشاشة الحالية
        for (UIView *sub in UIApplication.sharedApplication.keyWindow.subviews) {
            if ([sub isKindOfClass:[UIImageView class]]) {
                UIImageView *iv = (UIImageView *)sub;
                if (iv.image) {
                    targetImage = iv.image;
                    break;
                }
            }
        }

        if (targetImage) {
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                [PHAssetChangeRequest creationRequestForAssetFromImage:targetImage];
            } completionHandler:^(BOOL success, NSError * _Nullable error) {
                NSLog(@"[SaveGram] Image save: %@", success ? @"✅ Done" : error);
            }];
        } else {
            NSLog(@"[SaveGram] ⚠️ No image found.");
        }
    }]];

    // حفظ الفيديو
    [alert addAction:[UIAlertAction actionWithTitle:@"🎥 حفظ الفيديو" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSURL *videoURL = nil;

        // محاولة العثور على فيديو
        for (UIView *sub in UIApplication.sharedApplication.keyWindow.subviews) {
            CALayer *layer = sub.layer;
            if ([layer isKindOfClass:[AVPlayerLayer class]]) {
                AVPlayerLayer *playerLayer = (AVPlayerLayer *)layer;
                AVPlayerItem *item = playerLayer.player.currentItem;
                if (item && [item.asset isKindOfClass:[AVURLAsset class]]) {
                    videoURL = ((AVURLAsset *)item.asset).URL;
                    break;
                }
            }
        }

        if (!videoURL) {
            NSLog(@"[SaveGram] ⚠️ No video found.");
            return;
        }

        // تصدير الفيديو (تجنب الكراش)
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:videoURL options:nil];
        AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:asset
                                                                               presetName:AVAssetExportPresetHighestQuality];
        if (!exportSession) {
            NSLog(@"[SaveGram] ❌ Export session failed.");
            return;
        }

        NSURL *outputURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"SavedVideo.mp4"]];
        exportSession.outputURL = outputURL;
        exportSession.outputFileType = AVFileTypeMPEG4;
        exportSession.shouldOptimizeForNetworkUse = YES;

        [exportSession exportAsynchronouslyWithCompletionHandler:^{
            if (exportSession.status == AVAssetExportSessionStatusCompleted) {
                UISaveVideoAtPathToSavedPhotosAlbum(outputURL.path, nil, nil, nil);
                NSLog(@"[SaveGram] ✅ Video saved!");
            } else {
                NSLog(@"[SaveGram] ❌ Video export failed: %@", exportSession.error);
            }
        }];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"❌ إلغاء" style:UIAlertActionStyleCancel handler:nil]];

    UIViewController *rootVC = UIApplication.sharedApplication.keyWindow.rootViewController;
    while (rootVC.presentedViewController) {
        rootVC = rootVC.presentedViewController;
    }
    [rootVC presentViewController:alert animated:YES completion:nil];
}

@end

// تحميل الأداة تلقائيًا
%ctor {
    NSLog(@"[SaveGram] ✅ Tweak injected successfully");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication].keyWindow.rootViewController.view __sg_addFloatingButton];
    });
}
