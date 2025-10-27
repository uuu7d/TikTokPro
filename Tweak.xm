#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>

@interface UIView (FileSaverTweak)
+ (void)sg_showAlertStatic:(NSString *)title message:(NSString *)message;
- (void)__sg_handleFloatingButtonTap:(UIButton *)btn;
@end

@implementation UIView (FileSaverTweak)

// ✅ دالة عرض تنبيهات ثابتة لتجنب crash
+ (void)sg_showAlertStatic:(NSString *)title message:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *ok = [UIAlertAction actionWithTitle:@"موافق" style:UIAlertActionStyleDefault handler:nil];
        [alert addAction:ok];
        UIWindow *keyWindow = UIApplication.sharedApplication.keyWindow;
        [keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
    });
}

// ✅ دالة رئيسية عند الضغط على الزر ⬇️
- (void)__sg_handleFloatingButtonTap:(UIButton *)btn {
    UIView *targetView = UIApplication.sharedApplication.keyWindow.rootViewController.view;
    if (!targetView) {
        [UIView sg_showAlertStatic:@"خطأ" message:@"تعذر العثور على المحتوى"];
        return;
    }

    // عرض قائمة الخيارات
    UIAlertController *menu = [UIAlertController alertControllerWithTitle:@"خيارات التحميل"
                                                                  message:@"اختر نوع المحتوى للحفظ"
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

// ✅ حفظ الصور المعروضة
- (void)sg_saveVisibleImage {
    __block UIImage *targetImage = nil;

    for (UIView *subview in UIApplication.sharedApplication.keyWindow.rootViewController.view.subviews) {
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

// ✅ حفظ الفيديوهات المعروضة
- (void)sg_saveVisibleVideo {
    __block NSURL *videoURL = nil;

    for (UIView *subview in UIApplication.sharedApplication.keyWindow.rootViewController.view.subviews) {
        if ([subview isKindOfClass:NSClassFromString(@"AVPlayerView")]) {
            AVPlayerView *playerView = (AVPlayerView *)subview;
            AVPlayerItem *item = playerView.player.currentItem;
            if ([item.asset isKindOfClass:[AVURLAsset class]]) {
                videoURL = ((AVURLAsset *)item.asset).URL;
                break;
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

// ✅ زر التحميل ⬇️
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
        [window addSubview:downloadButton];
    }
}

%end
