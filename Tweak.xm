#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

// مساعدة للحصول على root view controller بشكل آمن لكل iOS
UIViewController *getRootViewController() {
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                keyWindow = scene.windows.firstObject;
                break;
            }
        }
    } else {
        keyWindow = [UIApplication sharedApplication].keyWindow;
    }
    return keyWindow.rootViewController;
}

// فتح روابط خارجية
void openURL(NSString *urlString) {
    NSURL *url = [NSURL URLWithString:urlString];
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }
}

// عرض alert ترحيبي
void showWelcomeAlert() {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"مرحبا!" 
                                                                   message:@"أهلاً بك في التطبيق" 
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *telegram = [UIAlertAction actionWithTitle:@"فتح تيليجرام" 
                                                       style:UIAlertActionStyleDefault 
                                                     handler:^(UIAlertAction * _Nonnull action) {
        AudioServicesPlaySystemSound(1104); // صوت نقر
        openURL(@"tg://resolve?domain=YourTelegramID");
    }];
    UIAlertAction *snapchat = [UIAlertAction actionWithTitle:@"فتح سناب شات" 
                                                       style:UIAlertActionStyleDefault 
                                                     handler:^(UIAlertAction * _Nonnull action) {
        AudioServicesPlaySystemSound(1104);
        openURL(@"snapchat://add/YourSnapchatID");
    }];
    UIAlertAction *restartApp = [UIAlertAction actionWithTitle:@"إعادة تشغيل التطبيق" 
                                                         style:UIAlertActionStyleDestructive 
                                                       handler:^(UIAlertAction * _Nonnull action) {
        AudioServicesPlaySystemSound(1104);
        exit(0);
    }];

    [alert addAction:telegram];
    [alert addAction:snapchat];
    [alert addAction:restartApp];

    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *rootVC = getRootViewController();
        if (rootVC) {
            [rootVC presentViewController:alert animated:YES completion:nil];
        }
    });
}

// حفظ الصور والفيديوهات تلقائيًا
// يمكن تعديل هذا الجزء حسب مكان المحتوى الذي تريد حفظه
void saveMediaToCameraRoll(UIImage *image, NSURL *videoURL) {
    if (image) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
    }
    if (videoURL) {
        UISaveVideoAtPathToSavedPhotosAlbum([videoURL path], nil, nil, nil);
    }
}

// Hook عند فتح التطبيق
%hook UIApplication

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    %orig;

    // عرض النافذة الترحيبية
    showWelcomeAlert();

    return YES;
}

%end

// مثال: Hook على عرض صورة أو فيديو إذا كنت تريد الحفظ التلقائي
// %hook SomeViewController
// - (void)displayImage:(UIImage *)image {
//     %orig;
//     saveMediaToCameraRoll(image, nil);
// }
// %end
