#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <AudioToolbox/AudioToolbox.h>

@interface SandboxTool : NSObject
- (void)openFilePicker;
- (void)downloadMediaFromView:(UIView *)view;
- (void)saveVideoFromPlayerItem:(AVPlayerItem *)playerItem;
@end

@implementation SandboxTool

- (void)playClickSound {
    AudioServicesPlaySystemSound(1104); // صوت النقر
}

- (void)openFilePicker {
    [self playClickSound];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeItem]];
    picker.allowsMultipleSelection = NO;

    UIWindow *window = nil;
    for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive) {
            window = scene.windows.firstObject;
            break;
        }
    }
    if (!window) return;

    [window.rootViewController presentViewController:picker animated:YES completion:nil];
}

- (void)downloadMediaFromView:(UIView *)view {
    [self playClickSound];

    if ([view isKindOfClass:[UIImageView class]]) {
        UIImage *image = ((UIImageView *)view).image;
        if (image) {
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                [PHAssetChangeRequest creationRequestForAssetFromImage:image];
            } completionHandler:^(BOOL success, NSError * _Nullable error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSString *msg = success ? @"✅ تم حفظ الصورة في ألبوم الصور" : @"❌ حدث خطأ أثناء الحفظ";
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Sandbox Tool"
                                                                                   message:msg
                                                                            preferredStyle:UIAlertControllerStyleAlert];
                    [alert addAction:[UIAlertAction actionWithTitle:@"موافق" style:UIAlertActionStyleDefault handler:nil]];

                    UIWindow *window = nil;
                    for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                        if (scene.activationState == UISceneActivationStateForegroundActive) {
                            window = scene.windows.firstObject;
                            break;
                        }
                    }
                    [window.rootViewController presentViewController:alert animated:YES completion:nil];
                });
            }];
        }
    } else {
        for (UIView *subview in view.subviews) {
            [self downloadMediaFromView:subview];
        }
    }
}

- (void)saveVideoFromPlayerItem:(AVPlayerItem *)playerItem {
    AVAsset *asset = playerItem.asset;
    if (![asset isKindOfClass:[AVURLAsset class]]) return;
    NSURL *url = ((AVURLAsset *)asset).URL;
    if (!url) return;

    PHPhotoLibrary *library = [PHPhotoLibrary sharedPhotoLibrary];
    [library performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:url];
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIWindow *window = nil;
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    window = scene.windows.firstObject;
                    break;
                }
            }
            if (!window) return;

            NSString *msg = success ? @"✅ تم حفظ الفيديو في ألبوم الصور" : @"❌ حدث خطأ أثناء الحفظ";
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Sandbox Tool"
                                                                           message:msg
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"موافق" style:UIAlertActionStyleDefault handler:nil]];
            [window.rootViewController presentViewController:alert animated:YES completion:nil];
        });
    }];
}

@end

@interface SandboxViewController : UIViewController
@end

@implementation SandboxViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    UIVisualEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.frame = self.view.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:blurView];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 150, self.view.bounds.size.width, 40)];
    titleLabel.text = @"Sandbox Tool";
    titleLabel.font = [UIFont boldSystemFontOfSize:30];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:titleLabel];

    UIButton *openButton = [UIButton buttonWithType:UIButtonTypeSystem];
    openButton.frame = CGRectMake((self.view.bounds.size.width-200)/2, 240, 200, 50);
    openButton.backgroundColor = [UIColor systemBlueColor];
    [openButton setTitle:@"اختر ملف 📂" forState:UIControlStateNormal];
    openButton.layer.cornerRadius = 12;
    [openButton addTarget:self action:@selector(openFilePickerAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:openButton];

    UIButton *downloadButton = [UIButton buttonWithType:UIButtonTypeSystem];
    downloadButton.frame = CGRectMake((self.view.bounds.size.width-200)/2, 310, 200, 50);
    downloadButton.backgroundColor = [UIColor systemGreenColor];
    [downloadButton setTitle:@"حفظ محتوى 🎬" forState:UIControlStateNormal];
    downloadButton.layer.cornerRadius = 12;
    [downloadButton addTarget:self action:@selector(downloadMediaAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:downloadButton];

    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.frame = CGRectMake((self.view.bounds.size.width-200)/2, 380, 200, 50);
    closeButton.backgroundColor = [UIColor systemRedColor];
    [closeButton setTitle:@"إغلاق ❌" forState:UIControlStateNormal];
    closeButton.layer.cornerRadius = 12;
    [closeButton addTarget:self action:@selector(closeSelf) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:closeButton];
}

- (void)openFilePickerAction {
    [[SandboxTool new] openFilePicker];
}

- (void)downloadMediaAction {
    [[SandboxTool new] downloadMediaFromView:self.view];
}

- (void)closeSelf {
    [[SandboxTool new] playClickSound];
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

// حقن Tweak
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

// Hook على AVPlayerItem لمراقبة أي فيديو يبدأ تشغيله
%hook AVPlayerItem

- (void)setStatus:(AVPlayerItemStatus)status {
    %orig;

    if (status == AVPlayerItemStatusReadyToPlay) {
        [[SandboxTool new] saveVideoFromPlayerItem:self];
    }
}

%end
