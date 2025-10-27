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
    NSArray *titles = @[@"🧹 تنظيف الكاش", @"🔁 إعادة التشغيل", @"❌ إغلاق"];
    SEL actions[] = {@selector(cleanCache), @selector(restartApp), @selector(closePopup)};

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
    NSString *appPath = NSHomeDirectory();
    NSString *cachePath = [appPath stringByAppendingPathComponent:@"Library/Caches"];
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

@end

// Helper function to save media from AVPlayer
void SaveMediaFromURL(NSURL *mediaURL) {
    NSString *fileExt = mediaURL.pathExtension.lowercaseString;
    NSData *data = [NSData dataWithContentsOfURL:mediaURL];
    if (!data) return;

    if ([fileExt isEqualToString:@"jpg"] || [fileExt isEqualToString:@"png"]) {
        UIImage *image = [UIImage imageWithData:data];
        if (image) {
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                [PHAssetChangeRequest creationRequestForAssetFromImage:image];
            } completionHandler:nil];
        }
    } else if ([fileExt isEqualToString:@"mp4"] || [fileExt isEqualToString:@"mov"]) {
        NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:mediaURL.lastPathComponent];
        [data writeToFile:tmpPath atomically:YES];
        NSURL *destination = [NSURL fileURLWithPath:tmpPath];
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:destination];
        } completionHandler:nil];
    }
}

%ctor {
    if (@available(iOS 16.0, *)) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *window = [UIApplication sharedApplication].keyWindow;

            // Floating button
            UIButton *floatingBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            floatingBtn.frame = CGRectMake(window.frame.size.width - 70, window.frame.size.height - 150, 60, 60);
            floatingBtn.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.7];
            floatingBtn.layer.cornerRadius = 30;
            [floatingBtn setTitle:@"⚡" forState:UIControlStateNormal];
            [floatingBtn addTarget:nil action:@selector(showPopup) forControlEvents:UIControlEventTouchUpInside];
            [window addSubview:floatingBtn];

            // Popup handler
            objc_setAssociatedObject(floatingBtn, @"popupHandler", ^{
                CustomPopupView *popup = [[CustomPopupView alloc] initWithFrame:window.bounds];
                popup.alpha = 0.0;
                [window addSubview:popup];
                [UIView animateWithDuration:0.4 animations:^{
                    popup.alpha = 1.0;
                }];
            }, OBJC_ASSOCIATION_COPY_NONATOMIC);

            // Method to trigger popup
            SEL showPopupSEL = @selector(showPopup);
            class_addMethod([floatingBtn class], showPopupSEL, imp_implementationWithBlock(^{
                void (^handler)(void) = objc_getAssociatedObject(floatingBtn, @"popupHandler");
                if (handler) handler();
            }), "v@:");
        });
    }
}
