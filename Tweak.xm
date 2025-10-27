#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>

#pragma mark - Declarations

@interface UIView (SaveGram)
+ (void)sg_updateFloatingButtonVisibilityForWindow:(UIWindow *)window;
+ (void)sg_addFloatingButtonToWindow:(UIWindow *)window;
+ (void)sg_removeFloatingButtonFromWindow:(UIWindow *)window;
+ (UIButton *)sg_floatingButtonForWindow:(UIWindow *)window;

- (BOOL)sg_containsLargeMediaCandidate;
- (UIImage *)sg_firstLargeImageInView;
- (AVAsset *)sg_firstVideoAssetInViewReturningURL:(NSURL **)outURL;
- (NSString *)sg_resolveUsernameOrDefault;
- (void)sg_handleFloatingButtonTap:(UIButton *)btn;

- (void)sg_saveImageToPhotos:(UIImage *)image filenamePrefix:(NSString *)prefix;
- (void)sg_saveAssetOrURL:(AVAsset *)asset url:(NSURL *)url filenamePrefix:(NSString *)prefix;
- (void)sg_exportAsset:(AVAsset *)asset toFileURL:(NSURL *)outputURL completion:(void(^)(BOOL success, NSError *error))completion;

+ (void)sg_showAlertStatic:(NSString *)title message:(NSString *)message;
+ (UIViewController *)sg_topViewController;
+ (void)sg_showHUDStatic:(NSString *)message;
@end

#pragma mark - Implementation

@implementation UIView (SaveGram)

#pragma mark - Floating button helpers

+ (NSUInteger)sg_floatingButtonTag { return 0xFA500001; }
+ (NSUInteger)sg_hudTag { return 0xFA500002; }

+ (UIButton *)sg_floatingButtonForWindow:(UIWindow *)window {
    if (!window) return nil;
    return (UIButton *)[window viewWithTag:[UIView sg_floatingButtonTag]];
}

+ (void)sg_addFloatingButtonToWindow:(UIWindow *)window {
    if (!window) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([UIView sg_floatingButtonForWindow:window]) return;

        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.tag = [UIView sg_floatingButtonTag];
        btn.frame = CGRectMake((window.bounds.size.width - 70)/2, (window.bounds.size.height - 70)/2, 70, 70);
        btn.layer.cornerRadius = 35;
        btn.clipsToBounds = YES;
        btn.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.45];
        btn.titleLabel.font = [UIFont systemFontOfSize:34];
        [btn setTitle:@"⬇️" forState:UIControlStateNormal];
        [btn addTarget:window action:@selector(sg_handleFloatingButtonTap:) forControlEvents:UIControlEventTouchUpInside];

        // Bring front and small shadow
        btn.layer.shadowColor = [UIColor blackColor].CGColor;
        btn.layer.shadowOpacity = 0.35;
        btn.layer.shadowRadius = 6;
        btn.layer.shadowOffset = CGSizeMake(0, 2);

        [window addSubview:btn];
        [window bringSubviewToFront:btn];
    });
}

+ (void)sg_removeFloatingButtonFromWindow:(UIWindow *)window {
    if (!window) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIButton *btn = [UIView sg_floatingButtonForWindow:window];
        if (!btn) return;
        [UIView animateWithDuration:0.22 animations:^{
            btn.alpha = 0.0;
        } completion:^(BOOL finished) {
            [btn removeFromSuperview];
        }];
    });
}

+ (void)sg_updateFloatingButtonVisibilityForWindow:(UIWindow *)window {
    if (!window) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL found = NO;
        // search window's view hierarchy for large media
        for (UIView *v in window.subviews) {
            if ([v sg_containsLargeMediaCandidate]) { found = YES; break; }
            for (UIView *sv in v.subviews) {
                if ([sv sg_containsLargeMediaCandidate]) { found = YES; break; }
            }
            if (found) break;
        }
        if (found) {
            [UIView sg_addFloatingButtonToWindow:window];
        } else {
            [UIView sg_removeFloatingButtonFromWindow:window];
        }
    });
}

#pragma mark - Detection helpers

- (BOOL)sg_containsLargeMediaCandidate {
    // Filter out tiny views / controls
    CGRect frameOnScreen = [self convertRect:self.bounds toView:nil];
    CGSize screen = UIScreen.mainScreen.bounds.size;
    CGFloat area = frameOnScreen.size.width * frameOnScreen.size.height;
    CGFloat screenArea = screen.width * screen.height;
    if (area < (screenArea * 0.10)) { // require 10% of screen area
        return NO;
    }

    // ignore common controls
    if ([self isKindOfClass:[UIButton class]] || [self isKindOfClass:[UILabel class]] || [self isKindOfClass:[UITextField class]] || [self isKindOfClass:[UISearchBar class]]) return NO;

    // search for imageView covering decent area or player layer
    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:[UIImageView class]]) {
            UIImageView *iv = (UIImageView *)sub;
            if (iv.image) {
                CGRect ivFrame = [iv convertRect:iv.bounds toView:nil];
                CGFloat ivArea = ivFrame.size.width * ivFrame.size.height;
                if (ivArea >= area * 0.25) return YES; // image covers >=25% of view area
            }
        }
        if ([sub.layer isKindOfClass:[AVPlayerLayer class]]) return YES;
        NSString *cls = NSStringFromClass([sub class]);
        if ([cls containsString:@"AVPlayer"] || [cls containsString:@"Player"] || [cls containsString:@"Video"]) return YES;
    }

    if ([self.layer isKindOfClass:[AVPlayerLayer class]]) return YES;

    return NO;
}

- (UIImage *)sg_firstLargeImageInView {
    // depth-first
    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:[UIImageView class]]) {
            UIImageView *iv = (UIImageView *)sub;
            if (iv.image && iv.bounds.size.width > 40 && iv.bounds.size.height > 40) return iv.image;
        }
        UIImage *found = [sub sg_firstLargeImageInView];
        if (found) return found;
    }
    return nil;
}

- (AVAsset *)sg_firstVideoAssetInViewReturningURL:(NSURL **)outURL {
    // check self.layer
    if ([self.layer isKindOfClass:[AVPlayerLayer class]]) {
        AVPlayerLayer *pl = (AVPlayerLayer *)self.layer;
        AVPlayerItem *item = pl.player.currentItem;
        if (item) {
            if (outURL && [item.asset isKindOfClass:[AVURLAsset class]]) *outURL = ((AVURLAsset *)item.asset).URL;
            return item.asset;
        }
    }

    // check subviews
    for (UIView *sub in self.subviews) {
        @try {
            if ([sub respondsToSelector:@selector(player)]) {
                id player = [sub valueForKey:@"player"];
                if (player && [player isKindOfClass:[AVPlayer class]]) {
                    AVPlayerItem *item = ((AVPlayer *)player).currentItem;
                    if (item) {
                        if (outURL && [item.asset isKindOfClass:[AVURLAsset class]]) *outURL = ((AVURLAsset *)item.asset).URL;
                        return item.asset;
                    }
                }
            }
        } @catch (NSException *e) {
            // ignore
        }
        AVAsset *found = [sub sg_firstVideoAssetInViewReturningURL:outURL];
        if (found) return found;
    }
    return nil;
}

#pragma mark - Username heuristics

- (NSString *)sg_resolveUsernameOrDefault {
    NSString *candidate = nil;
    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:[UILabel class]]) {
            NSString *t = ((UILabel *)sub).text;
            if (t && t.length > 0) {
                if ([t hasPrefix:@"@"]) { candidate = t; break; }
                NSCharacterSet *invalid = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
                NSString *clean = [[t componentsSeparatedByCharactersInSet:invalid] componentsJoinedByString:@""];
                if (clean.length >= 3 && clean.length <= 30) candidate = clean;
            }
        }
    }
    if (!candidate) {
        // search superviews
        UIView *p = self.superview;
        while (p && !candidate) {
            for (UIView *sub in p.subviews) {
                if ([sub isKindOfClass:[UILabel class]]) {
                    NSString *t = ((UILabel *)sub).text;
                    if (t && t.length > 0) {
                        if ([t hasPrefix:@"@"]) { candidate = t; break; }
                        NSCharacterSet *invalid = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
                        NSString *clean = [[t componentsSeparatedByCharactersInSet:invalid] componentsJoinedByString:@""];
                        if (clean.length >= 3 && clean.length <= 30) { candidate = clean; break; }
                    }
                }
            }
            p = p.superview;
        }
    }
    if (!candidate || candidate.length == 0) {
        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
        [fmt setDateFormat:@"yyyyMMdd_HHmmss"];
        candidate = [NSString stringWithFormat:@"user_%@", [fmt stringFromDate:[NSDate date]]];
    } else {
        NSCharacterSet *invalid = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
        candidate = [[candidate componentsSeparatedByCharactersInSet:invalid] componentsJoinedByString:@"_"];
    }
    return candidate;
}

#pragma mark - Floating button action

// Instance method called via target on button
- (void)sg_handleFloatingButtonTap:(UIButton *)btn {
    @try {
        UIWindow *window = btn.window ?: UIApplication.sharedApplication.keyWindow;
        if (!window) return;

        // find candidate view (topmost) containing large media
        UIView *candidate = nil;
        for (UIView *v in window.subviews.reverseObjectEnumerator) {
            if ([v sg_containsLargeMediaCandidate]) { candidate = v; break; }
            for (UIView *sv in v.subviews.reverseObjectEnumerator) {
                if ([sv sg_containsLargeMediaCandidate]) { candidate = sv; break; }
            }
            if (candidate) break;
        }
        if (!candidate) {
            [UIView sg_showAlertStatic:@"SaveGram" message:@"لا توجد وسائط مرئية للحفظ." inWindow:window];
            return;
        }

        NSString *username = [candidate sg_resolveUsernameOrDefault];
        UIImage *img = [candidate sg_firstLargeImageInView];
        NSURL *foundURL = nil;
        AVAsset *asset = [candidate sg_firstVideoAssetInViewReturningURL:&foundURL];

        // present action sheet safely
        UIViewController *top = [UIView sg_topViewController];
        if (!top) { [UIView sg_showAlertStatic:@"SaveGram" message:@"تعذّر الوصول للواجهة." inWindow:window]; return; }
        UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"SaveGram" message:@"اختر الإجراء" preferredStyle:UIAlertControllerStyleActionSheet];

        if (img) {
            [sheet addAction:[UIAlertAction actionWithTitle:@"📷 حفظ الصورة" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [candidate sg_saveImageToPhotos:img filenamePrefix:username];
                // hide button after success attempt
                [UIView sg_removeFloatingButtonFromWindow:window];
            }]];
        }

        if (asset || foundURL) {
            [sheet addAction:[UIAlertAction actionWithTitle:@"🎥 حفظ الفيديو" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [candidate sg_saveAssetOrURL:asset url:foundURL filenamePrefix:username];
                [UIView sg_removeFloatingButtonFromWindow:window];
            }]];
        }

        [sheet addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];

        // iPad safety
        if (sheet.popoverPresentationController) {
            sheet.popoverPresentationController.sourceView = btn;
            sheet.popoverPresentationController.sourceRect = btn.bounds;
        }
        [top presentViewController:sheet animated:YES completion:nil];

    } @catch (NSException *e) {
        NSLog(@"[SaveGram] Exception on tap: %@", e.reason);
    }
}

#pragma mark - Save implementations

- (void)sg_saveImageToPhotos:(UIImage *)image filenamePrefix:(NSString *)prefix {
    if (!image) { [UIView sg_showAlertStatic:@"SaveGram" message:@"لا توجد صورة للحفظ." inWindow:UIApplication.sharedApplication.keyWindow]; return; }
    [UIView sg_showHUDStatic:@"💾 حفظ الصورة..."];

    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    [fmt setDateFormat:@"yyyyMMdd_HHmmss"];
    NSString *fname = [NSString stringWithFormat:@"%@_%@.jpg", prefix ?: @"user", [fmt stringFromDate:[NSDate date]]];
    NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:fname];
    NSData *d = UIImageJPEGRepresentation(image, 1.0);
    if (!d) { [UIView sg_showAlertStatic:@"SaveGram" message:@"فشل تحويل الصورة." inWindow:UIApplication.sharedApplication.keyWindow]; return; }
    [d writeToFile:tmp atomically:YES];

    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:[NSURL fileURLWithPath:tmp]];
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) [UIView sg_showHUDStatic:[NSString stringWithFormat:@"✅ تم حفظ %@", fname]];
            else [UIView sg_showAlertStatic:@"SaveGram" message:[NSString stringWithFormat:@"فشل في الحفظ: %@", error.localizedDescription ?: @"غير معروف"] inWindow:UIApplication.sharedApplication.keyWindow];
        });
    }];
}

- (void)sg_saveAssetOrURL:(AVAsset *)asset url:(NSURL *)url filenamePrefix:(NSString *)prefix {
    UIWindow *win = UIApplication.sharedApplication.keyWindow;
    if (url && [url isFileURL]) {
        // direct save
        [UIView sg_showHUDStatic:@"🎥 حفظ الفيديو..."];
        NSString *fname;
        {
            NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
            [fmt setDateFormat:@"yyyyMMdd_HHmmss"];
            fname = [NSString stringWithFormat:@"%@_%@.mp4", prefix ?: @"user", [fmt stringFromDate:[NSDate date]]];
        }
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:url];
        } completionHandler:^(BOOL success, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) [UIView sg_showHUDStatic:[NSString stringWithFormat:@"✅ تم حفظ %@", fname]];
                else [UIView sg_showAlertStatic:@"SaveGram" message:[NSString stringWithFormat:@"فشل في الحفظ: %@", error.localizedDescription ?: @"غير معروف"] inWindow:win];
            });
        }];
        return;
    }

    // if url is remote or asset is composition -> export to temp then save
    AVAsset *useAsset = asset;
    if (!useAsset && url) {
        // try download remote data to temp file
        [UIView sg_showHUDStatic:@"⬇️ تحميل الفيديو..."];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            NSData *data = [NSData dataWithContentsOfURL:url];
            if (!data) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [UIView sg_showAlertStatic:@"SaveGram" message:@"فشل تحميل الفيديو." inWindow:win];
                });
                return;
            }
            NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"savegram_tmp_download.mp4"];
            [data writeToFile:tmpPath atomically:YES];
            AVAsset *downloaded = [AVAsset assetWithURL:[NSURL fileURLWithPath:tmpPath]];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self sg_saveAssetOrURL:downloaded url:[NSURL fileURLWithPath:tmpPath] filenamePrefix:prefix];
            });
        });
        return;
    }

    if (!useAsset) {
        [UIView sg_showAlertStatic:@"SaveGram" message:@"لا يوجد فيديو صالح للحفظ." inWindow:win];
        return;
    }

    // export
    [UIView sg_showHUDStatic:@"🎥 تصدير الفيديو..."];
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    [fmt setDateFormat:@"yyyyMMdd_HHmmss"];
    NSString *fname = [NSString stringWithFormat:@"%@_%@.mp4", prefix ?: @"user", [fmt stringFromDate:[NSDate date]]];
    NSString *outPath = [NSTemporaryDirectory() stringByAppendingPathComponent:fname];
    NSURL *outURL = [NSURL fileURLWithPath:outPath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:outPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:outPath error:nil];
    }

    [self sg_exportAsset:useAsset toFileURL:outURL completion:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!success) {
                [UIView sg_showAlertStatic:@"SaveGram" message:[NSString stringWithFormat:@"فشل في التصدير: %@", error.localizedDescription ?: @"Export failed"] inWindow:win];
                return;
            }
            // save exported file
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:outURL];
            } completionHandler:^(BOOL success2, NSError * _Nullable error2) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (success2) [UIView sg_showHUDStatic:[NSString stringWithFormat:@"✅ تم حفظ %@", fname]];
                    else [UIView sg_showAlertStatic:@"SaveGram" message:[NSString stringWithFormat:@"فشل في الحفظ: %@", error2.localizedDescription ?: @"unknown"] inWindow:win];
                });
            }];
        });
    }];
}

- (void)sg_exportAsset:(AVAsset *)asset toFileURL:(NSURL *)outputURL completion:(void(^)(BOOL success, NSError *error))completion {
    if (!asset || !outputURL) {
        if (completion) completion(NO, [NSError errorWithDomain:@"SaveGram" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"invalid params"}]);
        return;
    }
    NSString *preset = AVAssetExportPresetHighestQuality;
    NSArray *compatible = [AVAssetExportSession exportPresetsCompatibleWithAsset:asset];
    if ([compatible containsObject:AVAssetExportPresetPassthrough]) preset = AVAssetExportPresetPassthrough;

    AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:asset presetName:preset];
    if (!exportSession) { if (completion) completion(NO, [NSError errorWithDomain:@"SaveGram" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"failed to create export session"}]); return; }
    exportSession.outputURL = outputURL;
    exportSession.outputFileType = AVFileTypeMPEG4;
    exportSession.shouldOptimizeForNetworkUse = YES;

    [exportSession exportAsynchronouslyWithCompletionHandler:^{
        if (exportSession.status == AVAssetExportSessionStatusCompleted) {
            if (completion) completion(YES, nil);
        } else {
            NSError *err = exportSession.error ?: [NSError errorWithDomain:@"SaveGram" code:-3 userInfo:@{NSLocalizedDescriptionKey: @"export failed"}];
            if (completion) completion(NO, err);
        }
    }];
}

#pragma mark - UI helpers

+ (UIViewController *)sg_topViewController {
    __block UIViewController *top = nil;
    dispatch_sync(dispatch_get_main_queue(), ^{
        UIWindow *key = UIApplication.sharedApplication.keyWindow;
        top = key.rootViewController;
        while (top.presentedViewController) top = top.presentedViewController;
    });
    return top;
}

+ (void)sg_showAlertStatic:(NSString *)title message:(NSString *)message inWindow:(UIWindow *)window {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *top = [UIView sg_topViewController];
        if (!top) return;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"موافق" style:UIAlertActionStyleDefault handler:nil]];
        [top presentViewController:alert animated:YES completion:nil];
    });
}

+ (void)sg_showHUDStatic:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *w = UIApplication.sharedApplication.keyWindow;
        if (!w) return;
        UILabel *hud = (UILabel *)[w viewWithTag:[UIView sg_hudTag]];
        if (!hud) {
            hud = [[UILabel alloc] initWithFrame:CGRectZero];
            hud.tag = [UIView sg_hudTag];
            hud.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.78];
            hud.textColor = [UIColor whiteColor];
            hud.textAlignment = NSTextAlignmentCenter;
            hud.numberOfLines = 2;
            hud.layer.cornerRadius = 8;
            hud.clipsToBounds = YES;
            [w addSubview:hud];
        }
        UIFont *font = [UIFont boldSystemFontOfSize:14];
        CGSize textSize = [message sizeWithAttributes:@{NSFontAttributeName: font}];
        CGFloat maxW = w.bounds.size.width - 60;
        CGFloat width = MIN(maxW, textSize.width + 40);
        hud.frame = CGRectMake((w.bounds.size.width - width)/2, w.bounds.size.height - 140, width, 50);
        hud.font = font;
        hud.text = message;
        hud.alpha = 0;
        [UIView animateWithDuration:0.25 animations:^{ hud.alpha = 1.0; } completion:^(BOOL finished) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.25 animations:^{ hud.alpha = 0.0; } completion:nil];
            });
        }];
    });
}

@end

#pragma mark - Hook UIView.didMoveToWindow to update button visibility safely

%hook UIView

- (void)didMoveToWindow {
    %orig;
    if (!self.window) return;

    // ignore controls and small views to avoid injecting for icons/buttons/searchbars
    NSString *cls = NSStringFromClass([self class]);
    if ([self isKindOfClass:[UIButton class]] || [self isKindOfClass:[UILabel class]] ||
        [self isKindOfClass:[UITextField class]] || [self isKindOfClass:[UISearchBar class]] ||
        [cls containsString:@"Cell"]) {
        // still update global visibility if structure changed
        [UIView sg_updateFloatingButtonVisibilityForWindow:self.window];
        return;
    }

    @try {
        if ([self sg_containsLargeMediaCandidate]) {
            [UIView sg_updateFloatingButtonVisibilityForWindow:self.window];
        } else {
            // re-evaluate in case of removal
            [UIView sg_updateFloatingButtonVisibilityForWindow:self.window];
        }
    } @catch (NSException *e) {
        NSLog(@"[SaveGram] didMoveToWindow exception: %@", e.reason);
    }
}

%end

#pragma mark - ctor to ensure initial update

%ctor {
    NSLog(@"[SaveGram] ✅ Tweak loaded");
    // Delay a bit to allow app UI to settle, then update button for main window
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *w = UIApplication.sharedApplication.keyWindow;
        if (w) [UIView sg_updateFloatingButtonVisibilityForWindow:w];
    });

    // Also observe key window changes (optional)
    @try {
        [[NSNotificationCenter defaultCenter] addObserverForName:UIWindowDidBecomeKeyNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
            UIWindow *w = note.object;
            if (w) [UIView sg_updateFloatingButtonVisibilityForWindow:w];
        }];
    } @catch (NSException *e) { }
}
