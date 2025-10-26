#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <AVFoundation/AVFoundation.h>
#import <WebKit/WebKit.h>

#pragma mark - SandboxTool Interface
@interface SandboxTool : NSObject
@property (nonatomic, strong) UIDocumentPickerViewController *picker;
- (void)openFilePicker;
- (void)startAutoSave;
@end

#pragma mark - SandboxTool Implementation
@implementation SandboxTool

#pragma mark - فتح ملف يدويًا
- (void)openFilePicker {
    if (@available(iOS 14.0, *)) {
        self.picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[[UTType item]]];
    } else {
        self.picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.data"] inMode:UIDocumentPickerModeOpen];
    }
    self.picker.delegate = (id)self;
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

    [window.rootViewController presentViewController:self.picker animated:YES completion:nil];
}

#pragma mark - حفظ تلقائي للصور والفيديوهات
- (void)startAutoSave {
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

    [self scanViewForContent:window.rootViewController.view];
}

- (void)scanViewForContent:(UIView *)view {
    static NSMutableSet *processedViews;
    if (!processedViews) processedViews = [NSMutableSet new];

    // صور
    if ([view isKindOfClass:[UIImageView class]] && ((UIImageView *)view).image && ![processedViews containsObject:view]) {
        UIImageView *imgView = (UIImageView *)view;
        NSData *imageData = UIImagePNGRepresentation(imgView.image);
        NSString *fileName = [NSString stringWithFormat:@"auto_image_%@.png", [[NSUUID UUID] UUIDString]];
        NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:fileName];
        [imageData writeToFile:path atomically:YES];
        [processedViews addObject:view];
        [self showAlertWithTitle:@"✅ تم حفظ صورة تلقائيًا" message:path];
    }

    // فيديوهات AVPlayer
    if ([view.layer isKindOfClass:[AVPlayerLayer class]] && ![processedViews containsObject:view]) {
        AVPlayerLayer *playerLayer = (AVPlayerLayer *)view.layer;
        AVAsset *asset = playerLayer.player.currentItem.asset;
        if ([asset isKindOfClass:[AVURLAsset class]]) {
            AVURLAsset *urlAsset = (AVURLAsset *)asset;
            NSURL *videoURL = urlAsset.URL;
            NSData *videoData = [NSData dataWithContentsOfURL:videoURL];
            if (videoData) {
                NSString *fileName = [NSString stringWithFormat:@"auto_video_%@.mp4", [[NSUUID UUID] UUIDString]];
                NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:fileName];
                [videoData writeToFile:path atomically:YES];
                [processedViews addObject:view];
                [self showAlertWithTitle:@"✅ تم حفظ فيديو تلقائيًا" message:path];
            }
        }
    }

    // فيديوهات WKWebView
    if ([view isKindOfClass:[WKWebView class]] && ![processedViews containsObject:view]) {
        WKWebView *webView = (WKWebView *)view;
        [webView evaluateJavaScript:@"document.querySelector('video').src" completionHandler:^(id _Nullable result, NSError * _Nullable error) {
            if (result && [result isKindOfClass:[NSString class]]) {
                NSURL *videoURL = [NSURL URLWithString:(NSString *)result];
                NSData *videoData = [NSData dataWithContentsOfURL:videoURL];
                if (videoData) {
                    NSString *fileName = [NSString stringWithFormat:@"auto_webvideo_%@.mp4", [[NSUUID UUID] UUIDString]];
                    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:fileName];
                    [videoData writeToFile:path atomically:YES];
                    [processedViews addObject:view];
                    [self showAlertWithTitle:@"✅ تم حفظ فيديو Web تلقائيًا" message:path];
                }
            }
        }];
    }

    for (UIView *sub in view.subviews) {
        [self scanViewForContent:sub];
    }
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
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

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"موافق" style:UIAlertActionStyleDefault handler:nil]];
    [window.rootViewController presentViewController:alert animated:YES completion:nil];
}

@end

#pragma mark - SandboxViewController
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
    [openButton addTarget:self action:@selector(openFile) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:openButton];

    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.frame = CGRectMake((self.view.bounds.size.width - 200) / 2, 310, 200, 50);
    closeButton.backgroundColor = [UIColor systemRedColor];
    [closeButton setTitle:@"إغلاق ❌" forState:UIControlStateNormal];
    [closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeButton.layer.cornerRadius = 12;
    [closeButton addTarget:self action:@selector(closeSelf) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:closeButton];
}

- (void)openFile {
    SandboxTool *tool = [SandboxTool new];
    [tool openFilePicker];
}

- (void)closeSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

#pragma mark - UIApplication Hook
%hook UIApplication

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL result = %orig;

    // عرض الواجهة بعد ثانية واحدة
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
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

        // بدء الحفظ التلقائي
        SandboxTool *tool = [SandboxTool new];
        [tool startAutoSave];
    });

    return result;
}

%end
