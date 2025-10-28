#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <objc/runtime.h>

static char kSGDownloadButtonKey;

%hook UIView

%new - (BOOL)__sg_classNameLooksLikeMediaView {
    NSString *name = NSStringFromClass([self class]);
    if (!name) return NO;
    NSArray *keywords = @[@"Image", @"Story", @"Video", @"Player", @"Preview"];
    for (NSString *kw in keywords) {
        if ([name rangeOfString:kw options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;
    }
    if ([self isKindOfClass:[UIImageView class]]) return YES;
    return NO;
}

%new - (AVPlayerLayer *)__sg_findPlayerLayerRecursivelyInLayer:(CALayer *)layer {
    if (!layer) return nil;
    if ([layer isKindOfClass:[AVPlayerLayer class]]) return (AVPlayerLayer *)layer;
    for (CALayer *s in layer.sublayers) {
        AVPlayerLayer *found = [self __sg_findPlayerLayerRecursivelyInLayer:s];
        if (found) return found;
    }
    return nil;
}

%new - (void)__sg_addDownloadButtonSafely {
    if (![self __sg_classNameLooksLikeMediaView]) return;
    // ensure we are in window and have reasonable bounds
    if (!self.window || CGRectEqualToRect(self.bounds, CGRectZero)) return;

    UIButton *existing = (UIButton *)objc_getAssociatedObject(self, &kSGDownloadButtonKey);
    if (existing && existing.superview == self) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        UIButton *downloadButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [downloadButton setTitle:@"⬇️" forState:UIControlStateNormal];
        downloadButton.frame = CGRectMake(self.bounds.size.width - 50, 10, 40, 40);
        downloadButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
        downloadButton.tintColor = [UIColor whiteColor];
        downloadButton.layer.shadowColor = [UIColor blackColor].CGColor;
        downloadButton.layer.shadowOpacity = 0.3;
        downloadButton.layer.shadowOffset = CGSizeMake(1, 1);
        downloadButton.layer.shadowRadius = 2;
        // store reference
        objc_setAssociatedObject(self, &kSGDownloadButtonKey, downloadButton, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        // target-action: target is the view (self). Handler method defined below.
        [downloadButton addTarget:self action:@selector(__sg_handleDownloadTap:) forControlEvents:UIControlEventTouchUpInside];

        // Avoid adding button to non-interactive imageViews where clipsToBounds hides it.
        if (![self.subviews containsObject:downloadButton]) {
            [self addSubview:downloadButton];
        }
    });
}

- (void)didMoveToWindow {
    %orig;
    // add with delay 0 to next runloop to avoid interfering with setup
    dispatch_async(dispatch_get_main_queue(), ^{
        [self __sg_addDownloadButtonSafely];
    });
}

// Action receives sender so we can find correct view via sender.superview as fallback
- (void)__sg_handleDownloadTap:(UIButton *)sender {
    NSLog(@"[SaveGram] Download button tapped (safe handler)");
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *targetView = weakSelf;
        if (!targetView || targetView == (id)sender) {
            targetView = sender.superview ?: weakSelf;
        }
        if (!targetView) {
            [self __sg_showAlertWithTitle:@"SaveGram" message:@"No target view found."];
            return;
        }

        // first try find UIImageView in targetView (or itself)
        UIImageView *imageView = nil;
        if ([targetView isKindOfClass:[UIImageView class]]) imageView = (UIImageView *)targetView;
        else {
            for (UIView *sub in targetView.subviews) {
                if ([sub isKindOfClass:[UIImageView class]]) {
                    imageView = (UIImageView *)sub;
                    break;
                }
            }
        }

        if (imageView.image) {
            [targetView __sg_saveImageToPhotos:imageView.image];
            return;
        }

        // try find AVPlayerLayer
        AVPlayerLayer *playerLayer = [targetView __sg_findPlayerLayerRecursivelyInLayer:targetView.layer];
        if (!playerLayer) {
            // maybe subviews layers
            for (UIView *sub in targetView.subviews) {
                playerLayer = [targetView __sg_findPlayerLayerRecursivelyInLayer:sub.layer];
                if (playerLayer) break;
            }
        }

        if (playerLayer && playerLayer.player && playerLayer.player.currentItem) {
            AVPlayerItem *item = playerLayer.player.currentItem;
            AVAsset *asset = item.asset;
            NSURL *url = nil;
            if ([asset isKindOfClass:[AVURLAsset class]]) {
                url = ((AVURLAsset *)asset).URL;
            }
            [targetView __sg_saveVideoToPhotosWithAsset:asset remoteURL:url];
        } else {
            [targetView __sg_showAlertWithTitle:@"SaveGram" message:@"No media detected."];
        }
    });
}

%new - (void)__sg_saveImageToPhotos:(UIImage *)image {
    if (!image) {
        [self __sg_showAlertWithTitle:@"SaveGram" message:@"No image to save."];
        return;
    }
    [self __sg_showHUD:@"Saving image..."];
    // request authorization if needed
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (status != PHAuthorizationStatusAuthorized && status != PHAuthorizationStatusLimited) {
                [self __sg_showAlertWithTitle:@"SaveGram" message:@"Photos permission denied."];
                return;
            }
            UIImageWriteToSavedPhotosAlbum(image, self, @selector(__sg_image:didFinishSavingWithError:contextInfo:), NULL);
        });
    }];
}

- (void)__sg_image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    NSString *msg = error ? @"❌ Failed to save image." : @"✅ Image Saved!";
    [self __sg_showHUD:msg];
}

%new - (void)__sg_saveVideoToPhotosWithAsset:(AVAsset *)asset remoteURL:(NSURL *)maybeURL {
    [self __sg_showHUD:@"Preparing video..."];
    if (!asset && !maybeURL) {
        [self __sg_showAlertWithTitle:@"SaveGram" message:@"No video asset found."];
        return;
    }

    // request permission
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (status != PHAuthorizationStatusAuthorized && status != PHAuthorizationStatusLimited) {
                [self __sg_showAlertWithTitle:@"SaveGram" message:@"Photos permission denied."];
                return;
            }

            // If we have a remote URL (http/https) download it first
            if (maybeURL && !maybeURL.isFileURL) {
                [self __sg_downloadRemoteURL:maybeURL completion:^(NSURL *localFile, NSError *err) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (!localFile || err) {
                            [self __sg_showAlertWithTitle:@"SaveGram" message:err.localizedDescription ?: @"Failed to download video."];
                            return;
                        }
                        [self __sg_exportAndSaveVideoAtURL:localFile preferredFileName:@"video_downloaded.mp4"];
                    });
                }];
                return;
            }

            // If asset is AVURLAsset with file URL, use it
            if ([asset isKindOfClass:[AVURLAsset class]]) {
                NSURL *fileURL = ((AVURLAsset *)asset).URL;
                if (fileURL && fileURL.isFileURL) {
                    [self __sg_exportAndSaveVideoAtURL:fileURL preferredFileName:[fileURL lastPathComponent]];
                    return;
                }
            }

            // fallback: try export asset directly (may fail for streaming/DRM)
            [self __sg_exportAssetAndSave:asset preferredFileName:@"exported_video.mp4"];
        });
    }];
}

%new - (void)__sg_downloadRemoteURL:(NSURL *)url completion:(void(^)(NSURL *localFile, NSError *err))completion {
    if (!url) {
        if (completion) completion(nil, [NSError errorWithDomain:@"SaveGram" code:0 userInfo:@{NSLocalizedDescriptionKey:@"Invalid URL"}]);
        return;
    }
    NSURLSession *s = [NSURLSession sharedSession];
    NSURLRequest *req = [NSURLRequest requestWithURL:url];
    NSURLSessionDownloadTask *task = [s downloadTaskWithRequest:req completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID].UUIDString stringByAppendingPathExtension:@"mp4"]];
        NSURL *dest = [NSURL fileURLWithPath:tmp];
        NSError *moveErr = nil;
        [[NSFileManager defaultManager] moveItemAtURL:location toURL:dest error:&moveErr];
        if (moveErr) {
            if (completion) completion(nil, moveErr);
        } else {
            if (completion) completion(dest, nil);
        }
    }];
    [task resume];
}

%new - (void)__sg_exportAndSaveVideoAtURL:(NSURL *)fileURL preferredFileName:(NSString *)name {
    if (!fileURL) {
        [self __sg_showAlertWithTitle:@"SaveGram" message:@"No file to export."];
        return;
    }

    // if file is already a .mp4, attempt to save directly to Photos
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:fileURL];
        } completionHandler:^(BOOL success, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    [self __sg_showHUD:[NSString stringWithFormat:@"✅ Saved as %@", name ?: @"video.mp4"]];
                } else {
                    [self __sg_showAlertWithTitle:@"SaveGram" message:error.localizedDescription ?: @"Failed to save video."];
                }
            });
        }];
    });
}

%new - (void)__sg_exportAssetAndSave:(AVAsset *)asset preferredFileName:(NSString *)name {
    if (!asset) {
        [self __sg_showAlertWithTitle:@"SaveGram" message:@"No asset to export."];
        return;
    }
    NSArray *presets = [AVAssetExportSession exportPresetsCompatibleWithAsset:asset];
    NSString *preset = AVAssetExportPresetHighestQuality;
    if (![presets containsObject:preset] && presets.count > 0) preset = presets.lastObject;

    AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:asset presetName:preset];
    NSString *outPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID].UUIDString stringByAppendingPathExtension:@"mp4"]];
    exportSession.outputURL = [NSURL fileURLWithPath:outPath];
    exportSession.outputFileType = AVFileTypeMPEG4;
    exportSession.shouldOptimizeForNetworkUse = YES;

    [exportSession exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (exportSession.status == AVAssetExportSessionStatusCompleted) {
                [self __sg_exportAndSaveVideoAtURL:exportSession.outputURL preferredFileName:name];
            } else {
                NSString *err = exportSession.error.localizedDescription ?: @"Export failed.";
                [self __sg_showAlertWithTitle:@"SaveGram" message:[NSString stringWithFormat:@"❌ %@", err]];
            }
        });
    }];
}

%new - (void)__sg_showHUD:(NSString *)text {
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
            hud.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
            [self addSubview:hud];
        }
        hud.text = text;
        hud.alpha = 1.0;
        [UIView animateWithDuration:0.5 delay:2.0 options:0 animations:^{
            hud.alpha = 0.0;
        } completion:nil];
    });
}

%new - (UIViewController *)__sg_topViewController {
    UIWindow *key = UIApplication.sharedApplication.keyWindow;
    UIViewController *root = key.rootViewController;
    UIViewController *top = root;
    while (top.presentedViewController) top = top.presentedViewController;
    return top;
}

%new - (void)__sg_showAlertWithTitle:(NSString *)title message:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
        [alert addAction:ok];
        UIViewController *top = [self __sg_topViewController];
        if (top) [top presentViewController:alert animated:YES completion:nil];
        else NSLog(@"[SaveGram] Could not find top view controller to present alert");
    });
}

%end
