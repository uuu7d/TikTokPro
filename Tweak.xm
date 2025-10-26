#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <Photos/Photos.h>
#import <MobileCoreServices/MobileCoreServices.h>

@interface FileManagerViewController : UIViewController <UIDocumentPickerDelegate>
@end

@implementation FileManagerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    UIButton *openPickerButton = [UIButton buttonWithType:UIButtonTypeSystem];
    openPickerButton.frame = CGRectMake(50, 100, 300, 50);
    [openPickerButton setTitle:@"اختر ملف" forState:UIControlStateNormal];
    [openPickerButton addTarget:self action:@selector(openDocumentPicker) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:openPickerButton];

    UIButton *saveMediaButton = [UIButton buttonWithType:UIButtonTypeSystem];
    saveMediaButton.frame = CGRectMake(50, 180, 300, 50);
    [saveMediaButton setTitle:@"حفظ محتوى مرئي" forState:UIControlStateNormal];
    [saveMediaButton addTarget:self action:@selector(saveMedia) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:saveMediaButton];
}

#pragma mark - Document Picker

- (void)openDocumentPicker {
    UTType *fileType = UTTypeData; // يدعم جميع أنواع الملفات
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
    // مثال: حفظ صورة من URL
    NSURL *mediaURL = [NSURL URLWithString:@"https://example.com/sample.jpg"]; // ضع هنا رابط الصورة أو الفيديو

    NSURLSessionDownloadTask *downloadTask = [[NSURLSession sharedSession] downloadTaskWithURL:mediaURL completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"حدث خطأ أثناء التنزيل: %@", error.localizedDescription);
            return;
        }

        NSString *fileExtension = response.suggestedFilename.pathExtension.lowercaseString;

        if ([fileExtension isEqualToString:@"jpg"] || [fileExtension isEqualToString:@"png"]) {
            // حفظ الصورة في مكتبة الصور
            NSData *data = [NSData dataWithContentsOfURL:location];
            UIImage *image = [UIImage imageWithData:data];
            if (image) {
                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                    [PHAssetChangeRequest creationRequestForAssetFromImage:image];
                } completionHandler:^(BOOL success, NSError * _Nullable error) {
                    if (success) {
                        NSLog(@"تم حفظ الصورة بنجاح");
                    } else {
                        NSLog(@"فشل حفظ الصورة: %@", error.localizedDescription);
                    }
                }];
            }
        } else if ([fileExtension isEqualToString:@"mp4"] || [fileExtension isEqualToString:@"mov"]) {
            // حفظ الفيديو
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:location];
            } completionHandler:^(BOOL success, NSError * _Nullable error) {
                if (success) {
                    NSLog(@"تم حفظ الفيديو بنجاح");
                } else {
                    NSLog(@"فشل حفظ الفيديو: %@", error.localizedDescription);
                }
            }];
        } else {
            NSLog(@"نوع الملف غير مدعوم للحفظ");
        }
    }];

    [downloadTask resume];
}

@end
