#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>

#pragma mark - Category declarations (prototypes)

@interface UIView (SaveGram)
// UI
- (void)__sg_addDownloadButton;
- (void)__sg_handleDownloadTap;
- (void)__sg_presentSaveOptionsWithImage:(UIImage *)image asset:(AVAsset *)asset assetURL:(NSURL *)assetURL;

// Image
- (void)__sg_saveImageToPhotos:(UIImage *)image;
- (void)__sg_image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo;

// Video
- (void)__sg_saveVideoToPhotos:(NSURL *)videoURL asset:(AVAsset *)asset; // either URL or AVAsset-based
- (void)__sg_exportAsset:(AVAsset *)asset toFileURL:(NSURL *)outputURL completion:(void(^)(BOOL success, NSError *error))completion;

// Helpers
- (void)__sg_showHUD:(NSString *)text;
- (void)__sg_showAlertWithTitle:(NSString *)title message:(NSString *)message;
- (NSString *)__sg_resolveUsernameOrDefault;
@end


#pragma mark - Hook UIView implementation

%hook UIView

- (void)didMoveToWindow {
    %orig;

    // تأكد أن الـ view له نافذة وأنه في التطبيق المستهدف (مثلاً TikTok)
    if (!self.window) return;

    // تجاهل UISearchBar و UITextField لتجنب الكراش عند الضغط على مربع البحث
    if ([self isKindOfClass:[UISearchBar class]] || [self isKindOfClass:[UITextField class]]) {
        return;
    }

    // تأكد أن الـ view يحتوي على صورة أو فيديو (لتجنب التنفيذ العشوائي)
    BOOL hasMedia = NO;
    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:[UIImageView class]] || [sub isKindOfClass:NSClassFromString(@"AVPlayerView")]) {
            hasMedia = YES;
            break;
        }
    }

    if (hasMedia) {
        [self __sg_addDownloadButton];
    }
}

%end

%new
- (void)__sg_addDownloadButton {
    dispatch_async(dispatch_get_main_queue(), ^{
        // avoid duplicates
        if ([self viewWithTag:9999]) return;

        UIButton *downloadButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [downloadButton setTitle:@"⬇️" forState:UIControlStateNormal];
        downloadButton.frame = CGRectMake(self.bounds.size.width - 50, 10, 40, 40);
        downloadButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
        downloadButton.tintColor = [UIColor whiteColor];
        downloadButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.35];
        downloadButton.layer.cornerRadius = 8;
        downloadButton.clipsToBounds = YES;
        downloadButton.tag = 9999;
        [downloadButton addTarget:self action:@selector(__sg_handleDownloadTap) forControlEvents:UIControlEventTouchUpInside];

        [self addSubview:downloadButton];
        self.userInteractionEnabled = YES;
    });
}

%new
- (void)__sg_handleDownloadTap {
    NSLog(@"[SaveGram] Download tapped");

    // Try to find image or player layer directly on this view or its subviews.
    UIImage *foundImage = nil;
    AVAsset *foundAsset = nil;
    NSURL *foundURL = nil;

    // direct as UIImageView
    if ([self isKindOfClass:[UIImageView class]]) {
        UIImageView *iv = (UIImageView *)self;
        foundImage = iv.image;
    }

    // scan subviews for image view or player layer
    for (UIView *sv in self.subviews) {
        if (!foundImage && [sv isKindOfClass:[UIImageView class]]) {
            foundImage = ((UIImageView *)sv).image;
        }
        if (!foundAsset && [sv.layer isKindOfClass:[AVPlayerLayer class]]) {
            AVPlayerLayer *pl = (AVPlayerLayer *)sv.layer;
            AVPlayerItem *item = pl.player.currentItem;
            if (item) {
                if (item.asset) {
                    foundAsset = item.asset;
                    if ([foundAsset isKindOfClass:[AVURLAsset class]]) {
                        foundURL = ((AVURLAsset *)foundAsset).URL;
                    }
                }
            }
        }
    }

    // if still not found, check self.layer
    if (!foundAsset && [self.layer isKindOfClass:[AVPlayerLayer class]]) {
        AVPlayerLayer *pl = (AVPlayerLayer *)self.layer;
        AVPlayerItem *item = pl.player.currentItem;
        if (item) {
            if (item.asset) {
                foundAsset = item.asset;
                if ([foundAsset isKindOfClass:[AVURLAsset class]]) {
                    foundURL = ((AVURLAsset *)foundAsset).URL;
                }
            }
        }
    }

    // Present options alert (Image / Video / Cancel)
    [self __sg_presentSaveOptionsWithImage:foundImage asset:foundAsset assetURL:foundURL];
}

%new
- (void)__sg_presentSaveOptionsWithImage:(UIImage *)image asset:(AVAsset *)asset assetURL:(NSURL *)assetURL {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"SaveGram"
                                                                       message:@"Choose what to save"
                                                                preferredStyle:UIAlertControllerStyleActionSheet];

        // Save Image option (only if image exists)
        UIAlertAction *saveImage = [UIAlertAction actionWithTitle:@"📷 Save Image" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            if (image) {
                [self __sg_saveImageToPhotos:image];
            } else {
                [self __sg_showAlertWithTitle:@"SaveGram" message:@"No image available."];
            }
        }];
        if (image) [alert addAction:saveImage];

        // Save Video option (only if asset or URL exists)
        UIAlertAction *saveVideo = [UIAlertAction actionWithTitle:@"🎥 Save Video" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            // prefer URL if provided
            if (assetURL) {
                [self __sg_saveVideoToPhotos:assetURL asset:nil];
            } else if (asset) {
                [self __sg_saveVideoToPhotos:nil asset:asset];
            } else {
                [self __sg_showAlertWithTitle:@"SaveGram" message:@"No video available."];
            }
        }];
        if (asset || assetURL) [alert addAction:saveVideo];

        // Cancel
        UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
        [alert addAction:cancel];

        // present from top view controller
        UIWindow *keyWindow = UIApplication.sharedApplication.keyWindow;
        UIViewController *top = keyWindow.rootViewController;
        while (top.presentedViewController) top = top.presentedViewController;
        // for iPad safety set popoverPresentationController sourceView
        if (alert.popoverPresentationController) {
            alert.popoverPresentationController.sourceView = self;
            alert.popoverPresentationController.sourceRect = CGRectMake(self.bounds.size.width - 30, 10, 1, 1);
        }
        [top presentViewController:alert animated:YES completion:nil];
    });
}

%new
- (void)__sg_saveImageToPhotos:(UIImage *)image {
    [self __sg_showHUD:@"Saving image..."];
    UIImageWriteToSavedPhotosAlbum(image, self, @selector(__sg_image:didFinishSavingWithError:contextInfo:), NULL);
}

%new
- (void)__sg_image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    [self __sg_showHUD:(error ? @"❌ Failed to save image." : @"✅ Image Saved!")];
}

%new
- (void)__sg_saveVideoToPhotos:(NSURL *)videoURL asset:(AVAsset *)asset {
    [self __sg_showHUD:@"Preparing video..."];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{

        AVAsset *useAsset = nil;

        // 1) If URL is provided and is a file URL -> asset from file
        if (videoURL && [videoURL isFileURL]) {
            useAsset = [AVAsset assetWithURL:videoURL];
        }
        // 2) If URL is network URL -> try to download to temp then use
        else if (videoURL) {
            NSData *videoData = [NSData dataWithContentsOfURL:videoURL];
            if (videoData) {
                NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"savegram_temp_download.mp4"];
                [videoData writeToFile:tempPath atomically:YES];
                useAsset = [AVAsset assetWithURL:[NSURL fileURLWithPath:tempPath]];
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self __sg_showAlertWithTitle:@"SaveGram" message:@"Failed to download video data."];
                });
                return;
            }
        }
        // 3) If asset provided (in-memory / composition), use it
        else if (asset) {
            useAsset = asset;
        }

        if (!useAsset) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self __sg_showHUD:@"❌ No video asset found."];
            });
            return;
        }

        // prepare filename with username or timestamp
        NSString *username = [self __sg_resolveUsernameOrDefault];
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyyMMdd_HHmmss"];
        NSString *ts = [formatter stringFromDate:[NSDate date]];
        NSString *filename = [NSString stringWithFormat:@"%@_%@.mp4", username, ts];
        NSString *outputPath = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
        NSURL *outputURL = [NSURL fileURLWithPath:outputPath];

        // remove old if exists
        if ([[NSFileManager defaultManager] fileExistsAtPath:outputPath]) {
            [[NSFileManager defaultManager] removeItemAtPath:outputPath error:nil];
        }

        // export asset
        [self __sg_exportAsset:useAsset toFileURL:outputURL completion:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!success) {
                    NSString *msg = error.localizedDescription ?: @"Export failed.";
                    [self __sg_showAlertWithTitle:@"SaveGram" message:msg];
                    return;
                }

                // save to photo library
                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                    [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:outputURL];
                } completionHandler:^(BOOL success2, NSError * _Nullable error2) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (success2) {
                            [self __sg_showHUD:[NSString stringWithFormat:@"✅ Saved as %@", filename]];
                        } else {
                            NSString *msg = error2.localizedDescription ?: @"Failed to save video.";
                            [self __sg_showAlertWithTitle:@"SaveGram" message:msg];
                        }
                    });
                }];
            });
        }];
    });
}

%new
- (void)__sg_exportAsset:(AVAsset *)asset toFileURL:(NSURL *)outputURL completion:(void(^)(BOOL success, NSError *error))completion {
    // choose preset that supports passthrough if possible
    NSString *preset = AVAssetExportPresetHighestQuality;
    if ([[AVAssetExportSession exportPresetsCompatibleWithAsset:asset] containsObject:AVAssetExportPresetPassthrough]) {
        preset = AVAssetExportPresetPassthrough;
    }

    AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:asset presetName:preset];
    exportSession.outputURL = outputURL;
    exportSession.outputFileType = AVFileTypeMPEG4;
    exportSession.shouldOptimizeForNetworkUse = YES;

    [exportSession exportAsynchronouslyWithCompletionHandler:^{
        if (exportSession.status == AVAssetExportSessionStatusCompleted) {
            if (completion) completion(YES, nil);
        } else {
            NSError *err = exportSession.error ?: [NSError errorWithDomain:@"SaveGram" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Export failed."}];
            if (completion) completion(NO, err);
        }
    }];
}

%new
- (void)__sg_showHUD:(NSString *)text {
    dispatch_async(dispatch_get_main_queue(), ^{
        // hud is added to keyWindow for visibility across view hierarchies
        UIWindow *keyWindow = UIApplication.sharedApplication.keyWindow;
        if (!keyWindow) return;
        UILabel *hud = [keyWindow viewWithTag:7777];
        if (!hud) {
            hud = [[UILabel alloc] initWithFrame:CGRectMake(40, keyWindow.bounds.size.height - 120, keyWindow.bounds.size.width - 80, 44)];
            hud.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.75];
            hud.textColor = [UIColor whiteColor];
            hud.textAlignment = NSTextAlignmentCenter;
            hud.layer.cornerRadius = 8;
            hud.clipsToBounds = YES;
            hud.tag = 7777;
            [keyWindow addSubview:hud];
        }
        hud.text = text;
        hud.alpha = 1.0;

        [UIView animateWithDuration:0.35 delay:1.8 options:0 animations:^{
            hud.alpha = 0.0;
        } completion:nil];
    });
}

%new
- (void)__sg_showAlertWithTitle:(NSString *)title message:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        UIWindow *keyWindow = UIApplication.sharedApplication.keyWindow;
        UIViewController *top = keyWindow.rootViewController;
        while (top.presentedViewController) top = top.presentedViewController;
        if (top) [top presentViewController:alert animated:YES completion:nil];
    });
}

%new
- (NSString *)__sg_resolveUsernameOrDefault {
    // Try to walk responder chain and call username selector if present
    NSString *username = nil;
    UIResponder *r = self;
    while (r) {
        if ([r respondsToSelector:@selector(username)]) {
            // suppress ARC warning by using performSelector (may need pragma if strict)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            id v = [r performSelector:@selector(username)];
#pragma clang diagnostic pop
            if ([v isKindOfClass:[NSString class]] && ((NSString *)v).length > 0) {
                username = v;
                break;
            }
        }
        r = [r nextResponder];
    }

    if (!username || username.length == 0) {
        // fallback to generic name
        username = @"user";
    }
    // sanitize username: remove path-unfriendly chars
    NSCharacterSet *invalid = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
    NSString *clean = [[username componentsSeparatedByCharactersInSet:invalid] componentsJoinedByString:@"_"];
    return clean;
}

%end
