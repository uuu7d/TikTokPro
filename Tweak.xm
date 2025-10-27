#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>

// ============================================================
// 📸 FileSaverTweak — حفظ الصور والفيديوهات بزر ⬇️
// يعمل على iOS 13 إلى iOS 18 — آمن ضد الكراش
// ============================================================

@interface UIView (FileSaver)
+ (void)fs_showToast:(NSString *)msg;
- (void)fs_addDownloadButtonIfNeeded;
- (void)fs_handleDownloadButtonTap:(UIButton *)btn;
@end

@implementation UIView (FileSaver)

#pragma mark - Toast Notification
+ (void)fs_showToast:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *w = [UIApplication sharedApplication].keyWindow;
        if (!w) return;

        UILabel *lbl = (UILabel *)[w viewWithTag:0xFA50002];
        if (!lbl) {
            lbl = [[UILabel alloc] initWithFrame:CGRectMake(20, w.bounds.size.height - 140, w.bounds.size.width - 40, 40)];
            lbl.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
            lbl.textColor = UIColor.whiteColor;
            lbl.textAlignment = NSTextAlignmentCenter;
            lbl.layer.cornerRadius = 10;
            lbl.layer.masksToBounds = YES;
            lbl.tag = 0xFA50002;
            lbl.font = [UIFont boldSystemFontOfSize:15];
            [w addSubview:lbl];
        }
        lbl.text = msg;
        lbl.alpha = 1.0;

        [UIView animateWithDuration:0.5 delay:2.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            lbl.alpha = 0;
        } completion:nil];
    });
}

#pragma mark - زر التحميل
- (void)fs_addDownloadButtonIfNeeded {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) return;

        UIButton *btn = (UIButton *)[window viewWithTag:0xFA50001];
        if (!btn) {
            btn = [UIButton buttonWithType:UIButtonTypeCustom];
            btn.tag = 0xFA50001;
            btn.frame = CGRectMake(window.bounds.size.width - 70, window.bounds.size.height - 150, 50, 50);
            [btn setTitle:@"⬇️" forState:UIControlStateNormal];
            btn.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
            btn.layer.cornerRadius = 25;
            btn.layer.masksToBounds = YES;
            [btn addTarget:self action:@selector(fs_handleDownloadButtonTap:) forControlEvents:UIControlEventTouchUpInside];
            [window addSubview:btn];
        }

        // التحقق كل ثانية من نوع المحتوى المعروض
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
                BOOL hasMedia = NO;
                for (UIView *subview in window.subviews) {
                    if ([subview isKindOfClass:[UIImageView class]]) {
                        UIImageView *imgV = (UIImageView *)subview;
                        if (imgV.image) { hasMedia = YES; break; }
                    } else if ([subview.layer isKindOfClass:[AVPlayerLayer class]]) {
                        AVPlayerLayer *layer = (AVPlayerLayer *)subview.layer;
                        if (layer.player.currentItem) { hasMedia = YES; break; }
                    }
                }
                btn.hidden = !hasMedia;
            }];
        });
    });
}

#pragma mark - تنفيذ التحميل
- (void)fs_handleDownloadButtonTap:(UIButton *)btn {
    UIWindow *w = [UIApplication sharedApplication].keyWindow;
    if (!w) return;

    UIImage *foundImage = nil;
    NSURL *foundVideoURL = nil;

    // البحث عن الصور أو الفيديوهات في الواجهة
    for (UIView *subview in w.subviews) {
        if ([subview isKindOfClass:[UIImageView class]]) {
            UIImageView *imgV = (UIImageView *)subview;
            if (imgV.image) { foundImage = imgV.image; break; }
        } else if ([subview.layer isKindOfClass:[AVPlayerLayer class]]) {
            AVPlayerLayer *layer = (AVPlayerLayer *)subview.layer;
            AVPlayerItem *item = layer.player.currentItem;
            if (item && [item.asset isKindOfClass:[AVURLAsset class]]) {
                foundVideoURL = ((AVURLAsset *)item.asset).URL;
                break;
            }
        }
    }

    if (!foundImage && !foundVideoURL) {
        [UIView fs_showToast:@"❌ لا يوجد وسائط يمكن حفظها"];
        return;
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"⬇️ حفظ المحتوى"
                                                                   message:@"اختر ما تريد حفظه"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];

    if (foundImage) {
        [alert addAction:[UIAlertAction actionWithTitle:@"📸 حفظ الصورة" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            UIImageWriteToSavedPhotosAlbum(foundImage, nil, nil, nil);
            [UIView fs_showToast:@"✅ تم حفظ الصورة بنجاح"];
        }]];
    }

    if (foundVideoURL) {
        [alert addAction:[UIAlertAction actionWithTitle:@"🎥 حفظ الفيديو" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:foundVideoURL];
            } completionHandler:^(BOOL success, NSError * _Nullable error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [UIView fs_showToast:(success ? @"✅ تم حفظ الفيديو" : @"❌ فشل حفظ الفيديو")];
                });
            }];
        }]];
    }

    UIViewController *root = w.rootViewController;
    while (root.presentedViewController) root = root.presentedViewController;
    [root presentViewController:alert animated:YES completion:nil];
}

@end


%hook UIApplication
- (void)applicationDidBecomeActive:(UIApplication *)application {
    %orig;
    [[UIApplication sharedApplication].keyWindow fs_addDownloadButtonIfNeeded];
}
%end
