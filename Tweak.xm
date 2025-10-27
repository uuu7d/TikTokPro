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
    NSArray *titles = @[@"تيليجرام", @"سناب شات", @"🧹 تنظيف الكاش", @"🔁 إعادة التشغيل", @"💾 حفظ المحتوى المرئي"];
    SEL actions[] = {@selector(openTelegram), @selector(openSnapchat), @selector(cleanCache), @selector(restartApp), @selector(saveMedia)};

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

- (void)openTelegram {
    [self playClickSound];
    NSURL *url = [NSURL URLWithString:@"tg://resolve?domain=yourTelegramUsername"];
    if ([[UIApplication sharedApplication] canOpenURL:url])
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

- (void)openSnapchat {
    [self playClickSound];
    NSURL *url = [NSURL URLWithString:@"https://www.snapchat.com/add/yourSnapUsername"];
    if ([[UIApplication sharedApplication] canOpenURL:url])
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
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
        [UIWindow *window = nil; if (@available(iOS 13.0, *)) {     for (UIWindowScene* scene in [UIApplication sharedApplication].connectedScenes) {         if (scene.activationState == UISceneActivationStateForegroundActive) {             window = scene.windows.firstObject;             break;         }     } } else {     window = [UIApplication sharedApplication].keyWindow; } UIViewController *rootVC = window.rootViewController; presentViewController:alert animated:YES completion:nil];
    });
}

- (void)restartApp {
    [self playClickSound];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        exit(0);
    });
}

- (void)saveMedia {
    [self playClickSound];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"💾 حفظ المحتوى"
                                                                   message:@"أدخل رابط الصورة أو الفيديو:"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"https://example.com/media.mp4";
    }];

    UIAlertAction *download = [UIAlertAction actionWithTitle:@"تنزيل" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *urlString = alert.textFields.firstObject.text;
        NSURL *mediaURL = [NSURL URLWithString:urlString];
        if (!mediaURL) return;

        NSURLSessionDownloadTask *task = [[NSURLSession sharedSession] downloadTaskWithURL:mediaURL completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
            if (error) return;

            NSString *fileExt = response.suggestedFilename.pathExtension.lowercaseString;
            NSData *data = [NSData dataWithContentsOfURL:location];

            if ([fileExt isEqualToString:@"jpg"] || [fileExt isEqualToString:@"png"]) {
                UIImage *image = [UIImage imageWithData:data];
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
    }];

    [alert addAction:download];
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];

    dispatch_async(dispatch_get_main_queue(), ^{
        [UIWindow *window = nil; if (@available(iOS 13.0, *)) {     for (UIWindowScene* scene in [UIApplication sharedApplication].connectedScenes) {         if (scene.activationState == UISceneActivationStateForegroundActive) {             window = scene.windows.firstObject;             break;         }     } } else {     window = [UIApplication sharedApplication].keyWindow; } UIViewController *rootVC = window.rootViewController; presentViewController:alert animated:YES completion:nil];
    });
}

@end


%ctor {
    if (@available(iOS 16.0, *)) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *window = [UIApplication sharedApplication].keyWindow;
            CustomPopupView *popup = [[CustomPopupView alloc] initWithFrame:window.bounds];
            popup.alpha = 0.0;
            [window addSubview:popup];

            [UIView animateWithDuration:0.4 animations:^{
                popup.alpha = 1.0;
            }];
        });
    } else {
        NSLog(@"❌ هذه الأداة تعمل فقط على iOS 16 وأعلى.");
    }
}
