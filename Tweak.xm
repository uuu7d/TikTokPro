#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <Photos/Photos.h>

@interface UIView (FileSaverTweak)
+ (void)sg_showAlertStatic:(NSString *)title message:(NSString *)message;
- (void)__sg_handleFloatingButtonTap:(UIButton *)btn;
@end

@implementation UIView (FileSaverTweak)

// عرض تنبيه ثابت
+ (void)sg_showAlertStatic:(NSString *)title message:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *ok = [UIAlertAction actionWithTitle:@"موافق"
                                                     style:UIAlertActionStyleDefault
                                                   handler:nil];
        [alert addAction:ok];
        UIWindow *keyWindow = UIApplication.sharedApplication.keyWindow;
        [keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
    });
}

// عند الضغط على زر التحميل ⬇️
- (void)__sg_handleFloatingButtonTap:(UIButton *)btn {
    UIAlertController *menu = [UIAlertController alertControllerWithTitle:@"خيارات التحميل"
                                                                  message:@"اختر ما تريد حفظه"
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

    UIWindow *window = UIApplication.sharedApplication.keyWindow;
    [window.rootViewController presentViewController:menu animated:YES completion:nil];
}

// حفظ الصور
- (void)sg_saveVisibleImage {
    __block UIImage *targetImage = nil;

    // البحث في كل UIImageView في النافذة الحالية
    for (UIView *subview in UIApplication.sharedApplication.keyWindow.subviews) {
        if ([subview isKindOfClass:[UIImageView class]]) {
            UIImageView *imgView = (UIImageView *)subview;
            if (imgView.image) {
                targetImage = imgView.image;
                break;
            }
        }
    }

    if (!targetImage) {
        [UIView sg_showAlertStatic:@"تنبيه" message:@"لم يتم العثور على صورة لحفظها."];
        return;
    }

    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromImage:targetImage];
    } completionHandler:^(BOOL success, NSError *error) {
        if (success)
            [UIView sg_showAlertStatic:@"تم" message:@"تم حفظ الصورة بنجاح 📸"];
        else
            [UIView sg_showAlertStatic:@"خطأ" message:error.localizedDescription ?: @"حدث خطأ أثناء الحفظ"];
    }];
}

// حفظ الفيديوهات من AVPlayerLayer أو AVPlayerViewController
- (void)sg_saveVisibleVideo {
    __block NSURL *videoURL = nil;

    // أولاً نحاول استخراج الفيديو من AVPlayerViewController إن وُجد
    for (UIWindow *window in UIApplication.sharedApplication.windows) {
        UIViewController *rootVC = window.rootViewController;
        if ([rootVC isKindOfClass:[AVPlayerViewController class]]) {
            AVPlayerViewController *pvc = (AVPlayerViewController *)rootVC;
            AVPlayerItem *item = pvc.player.currentItem;
            if ([item.asset isKindOfClass:[AVURLAsset class]]) {
                videoURL = ((AVURLAsset *)item.asset).URL;
                break;
            }
        }

        // ثانيًا من الـ AVPlayerLayer إن وُجد داخل أي UIView
        for (UIView *view in window.subviews) {
            if ([view.layer isKindOfClass:[AVPlayerLayer class]]) {
                AVPlayerLayer *playerLayer = (AVPlayerLayer *)view.layer;
                AVPlayerItem *item = playerLayer.player.currentItem;
                if ([item.asset isKindOfClass:[AVURLAsset class]]) {
                    videoURL = ((AVURLAsset *)item.asset).URL;
                    break;
                }
            }
        }
    }

    if (!videoURL) {
        [UIView sg_showAlertStatic:@"تنبيه" message:@"لم يتم العثور على فيديو لحفظه."];
        return;
    }

    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:videoURL];
    } completionHandler:^(BOOL success, NSError *error) {
        if (success)
            [UIView sg_showAlertStatic:@"تم" message:@"تم حفظ الفيديو بنجاح 🎥"];
        else
            [UIView sg_showAlertStatic:@"خطأ" message:error.localizedDescription ?: @"حدث خطأ أثناء الحفظ"];
    }];
}

@end

// زر التحميل ⬇️ يظهر بشكل دائم وآمن
%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    UIWindow *window = UIApplication.sharedApplication.keyWindow;
    if (!window) return;

    UIButton *downloadButton = [window viewWithTag:0xFA500001];
    if (!downloadButton) {
        downloadButton = [UIButton buttonWithType:UIButtonTypeSystem];
        downloadButton.tag = 0xFA500001;
        [downloadButton setTitle:@"⬇️" forState:UIControlStateNormal];
        downloadButton.frame = CGRectMake(window.bounds.size.width - 70, window.bounds.size.height - 150, 50, 50);
        downloadButton.layer.cornerRadius = 25;
        downloadButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
        [downloadButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [downloadButton addTarget:self.view action:@selector(__sg_handleFloatingButtonTap:) forControlEvents:UIControlEventTouchUpInside];
        downloadButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
        [window addSubview:downloadButton];
    }
}

%end
