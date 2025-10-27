#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface CustomPopupView : UIView
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;
@end

@implementation CustomPopupView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupBlurBackground];
        [self setupButtons];
    }
    return self;
}

- (void)setupBlurBackground {
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialDark];
    self.blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    self.blurView.frame = self.bounds;
    self.blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:self.blurView];
}

- (void)setupButtons {
    NSArray *titles = @[@"🧹 تنظيف الكاش", @"🔁 إعادة التشغيل", @"❌ إغلاق الأداة", @"📂 تصفح ملفات التطبيق"];
    SEL actions[] = {@selector(cleanCache), @selector(restartApp), @selector(closePopup), @selector(openSandbox)};

    CGFloat buttonWidth = self.frame.size.width - 60;
    CGFloat buttonHeight = 50;
    CGFloat startY = 150;

    for (int i = 0; i < titles.count; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.frame = CGRectMake(30, startY + (i * 70), buttonWidth, buttonHeight);
        [button setTitle:titles[i] forState:UIControlStateNormal];
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        button.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.25];
        button.layer.cornerRadius = 12.0;
        button.clipsToBounds = YES;
        [button addTarget:self action:actions[i] forControlEvents:UIControlEventTouchUpInside];
        [self.blurView.contentView addSubview:button];
    }
}

#pragma mark - Actions

- (void)playClickSound {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"click" ofType:@"wav"];
    if (!path) return;
    NSURL *url = [NSURL fileURLWithPath:path];
    self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
    [self.audioPlayer play];
}

- (void)cleanCache {
    [self playClickSound];
    NSString *cachePath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches"];
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:cachePath error:nil];
    unsigned long long totalSize = 0;
    for (NSString *file in files) {
        NSString *filePath = [cachePath stringByAppendingPathComponent:file];
        NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
        totalSize += [attrs fileSize];
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
    }
    double mb = totalSize / (1024.0 * 1024.0);
    NSString *msg = [NSString stringWithFormat:@"تم حذف %.2f ميغابايت من ملفات الكاش.", mb];
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"✅ تم التنظيف"
                                                                       message:msg
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"موافق" style:UIAlertActionStyleDefault handler:nil]];
        [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
    });
}

- (void)restartApp {
    [self playClickSound];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        exit(0);
    });
}

- (void)closePopup {
    [self playClickSound];
    [UIView animateWithDuration:0.3 animations:^{
        self.alpha = 0.0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

- (void)openSandbox {
    [self playClickSound];
    UIDocumentPickerViewController *picker;
    if (@available(iOS 14.0, *)) {
        picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[[UTType folder]] asCopy:NO];
    } else {
        picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.folder"] inMode:UIDocumentPickerModeOpen];
    }
    picker.modalPresentationStyle = UIModalPresentationFullScreen;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:picker animated:YES completion:nil];
    });
}

@end

// ---------------- AVPlayer و UIImage مراقبة ----------------
%hook AVPlayer

- (void)play {
    %orig;
    [self startObservingMedia];
}

- (void)startObservingMedia {
    __weak typeof(self) weakSelf = self;
    [self addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(1, 1) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        AVAsset *asset = strongSelf.currentItem.asset;
        if ([asset isKindOfClass:[AVURLAsset class]]) {
            NSURL *url = ((AVURLAsset *)asset).URL;
            if (url) {
                [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
                    if (status == PHAuthorizationStatusAuthorized) {
                        NSData *data = [NSData dataWithContentsOfURL:url];
                        if (data) {
                            NSString *ext = url.pathExtension.lowercaseString;
                            NSString *filename = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"video.%@", ext]];
                            [data writeToFile:filename atomically:YES];
                            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                                [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:[NSURL fileURLWithPath:filename]];
                            } completionHandler:nil];
                        }
                    }
                }];
            }
        }
    }];
}

%end

%hook UIImageView

- (void)setImage:(UIImage *)image {
    %orig;
    if (image) {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            if (status == PHAuthorizationStatusAuthorized) {
                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                    [PHAssetChangeRequest creationRequestForAssetFromImage:image];
                } completionHandler:nil];
            }
        }];
    }
}

%end

// ---------------- زر عائم ----------------
%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(UIScreen.mainScreen.bounds.size.width-80, UIScreen.mainScreen.bounds.size.height-150, 60, 60)];
        window.windowLevel = UIWindowLevelAlert + 1;
        window.backgroundColor = UIColor.clearColor;

        UIButton *floatingBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        floatingBtn.frame = window.bounds;
        [floatingBtn setTitle:@"🛠️" forState:UIControlStateNormal];
        floatingBtn.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.5];
        floatingBtn.layer.cornerRadius = 30;
        floatingBtn.clipsToBounds = YES;
        [floatingBtn addTarget:nil action:@selector(showPopup) forControlEvents:UIControlEventTouchUpInside];
        [window addSubview:floatingBtn];
        [window makeKeyAndVisible];

        // إضافة طريقة عرض Popup
        id popupHandler = ^{
            UIWindow *mainWindow = [UIApplication sharedApplication].keyWindow;
            CustomPopupView *popup = [[CustomPopupView alloc] initWithFrame:mainWindow.bounds];
            popup.alpha = 0.0;
            [mainWindow addSubview:popup];
            [UIView animateWithDuration:0.4 animations:^{
                popup.alpha = 1.0;
            }];
        };
        objc_setAssociatedObject(floatingBtn, @"popupHandler", popupHandler, OBJC_ASSOCIATION_COPY_NONATOMIC);
    });
}

// ---------------- عرض Popup عند الضغط ----------------
%hook UIButton
- (void)sendAction:(SEL)action to:(id)target forEvent:(UIEvent *)event {
    if (objc_getAssociatedObject(self, @"popupHandler")) {
        void (^handler)(void) = objc_getAssociatedObject(self, @"popupHandler");
        handler();
        return;
    }
    %orig;
}
%end
