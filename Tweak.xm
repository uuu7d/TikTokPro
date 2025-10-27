#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>

@interface FileManagerViewController : UIViewController <UIDocumentPickerDelegate>
@end

@implementation FileManagerViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // الخلفية الضبابية
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.frame = self.view.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:blurView];

    self.view.backgroundColor = [[UIColor systemBackgroundColor] colorWithAlphaComponent:0.75];

    // عناوين الأزرار والعمليات المقابلة
    NSArray *titles = @[
        @"📁 اختر ملف",
        @"💾 حفظ محتوى مرئي",
        @"📨 فتح Telegram",
        @"👻 فتح Snapchat",
        @"🧹 تنظيف الكاش",
        @"🔄 إعادة تشغيل التطبيق"
    ];

    SEL selectors[] = {
        @selector(openDocumentPicker),
        @selector(saveVisibleMedia),
        @selector(openTelegram),
        @selector(openSnapchat),
        @selector(cleanCache),
        @selector(restartApp)
    };

    CGFloat yOffset = 120;
    for (int i = 0; i < titles.count; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.frame = CGRectMake(50, yOffset + i*65, UIScreen.mainScreen.bounds.size.width - 100, 50);
        [button setTitle:titles[i] forState:UIControlStateNormal];
        button.backgroundColor = [UIColor systemBlueColor];
        button.layer.cornerRadius = 12;
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont boldSystemFontOfSize:18];
        [button addTarget:self action:selectors[i] forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:button];
    }
}

#pragma mark - Document Picker

- (void)openDocumentPicker {
    UTType *fileType = UTTypeData;
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[fileType]];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;

    UIWindow *window = UIApplication.sharedApplication.connectedScenes.anyObject.windows.firstObject;
    [window.rootViewController presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if (urls.count == 0) return;

    NSURL *selectedFile = urls.firstObject;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"📄 تم اختيار الملف"
                                                                   message:selectedFile.path
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"موافق" style:UIAlertActionStyleDefault handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - حفظ المحتوى المرئي (صورة أو فيديو معروض على الشاشة)

- (void)saveVisibleMedia {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = UIApplication.sharedApplication.windows.firstObject;
        UIViewController *rootVC = window.rootViewController;
        UIView *rootView = rootVC.view;

        NSMutableArray<UIImage *> *images = [NSMutableArray array];

        for (UIView *subview in rootView.subviews) {
            if ([subview isKindOfClass:[UIImageView class]]) {
                UIImageView *imgView = (UIImageView *)subview;
                if (imgView.image) {
                    [images addObject:imgView.image];
                }
            }
        }

        if (images.count > 0) {
            for (UIImage *img in images) {
                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                    [PHAssetChangeRequest creationRequestForAssetFromImage:img];
                } completionHandler:^(BOOL success, NSError * _Nullable error) {
                    NSLog(success ? @"✅ تم حفظ الصورة من واجهة التطبيق" : @"❌ فشل حفظ الصورة");
                }];
            }

            [self showToast:@"✅ تم حفظ الصور المعروضة بنجاح"];
        } else {
            // محاولة التقاط فيديو إذا كان هناك AVPlayerLayer ظاهر
            AVPlayerLayer *playerLayer = [self findAVPlayerLayerInView:rootView];
            if (playerLayer) {
                AVPlayerItem *item = playerLayer.player.currentItem;
                if (item && item.asset) {
                    [self exportAndSaveAVAsset:item.asset];
                }
            } else {
                [self showToast:@"⚠️ لم يتم العثور على صور أو فيديوهات حالية"];
            }
        }
    });
}

- (AVPlayerLayer *)findAVPlayerLayerInView:(UIView *)view {
    for (CALayer *layer in view.layer.sublayers) {
        if ([layer isKindOfClass:[AVPlayerLayer class]]) {
            return (AVPlayerLayer *)layer;
        }
    }
    for (UIView *subview in view.subviews) {
        AVPlayerLayer *result = [self findAVPlayerLayerInView:subview];
        if (result) return result;
    }
    return nil;
}

- (void)exportAndSaveAVAsset:(AVAsset *)asset {
    NSString *outputPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"capturedVideo.mp4"];
    NSURL *outputURL = [NSURL fileURLWithPath:outputPath];

    AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPresetHighestQuality];
    exportSession.outputFileType = AVFileTypeMPEG4;
    exportSession.outputURL = outputURL;

    [exportSession exportAsynchronouslyWithCompletionHandler:^{
        if (exportSession.status == AVAssetExportSessionStatusCompleted) {
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:outputURL];
            } completionHandler:^(BOOL success, NSError * _Nullable error) {
                NSLog(success ? @"✅ تم حفظ الفيديو من واجهة التطبيق" : @"❌ فشل حفظ الفيديو");
            }];
        }
    }];
}

#pragma mark - الوظائف الإضافية

- (void)openTelegram {
    NSURL *url = [NSURL URLWithString:@"tg://resolve?domain=YourUsername"];
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

- (void)openSnapchat {
    NSURL *url = [NSURL URLWithString:@"snapchat://add/YourUsername"];
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

- (void)cleanCache {
    NSString *tempPath = NSTemporaryDirectory();
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tempPath error:nil];
    NSUInteger totalRemoved = 0;

    for (NSString *file in files) {
        NSString *fullPath = [tempPath stringByAppendingPathComponent:file];
        if ([[NSFileManager defaultManager] removeItemAtPath:fullPath error:nil]) {
            totalRemoved++;
        }
    }

    NSString *msg = [NSString stringWithFormat:@"🧹 تم تنظيف %lu ملف مؤقت", (unsigned long)totalRemoved];
    [self showToast:msg];
}

- (void)restartApp {
    exit(0);
}

#pragma mark - مساعدات عرضية

- (void)showToast:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake(40, UIScreen.mainScreen.bounds.size.height - 150, UIScreen.mainScreen.bounds.size.width - 80, 50)];
        toast.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
        toast.textColor = [UIColor whiteColor];
        toast.textAlignment = NSTextAlignmentCenter;
        toast.layer.cornerRadius = 12;
        toast.layer.masksToBounds = YES;
        toast.text = message;
        toast.alpha = 0;
        [UIApplication.sharedApplication.keyWindow addSubview:toast];

        [UIView animateWithDuration:0.5 animations:^{
            toast.alpha = 1;
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.5 delay:2 options:0 animations:^{
                toast.alpha = 0;
            } completion:^(BOOL finished) {
                [toast removeFromSuperview];
            }];
        }];
    });
}

@end

%hook UIApplication

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL result = %orig;

    if (@available(iOS 16, *)) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
            window.rootViewController = [[FileManagerViewController alloc] init];
            [window makeKeyAndVisible];
        });
    }

    return result;
}

%end
