#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <Photos/Photos.h>

@interface UIView (FileSaverTweak)
+ (void)sg_showAlertStatic:(NSString *)title message:(NSString *)message;
- (void)__sg_handleFloatingButtonTap:(UIButton *)btn;
- (UIWindow *)sg_activeWindow;
@end

@implementation UIView (FileSaverTweak)

// ✅ طريقة آمنة لجلب النافذة الفعالة (بدل keyWindow)
- (UIWindow *)sg_activeWindow {
    for (UIWindowScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *win in scene.windows) {
                if (win.isKeyWindow) return win;
            }
        }
    }
    return UIApplication.sharedApplication.windows.firstObject;
}

// عرض تنبيه بسيط
+ (void)sg_showAlertStatic:(NSString *)title message:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [[UIView new] sg_activeWindow];
        if (!window) return;

        UIViewController *rootVC = window.rootViewController;
        if (!rootVC) return;

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *ok = [UIAlertAction actionWithTitle:@"موافق"
                                                     style:UIAlertActionStyleDefault
                                                   handler:nil];
        [alert addAction:ok];
        [rootVC presentViewController:alert animated:YES completion:nil];
    });
}

// عند الضغط على زر التحميل ⬇️
- (void)__sg_handleFloatingButtonTap:(UIButton *)btn {
    UIWindow *window = [self sg_activeWindow];
    UIViewController *rootVC = window.rootViewController;
    if (!rootVC) return;

    UIAlertController *menu = [UIAlertController alertControllerWithTitle:@"📥 التحميل"
                                                                  message:@"اختر نوع المحتوى"
                                                           preferredStyle:UIAlertControllerStyleActionSheet];

    UIAlertAction *saveImage = [UIAlertAction actionWithTitle:@"📸 حفظ الصورة"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction *action) {
        [self sg_saveVisibleImage];
    }];

    UIAlertAction *saveVideo = [UIAlertAction actionWithTitle:@"🎥 حفظ الفيديو"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction *action) {
        [self sg_saveVisibleVideo];
    }];

    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"إلغاء"
                                                     style:UIAlertActionStyleCancel
                                                   handler:nil];

    [menu addAction:saveImage];
    [menu addAction:saveVideo];
    [menu addAction:cancel];

    [rootVC presentViewController:menu animated:YES completion:nil];
}

// حفظ الصور
- (void)sg_saveVisibleImage {
    __block UIImage *targetImage = nil;

    UIWindow *window = [self sg_activeWindow];
    if (!window) return;

    for (UIView *subview in window.subviews) {
        if ([subview isKindOfClass:[UIImageView class]]) {
            UIImageView *imgView = (UIImageView *)subview;
            if (imgView.image) {
                targetImage = imgView.image;
                break;
            }
        }
    }

    if (!targetImage) {
        [UIView sg_showAlertStatic:@"❗️" message:@"لم يتم العثور على صورة لحفظها."];
        return;
    }

    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromImage:targetImage];
    } completionHandler:^(BOOL success, NSError *error) {
        if (success)
            [UIView sg_showAlertStatic:@"تم ✅" message:@"تم حفظ الصورة بنجاح"];
        else
            [UIView sg_showAlertStatic:@"خطأ ❌" message:error.localizedDescription ?: @"حدث خطأ أثناء الحفظ"];
    }];
}

// حفظ الفيديوهات
- (void)sg_saveVisibleVideo {
    __block NSURL *videoURL = nil;
    UIWindow *window = [self sg_activeWindow];
    if (!window) return;

    // من AVPlayerViewController
    UIViewController *rootVC = window.rootViewController;
    if ([rootVC isKindOfClass:[AVPlayerViewController class]]) {
        AVPlayerViewController *pvc = (AVPlayerViewController *)rootVC;
        AVPlayerItem *item = pvc.player.currentItem;
        if ([item.asset isKindOfClass:[AVURLAsset class]]) {
            videoURL = ((AVURLAsset *)item.asset).URL;
        }
    }

    // من AVPlayerLayer
    if (!videoURL) {
        for (UIView *v in window.subviews) {
            if ([v.layer isKindOfClass:[AVPlayerLayer class]]) {
                AVPlayerLayer *layer = (AVPlayerLayer *)v.layer;
                AVPlayerItem *item = layer.player.currentItem;
                if ([item.asset isKindOfClass:[AVURLAsset class]]) {
                    videoURL = ((AVURLAsset *)item.asset).URL;
                    break;
                }
            }
        }
    }

    if (!videoURL) {
        [UIView sg_showAlertStatic:@"❗️" message:@"لم يتم العثور على فيديو لحفظه."];
        return;
    }

    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:videoURL];
    } completionHandler:^(BOOL success, NSError *error) {
        if (success)
            [UIView sg_showAlertStatic:@"تم ✅" message:@"تم حفظ الفيديو بنجاح"];
        else
            [UIView sg_showAlertStatic:@"خطأ ❌" message:error.localizedDescription ?: @"حدث خطأ أثناء الحفظ"];
    }];
}

@end

// ✅ الزر يضاف بأمان بعد التأكد من أن الواجهة جاهزة
%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;

    UIWindow *window = [[UIView new] sg_activeWindow];
    if (!window) return;

    UIButton *btn = [window viewWithTag:0xFA500001];
    if (!btn) {
        btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.tag = 0xFA500001;
        [btn setTitle:@"⬇️" forState:UIControlStateNormal];
        btn.frame = CGRectMake(window.bounds.size.width - 70, window.bounds.size.height - 160, 50, 50);
        btn.layer.cornerRadius = 25;
        btn.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [btn addTarget:self.view action:@selector(__sg_handleFloatingButtonTap:) forControlEvents:UIControlEventTouchUpInside];
        btn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
        dispatch_async(dispatch_get_main_queue(), ^{
            [window addSubview:btn];
        });
    }
}
%end
