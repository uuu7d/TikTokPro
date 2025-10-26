#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <AVKit/AVKit.h>

@interface SandboxTool : NSObject <UIDocumentPickerDelegate>
@property (nonatomic, strong) UIDocumentPickerViewController *picker;
@end

@implementation SandboxTool

- (void)openFilePicker {
    self.picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[[UTType data]]];
    self.picker.delegate = self;
    self.picker.allowsMultipleSelection = NO;

    UIWindow *window = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                window = scene.windows.firstObject;
                break;
            }
        }
    } else {
        window = [UIApplication sharedApplication].keyWindow;
    }
    if (!window) return;

    [window.rootViewController presentViewController:self.picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *fileURL = urls.firstObject;
    if (!fileURL) return;

    NSString *filePath = [fileURL path];
    NSLog(@"[SandboxTool] File selected: %@", filePath);

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"📂 تم اختيار ملف"
                                                                   message:filePath
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *ok = [UIAlertAction actionWithTitle:@"موافق" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:ok];

    UIWindow *window = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                window = scene.windows.firstObject;
                break;
            }
        }
    } else {
        window = [UIApplication sharedApplication].keyWindow;
    }
    if (!window) return;

    [window.rootViewController presentViewController:alert animated:YES completion:nil];
}

@end

@interface SandboxViewController : UIViewController
@end

@implementation SandboxViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 150, self.view.bounds.size.width, 40)];
    titleLabel.text = @"Sandbox Tool";
    titleLabel.font = [UIFont boldSystemFontOfSize:30];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:titleLabel];

    UIButton *openButton = [UIButton buttonWithType:UIButtonTypeSystem];
    openButton.frame = CGRectMake((self.view.bounds.size.width - 200) / 2, 240, 200, 50);
    openButton.backgroundColor = [UIColor systemBlueColor];
    [openButton setTitle:@"اختر ملف 📂" forState:UIControlStateNormal];
    [openButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    openButton.layer.cornerRadius = 12;
    [openButton addTarget:self action:@selector(openDocumentPicker) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:openButton];

    UIButton *downloadButton = [UIButton buttonWithType:UIButtonTypeSystem];
    downloadButton.frame = CGRectMake((self.view.bounds.size.width - 200) / 2, 310, 200, 50);
    downloadButton.backgroundColor = [UIColor systemGreenColor];
    [downloadButton setTitle:@"تحميل المحتوى 📥" forState:UIControlStateNormal];
    [downloadButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    downloadButton.layer.cornerRadius = 12;
    [downloadButton addTarget:self action:@selector(downloadCurrentMedia) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:downloadButton];

    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.frame = CGRectMake((self.view.bounds.size.width - 200) / 2, 380, 200, 50);
    closeButton.backgroundColor = [UIColor systemRedColor];
    [closeButton setTitle:@"إغلاق ❌" forState:UIControlStateNormal];
    [closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeButton.layer.cornerRadius = 12;
    [closeButton addTarget:self action:@selector(closeSelf) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:closeButton];
}

- (void)openDocumentPicker {
    SandboxTool *tool = [SandboxTool new];
    [tool openFilePicker];
}

- (void)downloadCurrentMedia {
    // مثال: حفظ صورة أو فيديو معروض على الشاشة
    UIWindow *window = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                window = scene.windows.firstObject;
                break;
            }
        }
    } else {
        window = [UIApplication sharedApplication].keyWindow;
    }
    if (!window) return;

    UIImageView *imageView = nil;
    for (UIView *subview in window.rootViewController.view.subviews) {
        if ([subview isKindOfClass:[UIImageView class]]) {
            imageView = (UIImageView *)subview;
            break;
        }
    }

    if (imageView.image) {
        UIImageWriteToSavedPhotosAlbum(imageView.image, nil, nil, nil);
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"✅ تم الحفظ"
                                                                       message:@"تم حفظ الصورة في ألبوم الصور"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"موافق" style:UIAlertActionStyleDefault handler:nil]];
        [window.rootViewController presentViewController:alert animated:YES completion:nil];
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"⚠️ خطأ"
                                                                       message:@"لا يوجد محتوى يمكن حفظه"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"موافق" style:UIAlertActionStyleDefault handler:nil]];
        [window.rootViewController presentViewController:alert animated:YES completion:nil];
    }
}

- (void)closeSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

// تفعيل الأداة عند فتح التطبيق
%hook UIApplication
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL result = %orig;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *window = nil;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    window = scene.windows.firstObject;
                    break;
                }
            }
        } else {
            window = [UIApplication sharedApplication].keyWindow;
        }
        if (!window) return;

        SandboxViewController *vc = [SandboxViewController new];
        vc.modalPresentationStyle = UIModalPresentationOverFullScreen;
        vc.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        [window.rootViewController presentViewController:vc animated:YES completion:nil];
    });

    return result;
}
%end
