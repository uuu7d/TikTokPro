// Tweak.xm
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <Photos/Photos.h>
#import <objc/runtime.h>

// ---------- Config ----------
static NSTimeInterval const kSGScanInterval = 0.5; // فحص المشهد كل نصف ثانية
static CGFloat const kSGButtonSizeW = 52.0;
static CGFloat const kSGButtonSizeH = 52.0;
static CGFloat const kSGRightMargin = 8.0;

// ---------- Helpers (Objective-C implementations so the compiler knows selectors) ----------
@interface UIView (SGHelpers)
- (BOOL)sg_isVisibleInWindow;
- (UIImageView *)sg_findVisibleImageViewRecursively;
- (AVPlayerLayer *)sg_findPlayerLayerRecursivelyInLayer:(CALayer *)layer;
- (AVPlayerLayer *)sg_findPlayerLayerRecursivelyInView:(UIView *)view;
@end

@implementation UIView (SGHelpers)

- (BOOL)sg_isVisibleInWindow {
    if (!self.window || self.hidden || self.alpha <= 0.01) return NO;
    CGRect bounds = self.bounds;
    if (CGRectIsEmpty(bounds)) return NO;
    // convert to window coords
    CGRect r = [self convertRect:self.bounds toView:self.window];
    CGRect winBounds = self.window.bounds;
    return CGRectIntersectsRect(r, winBounds);
}

- (UIImageView *)sg_findVisibleImageViewRecursively {
    if ([self isKindOfClass:[UIImageView class]]) {
        UIImageView *iv = (UIImageView *)self;
        if (iv.image && [iv sg_isVisibleInWindow]) return iv;
    }
    for (UIView *sub in self.subviews) {
        UIImageView *found = [sub sg_findVisibleImageViewRecursively];
        if (found) return found;
    }
    return nil;
}

- (AVPlayerLayer *)sg_findPlayerLayerRecursivelyInLayer:(CALayer *)layer {
    if (!layer) return nil;
    if ([layer isKindOfClass:[AVPlayerLayer class]]) return (AVPlayerLayer *)layer;
    for (CALayer *s in layer.sublayers) {
        AVPlayerLayer *f = [self sg_findPlayerLayerRecursivelyInLayer:s];
        if (f) return f;
    }
    return nil;
}

- (AVPlayerLayer *)sg_findPlayerLayerRecursivelyInView:(UIView *)view {
    AVPlayerLayer *pl = [self sg_findPlayerLayerRecursivelyInLayer:view.layer];
    if (pl && [view sg_isVisibleInWindow]) return pl;
    for (UIView *sub in view.subviews) {
        AVPlayerLayer *found = [self sg_findPlayerLayerRecursivelyInView:sub];
        if (found) return found;
    }
    return nil;
}

@end

// ---------- Floating button manager (singleton-like) ----------
%ctor {
    @autoreleasepool {
        // create a background thread timer to add button after short delay
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] addObserverForName:UIWindowDidBecomeVisibleNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
                // ensure button present when windows change
                // handled by our singleton below
            }];
            // start manager
            [SGFloatingButtonManager sharedManager];
        });
    }
}

@interface SGFloatingButtonManager : NSObject
@property (nonatomic, strong) UIButton *button;
@property (nonatomic, strong) NSTimer *scanTimer;
+ (instancetype)sharedManager;
@end

@implementation SGFloatingButtonManager

+ (instancetype)sharedManager {
    static SGFloatingButtonManager *inst;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[SGFloatingButtonManager alloc] init];
        [inst setup];
    });
    return inst;
}

- (void)setup {
    // create button window-level (on keyWindow)
    dispatch_async(dispatch_get_main_queue(), ^{
        [self createButton];
        // start scanning
        self.scanTimer = [NSTimer scheduledTimerWithTimeInterval:kSGScanInterval target:self selector:@selector(scanForMedia) userInfo:nil repeats:YES];
    });
}

- (void)createButton {
    if (self.button) return;
    // place on key window
    UIWindow *w = UIApplication.sharedApplication.keyWindow ?: UIApplication.sharedApplication.windows.firstObject;
    if (!w) {
        // will try again later
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self createButton];
        });
        return;
    }

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = CGRectMake(w.bounds.size.width - kSGRightMargin - kSGButtonSizeW,
                           (w.bounds.size.height - kSGButtonSizeH) / 2.0,
                           kSGButtonSizeW, kSGButtonSizeH);
    btn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    btn.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.55];
    btn.layer.cornerRadius = kSGButtonSizeW / 2.0;
    btn.clipsToBounds = YES;
    btn.tintColor = [UIColor whiteColor];
    btn.titleLabel.font = [UIFont systemFontOfSize:24];
    [btn setTitle:@"📥" forState:UIControlStateNormal];
    btn.layer.shadowColor = [UIColor blackColor].CGColor;
    btn.layer.shadowOpacity = 0.3;
    btn.layer.shadowRadius = 3;
    btn.layer.shadowOffset = CGSizeMake(0, 2);
    [btn addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
    btn.hidden = YES; // يظهر فقط عند وجود محتوى
    [w addSubview:btn];
    self.button = btn;

    // make button above other content
    [w bringSubviewToFront:btn];

    // respond to rotations/resizing
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidChange:) name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
}

- (void)windowDidChange:(NSNotification *)n {
    UIWindow *w = UIApplication.sharedApplication.keyWindow ?: UIApplication.sharedApplication.windows.firstObject;
    if (!w || !self.button) return;
    self.button.frame = CGRectMake(w.bounds.size.width - kSGRightMargin - kSGButtonSizeW,
                                   (w.bounds.size.height - kSGButtonSizeH) / 2.0,
                                   kSGButtonSizeW, kSGButtonSizeH);
    [w bringSubviewToFront:self.button];
}

// ---------------- scanning logic ----------------
- (void)scanForMedia {
    @autoreleasepool {
        UIWindow *window = UIApplication.sharedApplication.keyWindow ?: UIApplication.sharedApplication.windows.firstObject;
        if (!window) {
            if (self.button) self.button.hidden = YES;
            return;
        }

        // Search windows front-to-back
        UIView *foundView = nil;
        UIImageView *iv = nil;
        AVPlayerLayer *pl = nil;

        for (UIWindow *win in UIApplication.sharedApplication.windows.reverseObjectEnumerator) {
            // skip some system windows
            if (win == nil) continue;
            // find visible image view
            iv = [win sg_findVisibleImageViewRecursively];
            if (iv) { foundView = iv; break; }
            pl = [win sg_findPlayerLayerRecursivelyInView:win];
            if (pl) { foundView = win; break; }
        }

        BOOL shouldShow = (iv != nil) || (pl != nil);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.button) {
                self.button.hidden = !shouldShow;
            }
        });
    }
}

// ---------------- action ----------------
- (void)buttonTapped:(id)sender {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.button setTitle:@"⏳" forState:UIControlStateNormal];
        self.button.userInteractionEnabled = NO;
    });

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        // find topmost media again
        UIWindow *window = UIApplication.sharedApplication.keyWindow ?: UIApplication.sharedApplication.windows.firstObject;
        UIImageView *iv = nil;
        AVPlayerLayer *pl = nil;

        for (UIWindow *win in UIApplication.sharedApplication.windows.reverseObjectEnumerator) {
            iv = [win sg_findVisibleImageViewRecursively];
            if (iv) break;
            pl = [win sg_findPlayerLayerRecursivelyInView:win];
            if (pl) break;
        }

        if (iv) {
            // try to get original URL via KVC heuristics
            NSURL *maybeURL = [SGFloatingButtonManager findPossibleImageURLFromView:iv];
            if (maybeURL) {
                [SGFloatingButtonManager downloadImageFromURL:maybeURL completion:^(NSData *data, NSError *err) {
                    if (data) {
                        UIImage *img = [UIImage imageWithData:data];
                        if (img) {
                            [SGFloatingButtonManager saveImageToPhotos:img completion:^(BOOL ok, NSError *e) {
                                [self finalizeWithMessage:(ok?@"✅ Image saved":(e.localizedDescription?:@"❌ Failed"))];
                            }];
                        } else {
                            // fallback to existing image
                            [SGFloatingButtonManager saveImageToPhotos:iv.image completion:^(BOOL ok, NSError *e) {
                                [self finalizeWithMessage:(ok?@"✅ Image saved":(e.localizedDescription?:@"❌ Failed"))];
                            }];
                        }
                    } else {
                        // fallback
                        [SGFloatingButtonManager saveImageToPhotos:iv.image completion:^(BOOL ok, NSError *e) {
                            [self finalizeWithMessage:(ok?@"✅ Image saved":(e.localizedDescription?:@"❌ Failed"))];
                        }];
                    }
                }];
            } else {
                // no URL, save displayed image
                [SGFloatingButtonManager saveImageToPhotos:iv.image completion:^(BOOL ok, NSError *e) {
                    [self finalizeWithMessage:(ok?@"✅ Image saved":(e.localizedDescription?:@"❌ Failed"))];
                }];
            }
            return;
        }

        if (pl) {
            // get player item asset or URL
            AVPlayer *player = pl.player;
            AVPlayerItem *item = player.currentItem;
            AVAsset *asset = item.asset;
            NSURL *assetURL = nil;
            if ([asset isKindOfClass:[AVURLAsset class]]) assetURL = ((AVURLAsset *)asset).URL;

            if (assetURL && !assetURL.isFileURL) {
                // remote URL -> download then save
                [SGFloatingButtonManager downloadVideoFromURL:assetURL completion:^(NSURL *localFile, NSError *err) {
                    if (localFile) {
                        [SGFloatingButtonManager saveVideoFileToPhotos:localFile completion:^(BOOL ok, NSError *e) {
                            [self finalizeWithMessage:(ok?@"✅ Video saved":(e.localizedDescription?:@"❌ Failed"))];
                        }];
                    } else {
                        // fallback: try export asset (if possible)
                        [SGFloatingButtonManager exportAsset:asset completion:^(NSURL *outURL, NSError *exErr) {
                            if (outURL) {
                                [SGFloatingButtonManager saveVideoFileToPhotos:outURL completion:^(BOOL ok, NSError *e) {
                                    [self finalizeWithMessage:(ok?@"✅ Video saved":(e.localizedDescription?:@"❌ Failed"))];
                                }];
                            } else {
                                [self finalizeWithMessage:exErr.localizedDescription ?: @"❌ Failed to obtain video."];
                            }
                        }];
                    }
                }];
                return;
            } else if (assetURL && assetURL.isFileURL) {
                [SGFloatingButtonManager saveVideoFileToPhotos:assetURL completion:^(BOOL ok, NSError *e) {
                    [self finalizeWithMessage:(ok?@"✅ Video saved":(e.localizedDescription?:@"❌ Failed"))];
                }];
                return;
            } else {
                // asset without URL: try export
                [SGFloatingButtonManager exportAsset:asset completion:^(NSURL *outURL, NSError *exErr) {
                    if (outURL) {
                        [SGFloatingButtonManager saveVideoFileToPhotos:outURL completion:^(BOOL ok, NSError *e) {
                            [self finalizeWithMessage:(ok?@"✅ Video saved":(e.localizedDescription?:@"❌ Failed"))];
                        }];
                    } else {
                        [self finalizeWithMessage:exErr.localizedDescription ?: @"❌ Failed to export video."];
                    }
                }];
                return;
            }
        }

        // nothing found
        [self finalizeWithMessage:@"No media detected."];
    });
}

- (void)finalizeWithMessage:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{
        // show a temporary HUD near the button
        UILabel *hud = (UILabel *)[self.button viewWithTag:0xFACEB00C];
        if (!hud) {
            hud = [[UILabel alloc] initWithFrame:CGRectMake(-140, -56, 200, 40)];
            hud.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.78];
            hud.textColor = [UIColor whiteColor];
            hud.textAlignment = NSTextAlignmentCenter;
            hud.layer.cornerRadius = 8;
            hud.clipsToBounds = YES;
            hud.tag = 0xFACEB00C;
            hud.alpha = 0.0;
            hud.font = [UIFont systemFontOfSize:14];
            [self.button addSubview:hud];
        }
        hud.text = msg;
        [UIView animateWithDuration:0.18 animations:^{ hud.alpha = 1.0; }];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.25 animations:^{ hud.alpha = 0.0; }];
        });

        [self.button setTitle:@"📥" forState:UIControlStateNormal];
        self.button.userInteractionEnabled = YES;
    });
}

// ---------- static utility methods (class methods implemented here) ----------
+ (void)downloadImageFromURL:(NSURL *)url completion:(void(^)(NSData *data, NSError *err))completion {
    if (!url) { if (completion) completion(nil, [NSError errorWithDomain:@"SG" code:0 userInfo:@{NSLocalizedDescriptionKey:@"Invalid URL"}]); return; }
    NSURLSessionDataTask *t = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        if (completion) completion(d, e);
    }];
    [t resume];
}

+ (void)downloadVideoFromURL:(NSURL *)url completion:(void(^)(NSURL *localFile, NSError *err))completion {
    if (!url) { if (completion) completion(nil, [NSError errorWithDomain:@"SG" code:0 userInfo:@{NSLocalizedDescriptionKey:@"Invalid URL"}]); return; }
    NSURLSessionDownloadTask *t = [[NSURLSession sharedSession] downloadTaskWithURL:url completionHandler:^(NSURL *loc, NSURLResponse *resp, NSError *err) {
        if (err) { if (completion) completion(nil, err); return; }
        NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID].UUIDString stringByAppendingPathExtension:(url.pathExtension.length?url.pathExtension:@"mp4")]];
        NSURL *dest = [NSURL fileURLWithPath:tmp];
        NSError *moveErr = nil;
        [[NSFileManager defaultManager] moveItemAtURL:loc toURL:dest error:&moveErr];
        if (moveErr) { if (completion) completion(nil, moveErr); } else { if (completion) completion(dest, nil); }
    }];
    [t resume];
}

+ (void)saveImageToPhotos:(UIImage *)image completion:(void(^)(BOOL ok, NSError *err))completion {
    if (!image) { if (completion) completion(NO, [NSError errorWithDomain:@"SG" code:0 userInfo:@{NSLocalizedDescriptionKey:@"No image"}]); return; }
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (status != PHAuthorizationStatusAuthorized && status != PHAuthorizationStatusLimited) {
                if (completion) completion(NO, [NSError errorWithDomain:@"SG" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Photos permission denied"}]);
                return;
            }
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
            if (completion) completion(YES, nil);
        });
    }];
}

+ (void)saveVideoFileToPhotos:(NSURL *)fileURL completion:(void(^)(BOOL ok, NSError *err))completion {
    if (!fileURL) { if (completion) completion(NO, [NSError errorWithDomain:@"SG" code:0 userInfo:@{NSLocalizedDescriptionKey:@"No file"}]); return; }
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (status != PHAuthorizationStatusAuthorized && status != PHAuthorizationStatusLimited) {
                if (completion) completion(NO, [NSError errorWithDomain:@"SG" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Photos permission denied"}]);
                return;
            }
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:fileURL];
            } completionHandler:^(BOOL success, NSError * _Nullable error) {
                if (completion) completion(success, error);
            }];
        });
    }];
}

+ (void)exportAsset:(AVAsset *)asset completion:(void(^)(NSURL *outURL, NSError *err))completion {
    if (!asset) { if (completion) completion(nil, [NSError errorWithDomain:@"SG" code:0 userInfo:@{NSLocalizedDescriptionKey:@"No asset"}]); return; }
    NSArray *presets = [AVAssetExportSession exportPresetsCompatibleWithAsset:asset];
    NSString *preset = AVAssetExportPresetPassthrough;
    if (![presets containsObject:preset]) {
        if ([presets containsObject:AVAssetExportPresetHighestQuality]) preset = AVAssetExportPresetHighestQuality;
        else if (presets.count) preset = presets.lastObject;
    }
    AVAssetExportSession *es = [[AVAssetExportSession alloc] initWithAsset:asset presetName:preset];
    if (!es) { if (completion) completion(nil, [NSError errorWithDomain:@"SG" code:2 userInfo:@{NSLocalizedDescriptionKey:@"Cannot create export session"}]); return; }
    es.shouldOptimizeForNetworkUse = YES;
    NSString *outPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID].UUIDString stringByAppendingPathExtension:@"mp4"]];
    es.outputURL = [NSURL fileURLWithPath:outPath];
    es.outputFileType = AVFileTypeMPEG4;
    [es exportAsynchronouslyWithCompletionHandler:^{
        if (es.status == AVAssetExportSessionStatusCompleted) {
            if (completion) completion(es.outputURL, nil);
        } else {
            if (completion) completion(nil, es.error ?: [NSError errorWithDomain:@"SG" code:3 userInfo:@{NSLocalizedDescriptionKey:@"Export failed"}]);
        }
    }];
}

// ---------- utility heuristics ----------
+ (NSURL *)findPossibleImageURLFromView:(UIView *)v {
    // heuristics: try common property names via KVC
    NSArray *candidates = @[@"imageURL", @"imageUrl", @"url", @"photoURL", @"image_path", @"_imageURL"];
    for (NSString *key in candidates) {
        @try {
            id val = nil;
            if ([v respondsToSelector:NSSelectorFromString(key)]) {
                val = [v valueForKey:key];
            } else {
                // also check subviews
                for (UIView *sub in v.subviews) {
                    if ([sub respondsToSelector:NSSelectorFromString(key)]) {
                        val = [sub valueForKey:key];
                        if (val) break;
                    }
                }
            }
            if ([val isKindOfClass:[NSURL class]]) return val;
            if ([val isKindOfClass:[NSString class]]) {
                NSURL *u = [NSURL URLWithString:val];
                if (u) return u;
            }
        } @catch (NSException *ex) { /* ignore */ }
    }
    return nil;
}

// ---------------------------------------------------------
@end

// End of file
