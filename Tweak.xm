#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

@interface UIView (FileSaver)
+ (void)fs_showAlert:(NSString *)title message:(NSString *)message;
- (void)fs_handleDownloadButtonTap:(UIButton *)sender;
@end

@implementation UIView (FileSaver)

+ (void)fs_showAlert:(NSString *)title message:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"حسنًا" style:UIAlertActionStyleDefault handler:nil]];
        UIViewController *rootVC = UIApplication.sharedApplication.keyWindow.rootViewController;
        [rootVC presentViewController:alert animated:YES completion:nil];
    });
}

- (void)fs_handleDownloadButtonTap:(UIButton *)sender {
    UIWindow *window = UIApplication.sharedApplication.keyWindow;
    if (!window) return;
    
    // نحاول إيجاد صورة أو فيديو حالي في الواجهة
    UIImageView *imageView = nil;
    AVPlayerLayer *playerLayer = nil;

    for (UIView *subview in window.subviews) {
        if ([subview isKindOfClass:[UIImageView class]]) {
            imageView = (UIImageView *)subview;
            break;
        }
        for (CALayer *layer in subview.layer.sublayers) {
            if ([layer isKindOfClass:[AVPlayerLayer class]]) {
                playerLayer = (AVPlayerLayer *)layer;
                break;
            }
        }
    }

    if (imageView && imageView.image) {
        UIImageWriteToSavedPhotosAlbum(imageView.image, nil, nil, nil);
        [UIView fs_showAlert:@"تم الحفظ ✅" message:@"تم حفظ الصورة بنجاح في ألبوم الصور"];
    } else if (playerLayer && playerLayer.player.currentItem.asset) {
        AVURLAsset *asset = (AVURLAsset *)playerLayer.player.currentItem.asset;
        if ([asset isKindOfClass:[AVURLAsset class]]) {
            NSURL *url = asset.URL;
            NSData *data = [NSData dataWithContentsOfURL:url];
            NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"savedVideo.mp4"];
            [data writeToFile:path atomically:YES];
            UISaveVideoAtPathToSavedPhotosAlbum(path, nil, nil, nil);
            [UIView fs_showAlert:@"تم الحفظ 🎥" message:@"تم حفظ الفيديو بنجاح في ألبوم الصور"];
        }
    } else {
        [UIView fs_showAlert:@"⚠️ لم يتم العثور على محتوى" message:@"لم يتم العثور على صورة أو فيديو لحفظه."];
    }
}

@end


// ------- مراقبة مستمرة لظهور الصور/الفيديو -------

@interface UIWindow (FileSaverMonitor)
- (void)fs_startMonitoring;
@end

@implementation UIWindow (FileSaverMonitor)

- (void)fs_startMonitoring {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                          target:self
                                                        selector:@selector(fs_checkForMedia)
                                                        userInfo:nil
                                                         repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    });
}

- (void)fs_checkForMedia {
    BOOL foundMedia = NO;
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIImageView class]]) {
            foundMedia = YES;
            break;
        }
        for (CALayer *layer in subview.layer.sublayers) {
            if ([layer isKindOfClass:[AVPlayerLayer class]]) {
                foundMedia = YES;
                break;
            }
        }
    }

    UIButton *btn = (UIButton *)[self viewWithTag:0xFA500001001];
    if (!btn) {
        btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame = CGRectMake(self.bounds.size.width - 80, self.bounds.size.height - 150, 60, 60);
        btn.layer.cornerRadius = 30;
        btn.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.8];
        [btn setTitle:@"⬇️" forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:26];
        btn.tintColor = UIColor.whiteColor;
        btn.tag = 0xFA500001001;
        [btn addTarget:self action:@selector(fs_handleDownloadButtonTap:) forControlEvents:UIControlEventTouchUpInside];
        btn.hidden = YES;
        [self addSubview:btn];
    }

    // عرض أو إخفاء الزر حسب الحالة
    btn.hidden = !foundMedia;
}

@end


// ------- تفعيل المراقبة عند تشغيل التطبيق -------

%hook UIApplication

- (void)didFinishLaunching:(NSNotification *)notification {
    %orig;
    UIWindow *keyWindow = UIApplication.sharedApplication.keyWindow;
    [keyWindow fs_startMonitoring];
}

%end
