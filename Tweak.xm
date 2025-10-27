#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>

%hook UIView

// ✅ التصريحات المسبقة (Prototypes)
%new - (void)__sg_addDownloadButton;
%new - (void)__sg_handleDownloadTap;
%new - (void)__sg_saveImageToPhotos:(UIImage *)image;
%new - (void)__sg_image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo;
%new - (void)__sg_saveVideoToPhotos:(NSURL *)videoURL;
%new - (void)__sg_showHUD:(NSString *)text;
%new - (void)__sg_showAlertWithTitle:(NSString *)title message:(NSString *)message;

// ⬇️ إضافة زر التحميل
- (void)didMoveToWindow {
    %orig;
    if ([self isKindOfClass:[UIImageView class]] || [self.layer isKindOfClass:[AVPlayerLayer class]]) {
        [self __sg_addDownloadButton];
    }
}

// ⬇️ دالة إنشاء الزر
- (void)__sg_addDownloadButton {
    UIButton *downloadButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [downloadButton setTitle:@"⬇️" forState:UIControlStateNormal];
    downloadButton.frame = CGRectMake(self.bounds.size.width - 50, 10, 40, 40);
    downloadButton.tintColor = [UIColor whiteColor];
    downloadButton.layer.shadowColor = [UIColor blackColor].CGColor;
    downloadButton.layer.shadowOpacity = 0.3;
    downloadButton.layer.shadowOffset = CGSizeMake(1, 1);
    downloadButton.layer.shadowRadius = 2;
    downloadButton.tag = 9999;
    [downloadButton addTarget:self action:@selector(__sg_handleDownloadTap) forControlEvents:UIControlEventTouchUpInside];

    dispatch_async(dispatch_get_main_queue(), ^{
        if (![self viewWithTag:9999]) {
            [self addSubview:downloadButton];
        }
    });
}

// ⬇️ عند الضغط على الزر
- (void)__sg_handleDownloadTap {
    NSLog(@"[SaveGram] Download button tapped");

    UIImageView *imageView = nil;
    AVPlayerLayer *playerLayer = nil;

    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:[UIImageView class]]) {
            imageView = (UIImageView *)sub;
        } else if ([sub.layer isKindOfClass:[AVPlayerLayer class]]) {
            playerLayer = (AVPlayerLayer *)sub.layer;
        }
    }

    if (imageView.image) {
        [self __sg_saveImageToPhotos:imageView.image];
    } else if (playerLayer.player.currentItem) {
        AVPlayerItem *item = playerLayer.player.currentItem;
        AVAsset *asset = item.asset;
        if ([asset isKindOfClass:[AVURLAsset class]]) {
            NSURL *url = [(AVURLAsset *)asset URL];
            [self __sg_saveVideoToPhotos:url];
        } else {
            [self __sg_saveVideoToPhotos:nil];
        }
    } else {
        [self __sg_showAlertWithTitle:@"SaveGram" message:@"No media detected."];
    }
}

// ⬇️ حفظ الصورة
- (void)__sg_saveImageToPhotos:(UIImage *)image {
    [self __sg_showHUD:@"Saving image..."];
    UIImageWriteToSavedPhotosAlbum(image, self, @selector(__sg_image:didFinishSavingWithError:contextInfo:), NULL);
}

- (void)__sg_image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    [self __sg_showHUD:(error ? @"❌ Failed to save image." : @"✅ Image Saved!")];
}

// ⬇️ حفظ الفيديو (مع اسم المستخدم)
- (void)__sg_saveVideoToPhotos:(NSURL *)videoURL {
    [self __sg_showHUD:@"Preparing video..."];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        AVAsset *asset = nil;

        if (videoURL && [videoURL isFileURL]) {
            asset = [AVAsset assetWithURL:videoURL];
        } else if (videoURL) {
            NSData *videoData = [NSData dataWithContentsOfURL:videoURL];
            if (videoData) {
                NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"savegram_temp.mp4"];
                [videoData writeToFile:tempPath atomically:YES];
                asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:tempPath]];
            }
        } else if ([self.layer isKindOfClass:[AVPlayerLayer class]]) {
            AVPlayerLayer *playerLayer = (AVPlayerLayer *)self.layer;
            if (playerLayer.player.currentItem) asset = playerLayer.player.currentItem.asset;
        }

        if (!asset) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self __sg_showHUD:@"❌ No video asset found."];
            });
            return;
        }

        // 🔤 اسم المستخدم
        NSString *username = nil;
        UIResponder *responder = self;
        while (responder) {
            if ([responder respondsToSelector:@selector(username)]) {
                username = [responder performSelector:@selector(username)];
                break;
            }
            responder = [responder nextResponder];
        }

        if (!username || username.length == 0) {
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setDateFormat:@"yyyyMMdd_HHmmss"];
            username = [NSString stringWithFormat:@"user_%@", [formatter stringFromDate:[NSDate date]]];
        }

        NSString *filename = [NSString stringWithFormat:@"%@.mp4", username];
        NSString *outputPath = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
        NSURL *outputURL = [NSURL fileURLWithPath:outputPath];

        if ([[NSFileManager defaultManager] fileExistsAtPath:outputPath]) {
            [[NSFileManager defaultManager] removeItemAtPath:outputPath error:nil];
        }

        AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPresetHighestQuality];
        exportSession.outputURL = outputURL;
        exportSession.outputFileType = AVFileTypeMPEG4;

        [exportSession exportAsynchronouslyWithCompletionHandler:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                if (exportSession.status == AVAssetExportSessionStatusCompleted) {
                    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                        [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:outputURL];
                    } completionHandler:^(BOOL success, NSError * _Nullable error) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (success) {
                                [self __sg_showHUD:[NSString stringWithFormat:@"✅ Saved as %@", filename]];
                            } else {
                                NSString *msg = error ? error.localizedDescription : @"❌ Failed to save video.";
                                [self __sg_showAlertWithTitle:@"SaveGram" message:msg];
                            }
                        });
                    }];
                } else {
                    NSString *errorMsg = exportSession.error.localizedDescription ?: @"Export failed.";
                    [self __sg_showAlertWithTitle:@"SaveGram" message:[NSString stringWithFormat:@"❌ %@", errorMsg]];
                }
            });
        }];
    });
}

// ⬇️ HUD و Alerts
- (void)__sg_showHUD:(NSString *)text {
    dispatch_async(dispatch_get_main_queue(), ^{
        UILabel *hud = [self viewWithTag:7777];
        if (!hud) {
            hud = [[UILabel alloc] initWithFrame:CGRectMake(20, self.bounds.size.height - 80, self.bounds.size.width - 40, 40)];
            hud.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
            hud.textColor = [UIColor whiteColor];
            hud.textAlignment = NSTextAlignmentCenter;
            hud.layer.cornerRadius = 8;
            hud.clipsToBounds = YES;
            hud.tag = 7777;
            [self addSubview:hud];
        }
        hud.text = text;
        hud.alpha = 1.0;

        [UIView animateWithDuration:0.5 delay:2.0 options:0 animations:^{
            hud.alpha = 0.0;
        } completion:nil];
    });
}

- (void)__sg_showAlertWithTitle:(NSString *)title message:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
        [alert addAction:ok];
        UIViewController *root = UIApplication.sharedApplication.keyWindow.rootViewController;
        [root presentViewController:alert animated:YES completion:nil];
    });
}

%end
