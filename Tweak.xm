#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <AVFoundation/AVFoundation.h>
#import <WebKit/WebKit.h>

#pragma mark - SandboxTool Interface

@interface SandboxTool : NSObject <UIDocumentPickerDelegate>
@property (nonatomic, strong) UIDocumentPickerViewController *picker;
- (void)openFilePicker;
@end

#pragma mark - SandboxTool Implementation

@implementation SandboxTool

- (void)openFilePicker {
    if (@available(iOS 14.0, *)) {
        self.picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[[UTType item]]];
    } else {
        self.picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.data"] inMode:UIDocumentPickerModeOpen];
    }
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

// UIDocumentPickerDelegate
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

#pragma mark - SandboxViewController Interface

@interface SandboxViewController : UIViewController
@end

#pragma mark - SandboxViewController Implementation

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

    // زر فتح الملفات
    UIButton *openButton = [UIButton buttonWithType:UIButtonTypeSystem];
    openButton.frame = CGRectMake((self.view.bounds.size.width - 200)/2, 240, 200, 50);
    openButton.backgroundColor = [UIColor systemBlueColor];
    [openButton setTitle:@"اختر ملف 📂" forState:UIControlStateNormal];
    [openButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    openButton.layer.cornerRadius = 12;
    [openButton addTarget:self action:@selector(openDocumentPicker) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:openButton];

    // زر تنزيل المحتوى
    UIButton *downloadButton = [UIButton buttonWithType:UIButtonTypeSystem];
    downloadButton.frame = CGRectMake((self.view.bounds.size.width - 200)/2, 310, 200, 50);
    downloadButton.backgroundColor = [UIColor systemGreenColor];
    [downloadButton setTitle:@"تنزيل محتوى 📥" forState:UIControlStateNormal];
    [downloadButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    downloadButton.layer.cornerRadius = 12;
    [downloadButton addTarget:self action:@selector(downloadCurrentContent) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:downloadButton];

    // زر إغلاق الواجهة
    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.frame = CGRectMake((self.view.bounds.size.width - 200)/2, 380, 200, 50);
    closeButton.backgroundColor = [UIColor systemRedColor];
    [closeButton setTitle:@"إغلاق ❌" forState:UIControlStateNormal];
    [closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeButton.layer.cornerRadius = 12;
    [closeButton addTarget:self action:@selector(closeSelf) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:closeButton];
}

#pragma mark - Actions

- (void)openDocumentPicker {
    SandboxTool *tool = [SandboxTool new];
    [tool openFilePicker];
}

- (void)downloadCurrentContent {
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

    // تنزيل الصور
    UIImageView *imageView = [self findImageViewInView:window.rootViewController.view];
    if (imageView && imageView.image) {
        NSData *imageData = UIImagePNGRepresentation(imageView.image);
        NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject
                          stringByAppendingPathComponent:@"downloaded_image.png"];
        [imageData writeToFile:path atomically:YES];
        [self showAlertWithTitle:@"✅ تم تنزيل الصورة" message:path];
        return;
    }

    // تنزيل الفيديو من AVPlayer
    AVPlayerLayer *playerLayer = [self findPlayerLayerInView:window.rootViewController.view];
    AVPlayer *player = playerLayer.player;
    AVAsset *asset = player.currentItem.asset;
    if ([asset isKindOfClass:[AVURLAsset class]]) {
        AVURLAsset *urlAsset = (AVURLAsset *)asset;
        NSURL *videoURL = urlAsset.URL;
        NSData *videoData = [NSData dataWithContentsOfURL:videoURL];
        if (videoData) {
            NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject
                              stringByAppendingPathComponent:@"downloaded_video.mp4"];
            [videoData writeToFile:path atomically:YES];
            [self showAlertWithTitle:@"✅ تم تنزيل الفيديو" message:path];
            return;
        }
    }

    // تنزيل الفيديو من WKWebView (HTML5)
    WKWebView *webView = [self findWebViewInView:window.rootViewController.view];
    if (webView) {
        [webView evaluateJavaScript:@"document.querySelector('video').src" completionHandler:^(id _Nullable result, NSError * _Nullable error) {
            if (result && [result isKindOfClass:[NSString class]]) {
                NSURL *videoURL = [NSURL URLWithString:(NSString *)result];
                NSData *videoData = [NSData dataWithContentsOfURL:videoURL];
                if (videoData) {
                    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject
                                      stringByAppendingPathComponent:@"downloaded_web_video.mp4"];
                    [videoData writeToFile:path atomically:YES];
                    [self showAlertWithTitle:@"✅ تم تنزيل الفيديو من WebView" message:path];
                } else {
                    [self showAlertWithTitle:@"⚠️ خطأ" message:@"فشل تنزيل الفيديو من WebView"];
                }
            }
        }];
        return;
    }

    [self showAlertWithTitle:@"⚠️ خطأ" message:@"لم يتم العثور على صورة أو فيديو لتنزيله"];
}

#pragma mark - Helper Methods

- (UIImageView *)findImageViewInView:(UIView *)view {
    if ([view isKindOfClass:[UIImageView class]]) return (UIImageView *)view;
    for (UIView *subview in view.subviews) {
        UIImageView *found = [self findImageViewInView:subview];
        if (found) return found;
    }
    return nil;
}

- (AVPlayerLayer *)findPlayerLayerInView:(UIView *)view {
    if ([view.layer isKindOfClass:[AVPlayerLayer class]]) return (AVPlayerLayer *)view.layer;
    for (UIView *subview in view.subviews) {
        AVPlayerLayer *found = [self findPlayerLayerInView:subview];
        if (found) return found;
    }
    return nil;
}

- (WKWebView *)findWebViewInView:(UIView *)view {
    if ([view isKindOfClass:[WKWebView class]]) return (WKWebView *)view;
    for (UIView *subview in view.subviews) {
        WKWebView *found = [self findWebViewInView:subview];
        if (found) return found;
    }
    return nil;
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *ok = [UIAlertAction actionWithTitle:@"موافق" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:ok];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)closeSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

#pragma mark - Hooks

%hook UIApplication

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL result = %orig;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        SandboxTool *tool = [SandboxTool new];
        [tool openFilePicker];
    });

    return result;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    %orig;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
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

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [window.rootViewController presentViewController:vc animated:YES completion:nil];
        });
    });
}

%end
