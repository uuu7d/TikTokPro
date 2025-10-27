#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface CustomPopupView : UIView
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;
@property (nonatomic, strong) NSString *currentPath; // مسار الملف الحالي للحفظ
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

#pragma mark - Save Media

- (void)saveVideoAtPath:(NSString *)fullPath {
    self.currentPath = fullPath;
    if (!fullPath) return;
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:[NSURL fileURLWithPath:fullPath]];
    } completionHandler:nil];
}

- (void)saveImageAtPath:(NSString *)fullPath {
    self.currentPath = fullPath;
    if (!fullPath) return;
    UIImage *img = [UIImage imageWithContentsOfFile:fullPath];
    if (!img) return;
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromImage:img];
    } completionHandler:nil];
}

@end

#pragma mark - Floating Button

%ctor {
    if (@available(iOS 16.0, *)) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;

            // زر عائم للوصول للأداة
            UIButton *floatingBtn = [UIButton buttonWithType:UIButtonTypeSystem];
            floatingBtn.frame = CGRectMake(keyWindow.frame.size.width - 70, keyWindow.frame.size.height - 150, 60, 60);
            floatingBtn.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.8];
            floatingBtn.layer.cornerRadius = 30;
            [floatingBtn setTitle:@"🛠️" forState:UIControlStateNormal];
            [floatingBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [floatingBtn addTarget:nil action:@selector(showPopup) forControl
