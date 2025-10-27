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
        [self startObservingMedia];
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
    NSArray *titles = @[@"🧹 تنظيف الكاش", @"🔁 إعادة التشغيل", @"❌ إغلاق", @"📂 تصفح الملفات"];
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
    UIViewController *sandboxVC = [[UIViewController alloc] init];
    sandboxVC.view.backgroundColor = [UIColor systemBackgroundColor];
    sandboxVC.title = @"ملفات التطبيق";

    UITextView *textView = [[UITextView alloc] initWithFrame:sandboxVC.view.bounds];
    textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    textView.editable = NO;

    NSString *homePath = NSHomeDirectory();
    NSArray *files = [[NSFileManager defaultManager] subpathsAtPath:homePath];
    textView.text = [files componentsJoinedByString:@"\n"];

    [sandboxVC.view addSubview:textView];

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:sandboxVC];
    [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:nav animated:YES completion:nil];
}

#pragma mark - Auto Save Media

- (void)startObservingMedia {
    // مراقبة عرض الفيديوهات والصور
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleAVPlayerStart:)
                                                 name:AVPlayerItemNewAccessLogEntryNotification
                                               object:nil];
}

- (void)handleAVPlayerStart:(NSNotification *)notification {
    AVPlayerItem *item = notification.object;
    if (!item) return;
    
    AVAsset *asset = item.asset;
    if ([asset isKindOfClass:[AVURLAsset class]]) {
        NSURL *url = ((AVURLAsset *)asset).URL;
        [self saveVideoFromURL:url];
    }
}

- (void)saveVideoFromURL:(NSURL *)url {
    if (!url) return;
    NSData *data = [NSData dataWithContentsOfURL:url];
    if (!data) return;

    NSString *filename = url.lastPathComponent;
    NSURL *destination = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:filename]];
    [data writeToURL:destination atomically:YES];

    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:destination];
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        if (success) {
            NSLog(@"✅ الفيديو تم حفظه تلقائيًا: %@", filename);
        }
    }];
}

@end

#pragma mark - Floating Button

%ctor {
    if (@available(iOS 16.0, *)) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *window = [UIApplication sharedApplication].keyWindow;

            // زر عائم
            UIButton *floatingButton = [UIButton buttonWithType:UIButtonTypeSystem];
            floatingButton.frame = CGRectMake(window.bounds.size.width - 80, window.bounds.size.height - 150, 60, 60);
            floatingButton.layer.cornerRadius = 30;
            floatingButton.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.8];
            [floatingButton setTitle:@"🛠" forState:UIControlStateNormal];
            [floatingButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            floatingButton.clipsToBounds = YES;
            [floatingButton addTarget:nil action:@selector(showCustomPopup) forControlEvents:UIControlEventTouchUpInside];

            [window addSubview:floatingButton];
        });
    }
}

%hook UIApplication

- (void)showCustomPopup {
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    CustomPopupView *popup = [[CustomPopupView alloc] initWithFrame:window.bounds];
    popup.alpha = 0.0;
    [window addSubview:popup];
    [UIView animateWithDuration:0.4 animations:^{
        popup.alpha = 1.0;
    }];
}

%end
