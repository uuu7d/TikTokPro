#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface SandboxTool : NSObject <UIDocumentPickerDelegate>
@property (nonatomic, strong) UIDocumentPickerViewController *picker;
@end

@implementation SandboxTool

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

    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.frame = CGRectMake((self.view.bounds.size.width - 200) / 2, 310, 200, 50);
    closeButton.backgroundColor = [UIColor systemRedColor];
    [closeButton setTitle:@"إغلاق ❌" forState:UIControlStateNormal];
    [closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeButton.layer.cornerRadius = 12;
    [closeButton addTarget:self action:@selector(closeSelf) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:closeButton];
}

- (void)openFilePicker {
    // إصلاح مشكلة UTType
    self.picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[[UTType item]]];
    self.picker.delegate = self;
    self.picker.allowsMultipleSelection = NO;

    UIWindow *window = [UIApplication sharedApplication].connectedScenes.allObjects.firstObject.windows.firstObject;
    UIViewController *rootVC = window.rootViewController;
    [rootVC presentViewController:self.picker animated:YES completion:nil];
}

// عند اختيار ملف
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

    UIWindow *window = [UIApplication sharedApplication].connectedScenes.allObjects.firstObject.windows.firstObject;
    [window.rootViewController presentViewController:alert animated:YES completion:nil];
}

@end

%hook UIApplication
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL result = %orig;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        SandboxTool *tool = [SandboxTool new];
        [tool openFilePicker];
    });

    return result;
}
%end

// ✅ الدالة التي تُظهر الواجهة داخل التطبيق المستهدف
%hook UIApplication

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
