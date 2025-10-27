#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>

NSString *UniversalTweakVersion = @"v1.0.0";

#pragma mark - Toast Helper
@interface UIView (Toast)
+ (void)ut_showToast:(NSString *)message;
@end

@implementation UIView (Toast)
+ (void)ut_showToast:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) return;
        UILabel *label = (UILabel *)[window viewWithTag:0xAABBCC];
        if (!label) {
            label = [[UILabel alloc] initWithFrame:CGRectMake(20, window.bounds.size.height - 130, window.bounds.size.width - 40, 40)];
            label.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.75];
            label.textColor = [UIColor whiteColor];
            label.textAlignment = NSTextAlignmentCenter;
            label.font = [UIFont boldSystemFontOfSize:15];
            label.layer.cornerRadius = 10;
            label.layer.masksToBounds = YES;
            label.tag = 0xAABBCC;
            [window addSubview:label];
        }
        label.text = message;
        label.alpha = 1.0;
        [UIView animateWithDuration:0.5 delay:2.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            label.alpha = 0;
        } completion:nil];
    });
}
@end

#pragma mark - Downloader Helper
@interface UIView (UniversalDownloader)
- (void)ut_addDownloadButton;
- (void)ut_handleDownload;
@end

@implementation UIView (UniversalDownloader)

- (void)ut_addDownloadButton {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) return;

        UIButton *button = (UIButton *)[window viewWithTag:0xDD5500];
        if (!button) {
            button = [UIButton buttonWithType:UIButtonTypeCustom];
            button.tag = 0xDD5500;
            button.frame = CGRectMake(window.bounds.size.width - 70, window.bounds.size.height - 150, 55, 55);
            button.layer.cornerRadius = 27.5;
            button.layer.masksToBounds = YES;
            button.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
            [button setTitle:@"⬇️" forState:UIControlStateNormal];
            [button addTarget:self action:@selector(ut_handleDownload) forControlEvents:UIControlEventTouchUpInside];
            [window addSubview:button];
        }

        // تحديث حالة الزر
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
                BOOL hasMedia = NO;
                for (UIView *v in window.subviews) {
                    if ([v isKindOfClass:[UIImageView class]] && ((UIImageView *)v).image) {
                        hasMedia = YES;
                        break;
                    } else if ([v.layer isKindOfClass:[AVPlayerLayer class]]) {
                        AVPlayerLayer *layer = (AVPlayerLayer *)v.layer;
                        if (layer.player.currentItem) {
                            hasMedia = YES;
                            break;
                        }
                    }
                }
                button.hidden = !hasMedia;
            }];
        });
    });
}

- (void)ut_handleDownload {
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (!window) return;

    UIImage *foundImage = nil;
    NSURL *foundVideoURL = nil;

    // البحث داخل جميع النوافذ
    for (UIView *v in window.subviews) {
        if ([v isKindOfClass:[UIImageView class]]) {
            UIImageView *img = (UIImageView *)v;
            if (img.image) { foundImage = img.image; break; }
        } else if ([v.layer isKindOfClass:[AVPlayerLayer class]]) {
            AVPlayerLayer *layer = (AVPlayerLayer *)v.layer;
            AVPlayerItem *item = layer.player.currentItem;
            if (item && [item.asset isKindOfClass:[AVURLAsset class]]) {
                foundVideoURL = ((AVURLAsset *)item.asset).URL;
                break;
            }
        }
    }

    if (!foundImage && !foundVideoURL) {
        [UIView ut_showToast:@"❌ لم يتم العثور على أي وسائط قابلة للحفظ"];
        return;
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"⬇️ حفظ الوسائط"
                                                                   message:@"اختر نوع المحتوى الذي تريد حفظه"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];

    if (foundImage) {
        [alert addAction:[UIAlertAction actionWithTitle:@"📸 حفظ الصورة" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            UIImageWriteToSavedPhotosAlbum(foundImage, nil, nil, nil);
            [UIView ut_showToast:@"✅ تم حفظ الصورة بنجاح"];
        }]];
    }

    if (foundVideoURL) {
        [alert addAction:[UIAlertAction actionWithTitle:@"🎥 حفظ الفيديو" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:foundVideoURL];
            } completionHandler:^(BOOL success, NSError * _Nullable error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [UIView ut_showToast:(success ? @"✅ تم حفظ الفيديو" : @"❌ فشل حفظ الفيديو")];
                });
            }];
        }]];
    }

    UIViewController *root = window.rootViewController;
    while (root.presentedViewController) root = root.presentedViewController;
    [root presentViewController:alert animated:YES completion:nil];
}
@end

#pragma mark - Hook to UIApplication
%hook UIApplication
- (void)applicationDidBecomeActive:(UIApplication *)application {
    %orig;
    [[UIApplication sharedApplication].keyWindow ut_addDownloadButton];
}
%end
