#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>

#pragma mark - Declarations

@interface UIView (SaveGram)
+ (void)__sg_updateFloatingButtonVisibilityForWindow:(UIWindow *)window;
+ (UIButton *)__sg_floatingButtonForWindow:(UIWindow *)window;
+ (void)__sg_addFloatingButtonToWindow:(UIWindow *)window;
+ (void)__sg_removeFloatingButtonFromWindow:(UIWindow *)window;
- (BOOL)__sg_containsLargeMediaCandidate;
- (UIImage *)__sg_firstLargeImageInView;
- (AVAsset *)__sg_firstVideoAssetInViewReturningURL:(NSURL **)outURL;
- (NSString *)__sg_resolveUsernameFromViewOrDefault;
- (void)__sg_handleFloatingButtonTap:(UIButton *)btn;
- (void)__sg_saveImageToPhotos:(UIImage *)image username:(NSString *)username;
- (void)__sg_saveVideoAssetOrURL:(AVAsset *)asset url:(NSURL *)url username:(NSString *)username;
- (void)__sg_exportAsset:(AVAsset *)asset toFileURL:(NSURL *)outputURL completion:(void(^)(BOOL success, NSError *error))completion;
- (void)__sg_showHUD:(NSString *)message;
- (void)__sg_showAlertWithTitle:(NSString *)title message:(NSString *)message;
@end

#pragma mark - Implementation helpers (category)

@implementation UIView (SaveGram)

#pragma mark - Floating button management (class-level helpers)

// unique tag for floating button per window
+ (UIButton *)__sg_floatingButtonForWindow:(UIWindow *)window {
    if (!window) return nil;
    return (UIButton *)[window viewWithTag:0xFA5G0001]; // unique tag
}

+ (void)__sg_addFloatingButtonToWindow:(UIWindow *)window {
    if (!window) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([UIView __sg_floatingButtonForWindow:window]) return;

        // create button
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        [btn setTitle:@"⬇️" forState:UIControlStateNormal];
        btn.tag = 0xFA5G0001;
        btn.tintColor = [UIColor whiteColor];
        btn.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.45];
        btn.layer.cornerRadius = 28;
        btn.clipsToBounds = YES;
        btn.frame = CGRectMake(0, 0, 56, 56);

        // center-ish: slightly above center to avoid keyboard / controls
        CGPoint center = CGPointMake(CGRectGetMidX(window.bounds), CGRectGetMidY(window.bounds) - 20);
        btn.center = center;
        btn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;

        [btn addTarget:[UIView class] action:@selector(__sg_handleFloatingBtnTapped:) forControlEvents:UIControlEventTouchUpInside];

        // add subtle shadow
        btn.layer.shadowColor = [UIColor blackColor].CGColor;
        btn.layer.shadowOpacity = 0.35;
        btn.layer.shadowRadius = 6;
        btn.layer.shadowOffset = CGSizeMake(0, 2);

        [window addSubview:btn];
        [window bringSubviewToFront:btn];
    });
}

+ (void)__sg_removeFloatingButtonFromWindow:(UIWindow *)window {
    if (!window) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIButton *btn = [UIView __sg_floatingButtonForWindow:window];
        if (btn) [btn removeFromSuperview];
    });
}

// Called when floating button tapped — dispatch to topmost media view to act as handler
+ (void)__sg_handleFloatingBtnTapped:(UIButton *)btn {
    UIWindow *window = btn.window ?: UIApplication.sharedApplication.keyWindow;
    if (!window) return;

    // find topmost candidate view that contains large media
    UIView *candidate = nil;
    NSArray *subs = window.subviews;
    for (UIView *v in subs.reverseObjectEnumerator) {
        if ([v __sg_containsLargeMediaCandidate]) {
            candidate = v;
            break;
        }
    }
    // fallback: search deeper
    if (!candidate) {
        for (UIView *v in subs) {
            if ([v __sg_containsLargeMediaCandidate]) {
                candidate = v;
                break;
            }
        }
    }

    if (!candidate) {
        // No media found — show alert
        [UIView __sg_removeFloatingButtonFromWindow:window];
        dispatch_async(dispatch_get_main_queue(), ^{
            [UIView __sg_showAlertStatic:@"SaveGram" message:@"لا توجد وسائط مرئية للحفظ." inWindow:window];
        });
        return;
    }

    // Determine username, image or asset
    NSString *username = [candidate __sg_resolveUsernameFromViewOrDefault];
    UIImage *img = [candidate __sg_firstLargeImageInView];
    NSURL *url = nil;
    AVAsset *asset = [candidate __sg_firstVideoAssetInViewReturningURL:&url];

    if (img) {
        [candidate __sg_saveImageToPhotos:img username:username];
        return;
    }

    if (asset || url) {
        [candidate __sg_saveVideoAssetOrURL:asset url:url username:username];
        return;
    }

    // if nothing found — show alert
    [UIView __sg_showAlertStatic:@"SaveGram" message:@"تعذّر تحديد وسائط للحفظ." inWindow:window];
}

+ (void)__sg_updateFloatingButtonVisibilityForWindow:(UIWindow *)window {
    if (!window) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        // find any large media candidate in window's view hierarchy
        BOOL found = NO;
        for (UIView *v in window.subviews) {
            if ([v __sg_containsLargeMediaCandidate]) { found = YES; break; }
            // also check deeper subviews
            for (UIView *sv in v.subviews) {
                if ([sv __sg_containsLargeMediaCandidate]) { found = YES; break; }
            }
            if (found) break;
        }

        if (found) {
            [UIView __sg_addFloatingButtonToWindow:window];
        } else {
            [UIView __sg_removeFloatingButtonFromWindow:window];
        }
    });
}

#pragma mark - Instance helpers to detect media

// Heuristic: large media candidate if it contains a UIImageView with image or an AVPlayerLayer, and occupies significant area
- (BOOL)__sg_containsLargeMediaCandidate {
    // ignore tiny views and controls
    CGRect frame = [self convertRect:self.bounds toView:nil];
    CGSize screen = UIScreen.mainScreen.bounds.size;
    CGFloat area = frame.size.width * frame.size.height;
    CGFloat screenArea = screen.width * screen.height;
    if (area < (screenArea * 0.12)) { // require at least 12% of screen area
        return NO;
    }

    // ignore known non-content classes (buttons, labels, search bar, nav bars)
    if ([self isKindOfClass:[UIButton class]] || [self isKindOfClass:[UILabel class]] || [self isKindOfClass:[UITextField class]] || [self isKindOfClass:[UISearchBar class]]) {
        return NO;
    }

    // check for image view
    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:[UIImageView class]]) {
            UIImageView *iv = (UIImageView *)sub;
            if (iv.image && iv.image.size.width > 20 && iv.image.size.height > 20) {
                // ensure image area relative to this view is not tiny
                CGRect ivFrame = [iv convertRect:iv.bounds toView:nil];
                CGFloat ivArea = ivFrame.size.width * ivFrame.size.height;
                if (ivArea >= (area * 0.3)) return YES; // image covers >=30% of view area
            }
        }
        // AVPlayerLayer detection: either sub is a view whose layer is AVPlayerLayer or known class names
        if ([sub.layer isKindOfClass:[AVPlayerLayer class]]) {
            return YES;
        }
        NSString *cls = NSStringFromClass([sub class]);
        if ([cls containsString:@"AVPlayer"] || [cls containsString:@"Player"] || [cls containsString:@"Video"]) {
            return YES;
        }
    }

    // also check self.layer
    if ([self.layer isKindOfClass:[AVPlayerLayer class]]) return YES;

    return NO;
}

// Return first large UIImage in this view (search depth-first)
- (UIImage *)__sg_firstLargeImageInView {
    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:[UIImageView class]]) {
            UIImageView *iv = (UIImageView *)sub;
            if (iv.image) {
                // size check
                if (iv.bounds.size.width > 50 && iv.bounds.size.height > 50) {
                    return iv.image;
                }
            }
        }
        UIImage *found = [sub __sg_firstLargeImageInView];
        if (found) return found;
    }
    return nil;
}

// Return first AVAsset or AVURLAsset URL found in view; outURL gets URL if found
- (AVAsset *)__sg_firstVideoAssetInViewReturningURL:(NSURL **)outURL {
    // check for AVPlayerLayer on self
    if ([self.layer isKindOfClass:[AVPlayerLayer class]]) {
        AVPlayerLayer *pl = (AVPlayerLayer *)self.layer;
        AVPlayerItem *item = pl.player.currentItem;
        if (item) {
            if (item.asset) {
                if (outURL && [item.asset isKindOfClass:[AVURLAsset class]]) *outURL = ((AVURLAsset *)item.asset).URL;
                return item.asset;
            }
        }
    }

    // check subviews
    for (UIView *sub in self.subviews) {
        // try safe KVC for player (some custom views store player)
        @try {
            id player = nil;
            if ([sub respondsToSelector:@selector(player)]) {
                player = [sub valueForKey:@"player"];
            } else {
                // attempt KVC
                player = [sub valueForKey:@"player"];
            }
            if (player && [player isKindOfClass:[AVPlayer class]]) {
                AVPlayerItem *item = ((AVPlayer *)player).currentItem;
                if (item) {
                    if (outURL && [item.asset isKindOfClass:[AVURLAsset class]]) *outURL = ((AVURLAsset *)item.asset).URL;
                    return item.asset;
                }
            }
        } @catch (NSException *e) {
            // ignore
        }

        AVAsset *found = [sub __sg_firstVideoAssetInViewReturningURL:outURL];
        if (found) return found;
    }
    return nil;
}

#pragma mark - username resolution

- (NSString *)__sg_resolveUsernameFromViewOrDefault {
    // Heuristic: scan nearby labels that look like usernames (@ or short text near top/bottom)
    NSString *candidate = nil;

    // search subviews
    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:[UILabel class]]) {
            UILabel *lbl = (UILabel *)sub;
            NSString *t = lbl.text;
            if (t && t.length > 0) {
                // prefer values with @
                if ([t hasPrefix:@"@"]) {
                    candidate = t;
                    break;
                }
                // otherwise if short and alphanumeric
                NSCharacterSet *invalid = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
                NSString *clean = [[t componentsSeparatedByCharactersInSet:invalid] componentsJoinedByString:@""];
                if (clean.length >= 3 && clean.length <= 30) {
                    candidate = clean;
                }
            }
        }
    }

    // walk responder chain / superviews for labels
    if (!candidate) {
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
        // fallback using timestamp
        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
        [fmt setDateFormat:@"yyyyMMdd_HHmmss"];
        candidate = [NSString stringWithFormat:@"user_%@", [fmt stringFromDate:[NSDate date]]];
    } else {
        // sanitize candidate
        NSCharacterSet *invalid = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
        candidate = [[candidate componentsSeparatedByCharactersInSet:invalid] componentsJoinedByString:@"_"];
    }
    return candidate;
}

#pragma mark - Save actions

- (void)__sg_saveImageToPhotos:(UIImage *)image username:(NSString *)username {
    if (!image) {
        [self __sg_showAlertWithTitle:@"SaveGram" message:@"لا توجد صورة للحفظ."];
        return;
    }
    [self __sg_showHUD:[NSString stringWithFormat:@"💾 حفظ الصورة..."]];

    NSString *ts;
    {
        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
        [fmt setDateFormat:@"yyyyMMdd_HHmmss"];
        ts = [fmt stringFromDate:[NSDate date]];
    }
    NSString *fname = [NSString stringWithFormat:@"%@_%@.jpg", username, ts];
    NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:fname];
    NSData *d = UIImageJPEGRepresentation(image, 1.0);
    if (!d) { [self __sg_showAlertWithTitle:@"SaveGram" message:@"فشل في تحويل الصورة للبيانات."]; return; }
    [d writeToFile:tmp atomically:YES];

    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:[NSURL fileURLWithPath:tmp]];
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                [self __sg_showHUD:[NSString stringWithFormat:@"✅ تم حفظ %@", fname]];
            } else {
                [self __sg_showAlertWithTitle:@"SaveGram" message:[NSString stringWithFormat:@"فشل في الحفظ: %@", error.localizedDescription ?: @"غير معروف"]];
            }
        });
    }];
}

- (void)__sg_saveVideoAssetOrURL:(AVAsset *)asset url:(NSURL *)url username:(NSString *)username {
    [self __sg_showHUD:@"🎥 تجهيز الفيديو..."];

    // If URL is file URL, attempt direct save
    if (url && [url isFileURL]) {
        NSURL *fileURL = url;
        // create unique filename for feedback only (Photos uses internal name)
        NSString *ts;
        {
            NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
            [fmt setDateFormat:@"yyyyMMdd_HHmmss"];
            ts = [fmt stringFromDate:[NSDate date]];
        }
        NSString *fname = [NSString stringWithFormat:@"%@_%@.mp4", username, ts];

        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:fileURL];
        } completionHandler:^(BOOL success, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    [self __sg_showHUD:[NSString stringWithFormat:@"✅ تم حفظ %@", fname]];
                } else {
                    [self __sg_showAlertWithTitle:@"SaveGram" message:[NSString stringWithFormat:@"فشل في الحفظ: %@", error.localizedDescription ?: @"غير معروف"]];
                }
            });
        }];
        return;
    }

    // If asset is present (in-memory/composition), export it to temp file then save
    if (asset) {
        NSString *ts;
        {
            NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
            [fmt setDateFormat:@"yyyyMMdd_HHmmss"];
            ts = [fmt stringFromDate:[NSDate date]];
        }
        NSString *fname = [NSString stringWithFormat:@"%@_%@.mp4", username, ts];
        NSString *outPath = [NSTemporaryDirectory() stringByAppendingPathComponent:fname];
        NSURL *outURL = [NSURL fileURLWithPath:outPath];

        // remove old
        if ([[NSFileManager defaultManager] fileExistsAtPath:outPath]) {
            [[NSFileManager defaultManager] removeItemAtPath:outPath error:nil];
        }

        [self __sg_exportAsset:asset toFileURL:outURL completion:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!success) {
                    [self __sg_showAlertWithTitle:@"SaveGram" message:[NSString stringWithFormat:@"فشل في تصدير الفيديو: %@", error.localizedDescription ?: @"Export failed"]];
                    return;
                }
                // save exported file
                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                    [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:outURL];
                } completionHandler:^(BOOL success2, NSError * _Nullable error2) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (success2) {
                            [self __sg_showHUD:[NSString stringWithFormat:@"✅ تم حفظ %@", fname]];
                        } else {
                            [self __sg_showAlertWithTitle:@"SaveGram" message:[NSString stringWithFormat:@"فشل في الحفظ: %@", error2.localizedDescription ?: @"غير معروف"]];
                        }
                    });
                }];
            });
        }];
        return;
    }

    // If we reach here, no usable asset
    [self __sg_showAlertWithTitle:@"SaveGram" message:@"تعذّر الحصول على فيديو صالح للحفظ."];
}

// export helper
- (void)__sg_exportAsset:(AVAsset *)asset toFileURL:(NSURL *)outputURL completion:(void(^)(BOOL success, NSError *error))completion {
    if (!asset || !outputURL) {
        if (completion) completion(NO, [NSError errorWithDomain:@"SaveGram" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid parameters"}]);
        return;
    }

    // choose preset
    NSString *preset = AVAssetExportPresetHighestQuality;
    NSArray *compatible = [AVAssetExportSession exportPresetsCompatibleWithAsset:asset];
    if ([compatible containsObject:AVAssetExportPresetPassthrough]) preset = AVAssetExportPresetPassthrough;

    AVAssetExportSession *export = [[AVAssetExportSession alloc] initWithAsset:asset presetName:preset];
    export.outputURL = outputURL;
    export.outputFileType = AVFileTypeMPEG4;
    export.shouldOptimizeForNetworkUse = YES;

    [export exportAsynchronouslyWithCompletionHandler:^{
        if (export.status == AVAssetExportSessionStatusCompleted) {
            if (completion) completion(YES, nil);
        } else {
            NSError *err = export.error ?: [NSError errorWithDomain:@"SaveGram" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"Export failed"}];
            if (completion) completion(NO, err);
        }
    }];
}

#pragma mark - UI helpers

- (void)__sg_showHUD:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *w = UIApplication.sharedApplication.keyWindow;
        if (!w) return;
        // find or create hud label
        UILabel *hud = (UILabel *)[w viewWithTag:0xFA5G0002];
        if (!hud) {
            hud = [[UILabel alloc] initWithFrame:CGRectZero];
            hud.tag = 0xFA5G0002;
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
        CGFloat width = MIN(w.bounds.size.width - 60, textSize.width + 40);
        CGFloat height = 50;
        hud.frame = CGRectMake((w.bounds.size.width - width)/2, w.bounds.size.height - 140, width, height);
        hud.font = font;
        hud.text = message;
        hud.alpha = 0;
        [UIView animateWithDuration:0.25 animations:^{ hud.alpha = 1.0; } completion:^(BOOL finished) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.25 animations:^{ hud.alpha = 0.0; } completion:^(BOOL finished) {
                    // keep hud for reuse but hidden
                }];
            });
        }];
    });
}

- (void)__sg_showAlertWithTitle:(NSString *)title message:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *w = UIApplication.sharedApplication.keyWindow;
        if (!w) return;
        UIViewController *top = w.rootViewController;
        while (top.presentedViewController) top = top.presentedViewController;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"موافق" style:UIAlertActionStyleDefault handler:nil]];
        [top presentViewController:alert animated:YES completion:nil];
    });
}

// static helper used from class method when no instance available
+ (void)__sg_showAlertStatic:(NSString *)title message:(NSString *)message inWindow:(UIWindow *)window {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!window) return;
        UIViewController *top = window.rootViewController;
        while (top.presentedViewController) top = top.presentedViewController;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"موافق" style:UIAlertActionStyleDefault handler:nil]];
        [top presentViewController:alert animated:YES completion:nil];
    });
}

@end

#pragma mark - Hook UIView.didMoveToWindow (filtering + update floating button)

%hook UIView

- (void)didMoveToWindow {
    %orig;

    // Only proceed after view actually in a window
    if (!self.window) {
        return;
    }

    // Protect: ignore primitive controls & small views to avoid adding for app icons/buttons
    if ([self isKindOfClass:[UIButton class]] ||
        [self isKindOfClass:[UILabel class]] ||
        [self isKindOfClass:[UITextField class]] ||
        [self isKindOfClass:[UISearchBar class]] ||
        [NSStringFromClass([self class]) containsString:@"CollectionViewCell"] ||
        [NSStringFromClass([self class]) containsString:@"TableViewCell"]) {
        // still update visibility globally in case previous content changed
        [UIView __sg_updateFloatingButtonVisibilityForWindow:self.window];
        return;
    }

    // If this view or its subviews contain large media candidate, add floating button to the window
    @try {
        BOOL hasMedia = [self __sg_containsLargeMediaCandidate];
        if (hasMedia) {
            [UIView __sg_updateFloatingButtonVisibilityForWindow:self.window];
        } else {
            // also re-evaluate global visibility if this view is being removed/added
            [UIView __sg_updateFloatingButtonVisibilityForWindow:self.window];
        }
    } @catch (NSException *e) {
        NSLog(@"[SaveGram] didMoveToWindow exception: %@", e.reason);
    }
}

%end