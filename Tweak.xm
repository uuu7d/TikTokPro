#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <Photos/Photos.h>
#import <objc/runtime.h>

@interface UIView (FileSaverTweak)
+ (void)fs_showToast:(NSString *)msg;
+ (UIWindow *)fs_activeWindow;
- (BOOL)fs_containsLargeMedia;
- (UIImage *)fs_firstImage;
- (AVAsset *)fs_firstVideoAssetReturningURL:(NSURL **)outURL;
- (NSString *)fs_guessUsername;
- (void)fs_handleDownloadTap:(UIButton *)btn;
@end

@implementation UIView (FileSaverTweak)

+ (void)fs_showToast:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *w = [UIView fs_activeWindow];
        if (!w) return;
        UILabel *lbl = (UILabel *)[w viewWithTag:0xFA5_0002];
        if (!lbl) {
            lbl = [[UILabel alloc] initWithFrame:CGRectZero];
            lbl.tag = 0xFA5_0002;
            lbl.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.78];
            lbl.textColor = UIColor.whiteColor;
            lbl.textAlignment = NSTextAlignmentCenter;
            lbl.numberOfLines = 2;
            lbl.layer.cornerRadius = 8;
            lbl.clipsToBounds = YES;
            [w addSubview:lbl];
        }
        UIFont *f = [UIFont boldSystemFontOfSize:14];
        CGSize s = [msg sizeWithAttributes:@{NSFontAttributeName: f}];
        CGFloat maxW = w.bounds.size.width - 60;
        CGFloat width = MIN(maxW, s.width + 40);
        lbl.frame = CGRectMake((w.bounds.size.width - width)/2, w.bounds.size.height - 140, width, 50);
        lbl.font = f;
        lbl.text = msg;
        lbl.alpha = 0;
        [UIView animateWithDuration:0.25 animations:^{ lbl.alpha = 1.0; } completion:^(BOOL finished) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.25 animations:^{ lbl.alpha = 0.0; }];
            });
        }];
    });
}

+ (UIWindow *)fs_activeWindow {
    __block UIWindow *result = nil;
    dispatch_sync(dispatch_get_main_queue(), ^{
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *wscene = (UIWindowScene *)scene;
            if (wscene.activationState != UISceneActivationStateForegroundActive) continue;
            for (UIWindow *w in wscene.windows) {
                if (w.isKeyWindow) { result = w; break; }
            }
            if (result) break;
        }
        if (!result) result = UIApplication.sharedApplication.keyWindow ?: UIApplication.sharedApplication.windows.firstObject;
    });
    return result;
}

- (BOOL)fs_containsLargeMedia {
    CGRect frameOnScreen = [self convertRect:self.bounds toView:nil];
    CGSize screen = UIScreen.mainScreen.bounds.size;
    CGFloat area = frameOnScreen.size.width * frameOnScreen.size.height;
    CGFloat screenArea = screen.width * screen.height;
    if (area < (screenArea * 0.08)) return NO; // require ~8% of screen
    if ([self isKindOfClass:[UIButton class]] || [self isKindOfClass:[UILabel class]] ||
        [self isKindOfClass:[UITextField class]] || [self isKindOfClass:[UISearchBar class]]) return NO;
    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:[UIImageView class]]) {
            UIImageView *iv = (UIImageView *)sub;
            if (iv.image) {
                CGRect ivFrame = [iv convertRect:iv.bounds toView:nil];
                CGFloat ivArea = ivFrame.size.width * ivFrame.size.height;
                if (ivArea >= area * 0.25) return YES;
            }
        }
        if ([sub.layer isKindOfClass:[AVPlayerLayer class]]) return YES;
        NSString *cls = NSStringFromClass([sub class]);
        if ([cls.lowercaseString containsString:@"player"] || [cls.lowercaseString containsString:@"video"]) return YES;
    }
    if ([self.layer isKindOfClass:[AVPlayerLayer class]]) return YES;
    return NO;
}

- (UIImage *)fs_firstImage {
    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:[UIImageView class]]) {
            UIImageView *iv = (UIImageView *)sub;
            if (iv.image) return iv.image;
        }
        UIImage *found = [sub fs_firstImage];
        if (found) return found;
    }
    return nil;
}

- (AVAsset *)fs_firstVideoAssetReturningURL:(NSURL **)outURL {
    if ([self.layer isKindOfClass:[AVPlayerLayer class]]) {
        AVPlayerLayer *pl = (AVPlayerLayer *)self.layer;
        AVPlayerItem *item = pl.player.currentItem;
        if (item) {
            if (outURL && [item.asset isKindOfClass:[AVURLAsset class]]) *outURL = ((AVURLAsset *)item.asset).URL;
            return item.asset;
        }
    }
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
        } @catch (NSException *e) {}
        AVAsset *found = [sub fs_firstVideoAssetReturningURL:outURL];
        if (found) return found;
    }
    return nil;
}

- (NSString *)fs_guessUsername {
    NSString *candidate = nil;
    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:[UILabel class]]) {
            NSString *t = ((UILabel *)sub).text;
            if (t && t.length >= 3 && t.length <= 30) {
                if ([t hasPrefix:@"@"]) { candidate = t; break; }
                NSCharacterSet *inv = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
                NSString *clean = [[t componentsSeparatedByCharactersInSet:inv] componentsJoinedByString:@""];
                if (clean.length >= 3) { candidate = clean; break; }
            }
        }
    }
    if (!candidate) {
        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
        [fmt setDateFormat:@"yyyyMMdd_HHmmss"];
        candidate = [NSString stringWithFormat:@"user_%@", [fmt stringFromDate:[NSDate date]]];
    }
    return candidate;
}

- (void)fs_handleDownloadTap:(UIButton *)btn {
    @try {
        UIWindow *w = [UIView fs_activeWindow];
        if (!w) { [UIView fs_showToast:@"لا توجد نافذة نشطة"]; return; }

        // find candidate view containing media
        UIView *candidate = nil;
        for (UIView *v in w.subviews.reverseObjectEnumerator) {
            if ([v fs_containsLargeMedia]) { candidate = v; break; }
            for (UIView *sv in v.subviews.reverseObjectEnumerator) {
                if ([sv fs_containsLargeMedia]) { candidate = sv; break; }
            }
            if (candidate) break;
        }
        if (!candidate) { [UIView fs_showToast:@"لم يتم العثور على وسائط"]; return; }

        NSString *username = [candidate fs_guessUsername];
        UIImage *img = [candidate fs_firstImage];
        NSURL *foundURL = nil;
        AVAsset *asset = [candidate fs_firstVideoAssetReturningURL:&foundURL];

        UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"SaveGram" message:@"اختر الإجراء" preferredStyle:UIAlertControllerStyleActionSheet];

        if (img) {
            [sheet addAction:[UIAlertAction actionWithTitle:@"📷 حفظ الصورة" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [UIView fs_showToast:@"💾 جاري حفظ الصورة..."];
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    NSData *d = UIImageJPEGRepresentation(img, 1.0);
                    NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_%@.jpg", username, [[NSUUID UUID] UUIDString]]];
                    [d writeToFile:tmp atomically:YES];
                    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                        [PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:[NSURL fileURLWithPath:tmp]];
                    } completionHandler:^(BOOL success, NSError * _Nullable error) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (success) [UIView fs_showToast:@"✅ صورة حفظت"];
                            else [UIView fs_showToast:@"❌ فشل حفظ الصورة"];
                        });
                    }];
                });
            }]];
        }

        if (asset || foundURL) {
            [sheet addAction:[UIAlertAction actionWithTitle:@"🎞 حفظ الفيديو" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [UIView fs_showToast:@"🎥 جاري حفظ الفيديو..."];
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                    if (foundURL && foundURL.isFileURL) {
                        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                            [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:foundURL];
                        } completionHandler:^(BOOL success, NSError * _Nullable error) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                if (success) [UIView fs_showToast:@"✅ فيديو حفظ"];
                                else [UIView fs_showToast:@"❌ فشل حفظ الفيديو"];
                            });
                        }];
                        return;
                    }
                    // else export asset
                    AVAsset *useAsset = asset;
                    if (!useAsset && foundURL) useAsset = [AVURLAsset URLAssetWithURL:foundURL options:nil];
                    if (!useAsset) { dispatch_async(dispatch_get_main_queue(), ^{ [UIView fs_showToast:@"❌ لا يوجد فيديو صالح"]; }); return; }
                    NSString *fname = [NSString stringWithFormat:@"%@_%@.mp4", username, [[NSUUID UUID] UUIDString]];
                    NSString *outPath = [NSTemporaryDirectory() stringByAppendingPathComponent:fname];
                    NSURL *outURL = [NSURL fileURLWithPath:outPath];
                    NSArray *presets = [AVAssetExportSession exportPresetsCompatibleWithAsset:useAsset];
                    NSString *preset = AVAssetExportPresetHighestQuality;
                    if ([presets containsObject:AVAssetExportPresetPassthrough]) preset = AVAssetExportPresetPassthrough;
                    AVAssetExportSession *export = [[AVAssetExportSession alloc] initWithAsset:useAsset presetName:preset];
                    if (!export) { dispatch_async(dispatch_get_main_queue(), ^{ [UIView fs_showToast:@"❌ فشل إنشاء جلسة التصدير"]; }); return; }
                    export.outputURL = outURL;
                    export.outputFileType = AVFileTypeMPEG4;
                    export.shouldOptimizeForNetworkUse = YES;
                    [export exportAsynchronouslyWithCompletionHandler:^{
                        if (export.status == AVAssetExportSessionStatusCompleted) {
                            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                                [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:outURL];
                            } completionHandler:^(BOOL success2, NSError * _Nullable err2) {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    if (success2) [UIView fs_showToast:@"✅ فيديو حفظ"];
                                    else [UIView fs_showToast:@"❌ فشل حفظ الفيديو"];
                                });
                            }];
                        } else {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [UIView fs_showToast:@"❌ فشل تصدير الفيديو"];
                            });
                        }
                    }];
                });
            }]];
        }

        [sheet addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
        UIViewController *top = [UIView fs_activeWindow].rootViewController;
        while (top.presentedViewController) top = top.presentedViewController;
        if (sheet.popoverPresentationController) {
            sheet.popoverPresentationController.sourceView = btn;
            sheet.popoverPresentationController.sourceRect = btn.bounds;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [top presentViewController:sheet animated:YES completion:nil];
        });
    } @catch (NSException *e) {
        NSLog(@"[FileSaver] Exception tap: %@", e.reason);
    }
}

@end

// --- Monitor window periodically and show/hide button dynamically ---

@interface UIWindow (FSMonitor)
- (void)fs_startMonitor;
@end

@implementation UIWindow (FSMonitor)

- (void)fs_startMonitor {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSTimer *t = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(fs_checkMedia) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:t forMode:NSRunLoopCommonModes];
    });
}

- (void)fs_checkMedia {
    BOOL found = NO;
    for (UIView *v in self.subviews) {
        if ([v fs_containsLargeMedia]) { found = YES; break; }
        for (UIView *sv in v.subviews) {
            if ([sv fs_containsLargeMedia]) { found = YES; break; }
        }
        if (found) break;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        UIButton *btn = (UIButton *)[self viewWithTag:0xFA5_0001];
        if (!btn) {
            btn = [UIButton buttonWithType:UIButtonTypeCustom];
            btn.frame = CGRectMake(self.bounds.size.width - 80, self.bounds.size.height - 150, 60, 60);
            btn.layer.cornerRadius = 30;
            btn.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];
            [btn setTitle:@"⬇️" forState:UIControlStateNormal];
            btn.titleLabel.font = [UIFont systemFontOfSize:30];
            btn.tag = 0xFA5_0001;
            btn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
            [btn addTarget:self action:@selector(fs_handleDownloadTap:) forControlEvents:UIControlEventTouchUpInside];
            btn.hidden = YES;
            [self addSubview:btn];
        }
        btn.hidden = !found;
    });
}

@end

%ctor {
    NSLog(@"[FileSaverTweak] loaded");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *w = [UIView fs_activeWindow];
        if (w) [w fs_startMonitor];
    });
}
