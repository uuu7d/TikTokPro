#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <Photos/Photos.h>
#import <MobileCoreServices/MobileCoreServices.h>

@interface FileManagerViewController : UIViewController <UIDocumentPickerDelegate>
@end

@implementation FileManagerViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // خلفية ضبابية
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.frame = self.view.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:blurView];

    // ألوان الخلفية نصف شفافة
    self.view.backgroundColor = [[UIColor systemBackgroundColor] colorWithAlphaComponent:0.8];

    // أزرار
    NSArray *titles = @[@"اختر ملف", @"حفظ محتوى مرئي", @"فتح Telegram", @"فتح Snapchat", @"تنظيف الكاش", @"إعادة تشغيل التطبيق"];
    SEL selectors[] = {@selector(openDocumentPicker), @selector(saveMedia), @selector(openTelegram), @selector(openSnapchat), @selector(cleanCache), @selector(restartApp)};

    for (int i = 0; i < titles.count; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.frame = CGRectMake(50, 100 + i*70, 300, 50);
        [button setTitle:titles[i] forState:UIControlStateNormal];
        button.backgroundColor = [UIColor systemBlueColor];
        button.layer.cornerRadius = 10;
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [button addTarget:self action:selectors[i] forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:button];
    }
}

#pragma mark - Document Picker

- (void)openDocumentPicker {
    UTType *fileType = UTTypeData; // يدعم جميع الملفات
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[fileType]];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;

    UIWindow *window = nil;
    for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive) {
            window = scene.windows.firstObject;
            break;
        }
    }

    if (window) {
        [window.rootViewController presentViewController:picker animated:YES completion:nil];
    }
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if (urls.count > 0) {
        NSURL *selectedFile = urls.firstObject;
        NSLog(@"تم اختيار الملف: %@", selectedFile.path);

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"تم اختيار الملف"
                                                                       message:selectedFile.path
                                                                preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *ok = [UIAlertAction actionWithTitle:@"موافق" style:UIAlertActionStyleDefault handler:nil];
        UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil];
        [alert addAction:ok];
        [alert addAction:cancel];

        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    NSLog(@"تم إلغاء اختيار الملف");
}

#pragma mark - حفظ محتوى مرئي

- (void)saveMedia {
    // مثال: حفظ صورة أو فيديو من رابط
    NSURL *mediaURL = [NSURL URLWithString:@"https://example.com/sample.jpg"]; // ضع رابطك هنا

    NSURLSessionDownloadTask *downloadTask = [[NSURLSession sharedSession] downloadTaskWithURL:mediaURL completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"حدث خطأ أثناء التنزيل: %@", error.localizedDescription);
            return;
        }

        NSString *fileExtension = response.suggestedFilename.pathExtension.lowercaseString;

        if ([fileExtension isEqualToString:@"jpg"] || [fileExtension isEqualToString:@"png"]) {
            NSData *data = [NSData dataWithContentsOfURL:location];
            UIImage *image = [UIImage imageWithData:data];
            if (image) {
                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                    [PHAssetChangeRequest creationRequestForAssetFromImage:image];
                } completionHandler:^(BOOL success, NSError * _Nullable error) {
                    NSLog(success ? @"تم حفظ الصورة بنجاح" : @"فشل حفظ الصورة");
                }];
            }
        } else if ([fileExtension isEqualToString:@"mp4"] || [fileExtension isEqualToString:@"mov"]) {
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:location];
            } completionHandler:^(BOOL success, NSError * _Nullable error) {
                NSLog(success ? @"تم حفظ الفيديو بنجاح" : @"فشل حفظ الفيديو");
            }];
        } else {
            NSLog(@"نوع الملف غير مدعوم للحفظ");
        }
    }];

    [downloadTask resume];
}

#pragma mark - وظائف إضافية

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
    NSError *error = nil;
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tempPath error:&error];
    if (error) { NSLog(@"خطأ: %@", error); return; }

    for (NSString *file in files) {
        NSString *fullPath = [tempPath stringByAppendingPathComponent:file];
        [[NSFileManager defaultManager] removeItemAtPath:fullPath error:nil];
    }

    NSLog(@"تم تنظيف الكاش");
}

- (void)restartApp {
    UIWindow *window = [UIApplication sharedApplication].windows.firstObject;
    if (window) {
        window.rootViewController = [[FileManagerViewController alloc] init];
    }
}

@end

%hook UIApplication

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    %orig;

    if (@available(iOS 16, *)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            FileManagerViewController *vc = [[FileManagerViewController alloc] init];
            UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
            window.rootViewController = vc;
            [window makeKeyAndVisible];
        });
    }

    return YES;
}

%end