#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface CustomPopupView : UIView
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;
@property (nonatomic, strong) AVPlayer *player;
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
    [self removeFromSuperview];
}

- (void)openSandbox {
    [self playClickSound];
    if (@available(iOS 14.0, *)) {
        UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeFolder] asCopy:NO];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:picker animated:YES completion:nil];
        });
    }
}

#pragma mark - Media Saving

- (void)observePlayer:(AVPlayer *)player {
    __weak AVPlayer *weakPlayer = player;
    [player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(1, 1)
                                        queue:dispatch_get_main_queue()
                                   usingBlock:^(CMTime time) {
        AVPlayer *strongPlayer = weakPlayer;
        if (!strongPlayer) return;
        AVAsset *asset = strongPlayer.currentItem.asset;
        if ([asset isKindOfClass:[AVURLAsset class]]) {
            NSURL *url = [(AVURLAsset *)asset URL];
            [self saveMediaFromURL:url];
        }
    }];
}

- (void)saveMediaFromURL:(NSURL *)url {
    if (!url) return;
    NSString *fileExt = url.pathExtension.lowercaseString;

    NSURLSessionDownloadTask *task = [[NSURLSession sharedSession] downloadTaskWithURL:url completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        if (error) return;

        if ([fileExt isEqualToString:@"jpg"] || [fileExt isEqualToString:@"png"]) {
            UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:location]];
            if (image) {
                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                    [PHAssetChangeRequest creationRequestForAssetFromImage:image];
                } completionHandler:nil];
            }
        } else if ([fileExt isEqualToString:@"mp4"] || [fileExt isEqualToString:@"mov"]) {
            NSURL *destination = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:response.suggestedFilename]];
            [[NSFileManager defaultManager] moveItemAtURL:location toURL:destination error:nil];
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:destination];
            } completionHandler:nil];
        }
    }];
    [task resume];
}

@end

#pragma mark - Constructor

static void showPopup() {
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    CustomPopupView *popup = [[CustomPopupView alloc] initWithFrame:window.bounds];
    popup.alpha = 0.0;
    [window addSubview:popup];
    [UIView animateWithDuration:0.4 animations:^{
        popup.alpha = 1.0;
    }];
}

%ctor {
    if (@available(iOS 16.0, *)) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *window = [UIApplication sharedApplication].keyWindow;

            UIButton *floatingBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            floatingBtn.frame = CGRectMake(window.bounds.size.width - 80, window.bounds.size.height - 150, 60, 60);
            floatingBtn.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.8];
            floatingBtn.layer.cornerRadius = 30;
            [floatingBtn setTitle:@"⚡" forState:UIControlStateNormal];
            [floatingBtn addTarget:nil action:@selector(showPopup) forControlEvents:UIControlEventTouchUpInside];
            [window addSubview:floatingBtn];

            showPopup();
        });
    } else {
        NSLog(@"❌ هذه الأداة تعمل فقط على iOS 16 وأعلى.");
    }
}
