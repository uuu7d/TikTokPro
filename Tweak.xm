#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>

@interface SandboxViewController : UIViewController
@end

@implementation SandboxViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];

    // عنوان
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 150, self.view.bounds.size.width, 40)];
    titleLabel.text = @"Sandbox Tool";
    titleLabel.font = [UIFont boldSystemFontOfSize:30];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:titleLabel];

    // زر اختيار ملف
    UIButton *openButton = [UIButton buttonWithType:UIButtonTypeSystem];
    openButton.frame = CGRectMake((self.view.bounds.size.width - 200)/2, 240, 200, 50);
    openButton.backgroundColor = [UIColor systemBlueColor];
    [openButton setTitle:@"اختر ملف 📂" forState:UIControlStateNormal];
    [openButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    openButton.layer.cornerRadius = 12;
    [openButton addTarget:self action:@selector(openDocumentPicker) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:openButton];

    // زر تحميل صورة/فيديو
    UIButton *downloadButton = [UIButton buttonWithType:UIButtonTypeSystem];
    downloadButton.frame = CGRectMake((self.view.bounds.size.width - 200)/2, 310, 200, 50);
    downloadButton.backgroundColor = [UIColor systemGreenColor];
    [downloadButton setTitle:@"تحميل محتوى 📥" forState:UIControlStateNormal];
    [downloadButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    downloadButton.layer.cornerRadius = 12;
    [downloadButton addTarget:self action:@selector(downloadContent) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:downloadButton];

    // زر إغلاق
    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.frame = CGRectMake((self.view.bounds.size.width - 200)/2, 380, 200, 50);
    closeButton.backgroundColor = [UIColor systemRedColor];
    [closeButton setTitle:@"إغلاق ❌" forState:UIControlStateNormal];
    [closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeButton.layer.cornerRadius = 12;
    [closeButton addTarget:self action:@selector(closeSelf) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:closeButton];
}

- (void)openDocumentPicker {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[[UTType data]]];
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

// عند اختيار ملف
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *fileURL = urls.firstObject;
    if (!fileURL) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"📂 تم اختيار ملف"
                                                                   message:[fileURL path]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"موافق" style:UIAlertActionStyleDefault handler:nil]];

    UIWindow *window = nil;
    for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive) {
            window = scene.windows.firstObject;
            break;
        }
    }
    if (window) {
        [window.rootViewController presentViewController:alert animated:YES completion:nil];
    }
}

// تحميل محتوى مرئي (صورة/فيديو)
- (void)downloadContent {
    // مثال: تنزيل صورة عشوائية من رابط (يمكن تعديل الرابط)
    NSURL *url = [NSURL URLWithString:@"https://example.com/image.jpg"];
    NSData *data = [NSData dataWithContentsOfURL:url];
    if (!data) return;

    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        PHAssetResourceCreationOptions *options = [PHAssetResourceCreationOptions new];
        PHAssetCreationRequest *req = [PHAssetCreationRequest creationRequestForAsset];
        [req addResourceWithType:PHAssetResourceTypePhoto data:data options:options];
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *msg = success ? @"✅ تم تنزيل المحتوى" : [NSString stringWithFormat:@"❌ فشل التنزيل: %@", error.localizedDescription];
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"تحميل محتوى" message:msg preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"موافق" style:UIAlertActionStyleDefault handler:nil]];

            UIWindow *window = nil;
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    window = scene.windows.firstObject;
                    break;
                }
            }
            if (window) {
                [window.rootViewController presentViewController:alert animated:YES completion:nil];
            }
        });
    }];
}

// إغلاق النافذة
- (void)closeSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

%hook UIApplication

- (void)applicationDidBecomeActive:(UIApplication *)application {
    %orig;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIWindow *window = nil;
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                window = scene.windows.firstObject;
                break;
            }
        }
        if (!window) return;

        SandboxViewController *vc = [SandboxViewController new];
        vc.modalPresentationStyle = UIModalPresentationOverFullScreen;
        vc.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [window.rootViewController presentViewController:vc animated:YES completion:nil];
        });
    });
}

%end
