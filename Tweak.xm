// Tweak.xm - SaveGram (Generalized)
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <objc/runtime.h>

static char kSGDownloadButtonKey;
static char kSGCheckingKey;

%hook UIView

// --- Helpers -------------------------------------------------------------

%new - (void)__sg_log:(NSString *)fmt, ... {
    va_list args;
    va_start(args, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    NSLog(@"[SaveGram] %@", s);
}

%new - (BOOL)__sg_alreadyChecking {
    NSNumber *n = objc_getAssociatedObject(self, &kSGCheckingKey);
    return n ? [n boolValue] : NO;
}
%new - (void)__sg_setChecking:(BOOL)v {
    objc_setAssociatedObject(self, &kSGCheckingKey, @(v), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// فحص سريع لأسماء الكلاسات المعروفة بأنها تعرض وسائط
%new - (BOOL)__sg_classNameLooksLikeMediaView {
    NSString *name = NSStringFromClass([self class]);
    if (!name) return NO;
    NSArray *keywords = @[@"Image", @"Story", @"Video", @"Player", @"Preview", @"Media", @"Photo", @"AV"];
    for (NSString *kw in keywords) {
        if ([name rangeOfString:kw options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;
    }
    if ([self isKindOfClass:[UIImageView class]]) return YES;
    return NO;
}

// البحث المتكرر عن AVPlayerLayer داخل الشجرة
%new - (AVPlayerLayer *)__sg_findPlayerLayerRecursivelyInLayer:(CALayer *)layer {
    if (!layer) return nil;
    if ([layer isKindOfClass:[AVPlayerLayer class]]) return (AVPlayerLayer *)layer;
    for (CALayer *s in layer.sublayers) {
        AVPlayerLayer *found = [self __sg_findPlayerLayerRecursivelyInLayer:s];
        if (found) return found;
    }
    return nil;
}

// محاولة الحصول على URL أصلية لصورة (في حال الـ imageView يخزّن URL عبر property خاصة)
%new - (NSURL *)__sg_tryGetImageURLFromView {
    // أمثلة: بعض اليوزرات تحتوي على keys مثل "imageURL" أو "url"
    NSArray *cands = @[@"imageURL", @"imageUrl", @"url", @"image_path", @"photoURL"];
    for (NSString *k in cands) {
        if ([self respondsToSelector:NSSelectorFromString(k)]) {
            @try {
                id v = [self valueForKey:k];
                if ([v isKindOfClass:[NSURL class]]) return v;
                if ([v isKindOfClass:[NSString class]]) return [NSURL URLWithString:v];
            } @catch (NSException *ex) { /* ignore */ }
        }
        // try subviews
        for (UIView *sub in self.subviews) {
            if ([sub respondsToSelector:NSSelectorFromString(k)]) {
                @try {
                    id v = [sub valueForKey:k];
                    if ([v isKindOfClass:[NSURL class]]) return v;
                    if ([v isKindOfClass:[NSString class]]) return [NSURL URLWithString:v];
                } @catch (NSException *ex) {}
            }
        }
    }
    return nil;
}

// ترجيح جودة الفيديو: نستخدم passthrough إن أمكن وإلا highest compatible preset
%new - (NSString *)__sg_chooseExportPresetForAsset:(AVAsset *)asset {
    if (!asset) return AVAssetExportPresetPassthrough;
    NSArray *presets = [AVAssetExportSession exportPresetsCompatibleWithAsset:asset];
    if ([presets containsObject:AVAssetExportPresetPassthrough]) return AVAssetExportPresetPassthrough;
    if ([presets containsObject:AVAssetExportPresetHighestQuality]) return AVAssetExportPresetHighestQuality;
    if (presets.count) return presets.lastObject;
    return AVAssetExportPresetHighestQuality;
}

// top view controller لعرض التنبيهات بأمان
%new - (UIViewController *)__sg_topViewController {
    UIWindow *key = UIApplication.sharedApplication.keyWindow ?: UIApplication.sharedApplication.windows.firstObject;
    UIViewController *root = key.rootViewController;
    UIViewController *top = root;
    while (top.presentedViewController) top = top.presentedViewController;
    return top;
}

// --- إضافة زر التحميل بأمان ---------------------------------------------

%new - (void)__sg_addDownloadButtonSafely {
    // لا نضيف أكثر من زر واحد لكل view
    if (objc_getAssociatedObject(self, &kSGDownloadButtonKey)) return;
    if (![self __sg_classNameLooksLikeMediaView]) return;
    if (!self.window || CGRectEqualToRect(self.bounds, CGRectZero)) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        // حماية ثانية
        if (objc_getAssociatedObject(self, &kSGDownloadButtonKey)) return;

        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        [btn setTitle:@"⬇️" forState:UIControlStateNormal];
        btn.frame = CGRectMake(MAX(8, self.bounds.size.width - 54), 8, 44, 36);
        btn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
        btn.tintColor = [UIColor whiteColor];
        btn.layer.shadowColor = [UIColor blackColor].CGColor;
        btn.layer.shadowOpacity = 0.35;
        btn.layer.shadowOffset = CGSizeMake(1, 1);
        btn.layer.shadowRadius = 2;
        // store reference
        objc_setAssociatedObject(self, &kSGDownloadButtonKey, btn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        // add safe target: pass sender so can find correct superview
        [btn addTarget:self action:@selector(__sg_handleDownloadTap:) forControlEvents:UIControlEventTouchUpInside];
        // ensure interaction enabled
        self.userInteractionEnabled = YES;
        [self addSubview:btn];
    });
}

// Hook آمن على didMoveToWindow — نعمل إضافة متأخرة خفيفة لتفادي التعارض أثناء إعداد الواجهة
- (void)didMoveToWindow {
    %orig;
    // لا نحاول إضافة بشكل متكرر إن كان أثناء إعادة التدوير سريعًا
    if ([self __sg_alreadyChecking]) return;
    [self __sg_setChecking:YES];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self __sg_addDownloadButtonSafely];
        [self __sg_setChecking:NO];
    });
}

// --- معالج الضغط على الزر -----------------------------------------------

// نستخدم sender للوصول إلى superview الصحيح (يعالج حالات reuse)
- (void)__sg_handleDownloadTap:(UIButton *)sender {
    UIView *target = sender.superview ?: self;
    if (!target) {
        [self __sg_log:@"no target on button tap"];
        return;
    }

    [self __sg_log:@"download tapped on view %@", NSStringFromClass([target class])];

    // 1) أولاً: هل يوجد صورة مباشرة؟
    UIImageView *imgView = nil;
    if ([target isKindOfClass:[UIImageView class]]) imgView = (UIImageView *)target;
    else {
        for (UIView *v in target.subviews) {
            if ([v isKindOfClass:[UIImageView class]]) { imgView = (UIImageView *)v; break; }
        }
    }

    if (imgView.image) {
        // إذا أمكن، حاول الحصول على URL الأصلي أعلى جودة
        NSURL *maybeURL = [target __sg_tryGetImageURLFromView];
        if (maybeURL) {
            [target __sg_log:@"found candidate image URL: %@", maybeURL];
            [target __sg_saveImageFromURL:maybeURL fallbackImage:imgView.image];
        } else {
            [target __sg_saveImageToPhotos:imgView.image];
        }
        return;
    }

    // 2) هل هناك AVPlayerLayer في الطبقات؟
    AVPlayerLayer *playerLayer = [target __sg_findPlayerLayerRecursivelyInLayer:target.layer];
    if (!playerLayer) {
        // تفتيش أيضا في subviews
        for (UIView *v in target.subviews) {
            playerLayer = [target __sg_findPlayerLayerRecursivelyInLayer:v.layer];
            if (playerLayer) break;
        }
    }

    if (playerLayer && playerLayer.player && playerLayer.player.currentItem) {
        AVPlayerItem *item = playerLayer.player.currentItem;
        AVAsset *asset = item.asset;
        NSURL *url = nil;
        if ([asset isKindOfClass:[AVURLAsset class]]) url = ((AVURLAsset *)asset).URL;
        [target __sg_saveVideoToPhotosWithAsset:asset remoteURL:url];
        return;
    }

    // 3) محاولة إيجاد AVPlayerViewController أو MPMoviePlayerController عبر responder chain
    UIResponder *r = target;
    while (r) {
        if ([r isKindOfClass:[AVPlayerViewController class]]) {
            AVPlayerViewController *vc = (AVPlayerViewController *)r;
            AVAsset *asset = vc.player.currentItem.asset;
            NSURL *url = nil;
            if ([asset isKindOfClass:[AVURLAsset class]]) url = ((AVURLAsset *)asset).URL;
            [target __sg_saveVideoToPhotosWithAsset:asset remoteURL:url];
            return;
        }
        r = [r nextResponder];
    }

    [target __sg_showAlertWithTitle:@"SaveGram" message:@"No media detected."];
}

// --- حفظ الصور ----------------------------------------------------------

%new - (void)__sg_saveImageFromURL:(NSURL *)url fallbackImage:(UIImage *)fallback {
    if (!url) {
        [self __sg_saveImageToPhotos:fallback];
        return;
    }
    // لو URL ملف محلي - استخدمه مباشرة
    if (url.isFileURL) {
        NSData *d = [NSData dataWithContentsOfURL:url];
        UIImage *img = [UIImage imageWithData:d];
        if (img) { [self __sg_saveImageToPhotos:img]; return; }
    }
    // تحميل الشبكة بطريقة غير متزامنة
    [self __sg_showHUD:@"Downloading image..."];
    NSURLSessionDataTask *t = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (err || !data) {
                [self __sg_log:@"image download failed: %@", err];
                if (fallback) [self __sg_saveImageToPhotos:fallback];
                else [self __sg_showAlertWithTitle:@"SaveGram" message:@"Failed to download image."];
                return;
            }
            UIImage *img = [UIImage imageWithData:data];
            if (!img && fallback) img = fallback;
            if (img) [self __sg_saveImageToPhotos:img];
            else [self __sg_showAlertWithTitle:@"SaveGram" message:@"Downloaded data is not an image."];
        });
    }];
    [t resume];
}

%new - (void)__sg_saveImageToPhotos:(UIImage *)image {
    if (!image) {
        [self __sg_showAlertWithTitle:@"SaveGram" message:@"No image to save."];
        return;
    }
    [self __sg_showHUD:@"Saving image..."];
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
    NSString *msg = error ? @"❌ Failed to save image." : @"✅ Image saved";
    [self __sg_showHUD:msg];
}

// --- حفظ الفيديو --------------------------------------------------------

%new - (void)__sg_saveVideoToPhotosWithAsset:(AVAsset *)asset remoteURL:(NSURL *)maybeURL {
    [self __sg_showHUD:@"Preparing video..."];
    if (!asset && !maybeURL) {
        [self __sg_showAlertWithTitle:@"SaveGram" message:@"No video asset found."];
        return;
    }

    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (status != PHAuthorizationStatusAuthorized && status != PHAuthorizationStatusLimited) {
                [self __sg_showAlertWithTitle:@"SaveGram" message:@"Photos permission denied."];
                return;
            }

            // حالة: URL موجود وبعيد -> نحمّله أولًا
            if (maybeURL && !maybeURL.isFileURL) {
                [self __sg_downloadRemoteURL:maybeURL completion:^(NSURL *localFile, NSError *err) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (err || !localFile) {
                            [self __sg_showAlertWithTitle:@"SaveGram" message:err.localizedDescription ?: @"Failed to download video."];
                            return;
                        }
                        [self __sg_exportAndSaveVideoAtURL:localFile preferredFileName:maybeURL.lastPathComponent];
                    });
                }];
                return;
            }

            // حالة: ملف محلي (file URL)
            if ([asset isKindOfClass:[AVURLAsset class]]) {
                NSURL *fileURL = ((AVURLAsset *)asset).URL;
                if (fileURL && fileURL.isFileURL) {
                    [self __sg_exportAndSaveVideoAtURL:fileURL preferredFileName:fileURL.lastPathComponent];
                    return;
                }
            }

            // حالة: asset مباشر لكن قد يحتاج export
            [self __sg_exportAssetAndSave:asset preferredFileName:@"video_export.mp4"];
        });
    }];
}

%new - (void)__sg_downloadRemoteURL:(NSURL *)url completion:(void(^)(NSURL *localFile, NSError *err))completion {
    if (!url) {
        if (completion) completion(nil, [NSError errorWithDomain:@"SaveGram" code:0 userInfo:@{NSLocalizedDescriptionKey:@"Invalid URL"}]);
        return;
    }
    NSURLSessionDownloadTask *t = [[NSURLSession sharedSession] downloadTaskWithURL:url completionHandler:^(NSURL *location, NSURLResponse *resp, NSError *err) {
        if (err) {
            if (completion) completion(nil, err);
            return;
        }
        NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID].UUIDString stringByAppendingPathExtension:@"mp4"]];
        NSURL *dest = [NSURL fileURLWithPath:tmp];
        NSError *moveErr = nil;
        [[NSFileManager defaultManager] moveItemAtURL:location toURL:dest error:&moveErr];
        if (moveErr) { if (completion) completion(nil, moveErr); }
        else { if (completion) completion(dest, nil); }
    }];
    [t resume];
}

%new - (void)__sg_exportAndSaveVideoAtURL:(NSURL *)fileURL preferredFileName:(NSString *)name {
    if (!fileURL) { [self __sg_showAlertWithTitle:@"SaveGram" message:@"No file to save."]; return; }
    // لو الملف هو mp4 أو mov نجرّب حفظه مباشرة
    NSString *ext = fileURL.pathExtension.lowercaseString;
    if ([ext isEqualToString:@"mp4"] || [ext isEqualToString:@"mov"]) {
        [self __sg_showHUD:@"Saving video..."];
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:fileURL];
            } completionHandler:^(BOOL success, NSError * _Nullable error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (success) [self __sg_showHUD:[NSString stringWithFormat:@"✅ Saved %@", name ?: @"video"]];
                    else [self __sg_showAlertWithTitle:@"SaveGram" message:error.localizedDescription ?: @"Failed to save video."];
                });
            }];
        });
        return;
    }

    // خلاف ذلك، سنحاول التصدير إلى mp4 بأعلى جودة متاحة
    [self __sg_exportAssetAndSave:[AVAsset assetWithURL:fileURL] preferredFileName:name];
}

%new - (void)__sg_exportAssetAndSave:(AVAsset *)asset preferredFileName:(NSString *)name {
    if (!asset) { [self __sg_showAlertWithTitle:@"SaveGram" message:@"No asset to export."]; return; }

    NSString *preset = [self __sg_chooseExportPresetForAsset:asset];
    AVAssetExportSession *es = [[AVAssetExportSession alloc] initWithAsset:asset presetName:preset];
    if (!es) {
        [self __sg_showAlertWithTitle:@"SaveGram" message:@"Cannot create export session."];
        return;
    }
    es.shouldOptimizeForNetworkUse = YES;
    NSString *outPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID].UUIDString stringByAppendingPathExtension:@"mp4"]];
    es.outputURL = [NSURL fileURLWithPath:outPath];
    es.outputFileType = AVFileTypeMPEG4;

    [es exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (es.status == AVAssetExportSessionStatusCompleted) {
                [self __sg_exportAndSaveVideoAtURL:es.outputURL preferredFileName:name];
            } else {
                NSString *err = es.error.localizedDescription ?: @"Export failed (DRM or streaming?)";
                [self __sg_showAlertWithTitle:@"SaveGram" message:err];
            }
        });
    }];
}

// --- HUD & Alerts -------------------------------------------------------

%new - (void)__sg_showHUD:(NSString *)text {
    dispatch_async(dispatch_get_main_queue(), ^{
        UILabel *hud = [self viewWithTag:0xABCD1001];
        if (!hud) {
            hud = [[UILabel alloc] initWithFrame:CGRectMake(20, self.bounds.size.height - 80, self.bounds.size.width - 40, 42)];
            hud.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
            hud.textColor = [UIColor whiteColor];
            hud.textAlignment = NSTextAlignmentCenter;
            hud.layer.cornerRadius = 8;
            hud.clipsToBounds = YES;
            hud.tag = 0xABCD1001;
            hud.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
            [self addSubview:hud];
        }
        hud.text = text;
        hud.alpha = 1.0;
        [UIView animateWithDuration:0.45 delay:2.0 options:0 animations:^{ hud.alpha = 0.0; } completion:nil];
    });
}

%new - (void)__sg_showAlertWithTitle:(NSString *)title message:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *a = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        UIViewController *top = [self __sg_topViewController];
        if (top) [top presentViewController:a animated:YES completion:nil];
        else [self __sg_log:@"Cannot present alert - no top VC"];
    });
}

%end
