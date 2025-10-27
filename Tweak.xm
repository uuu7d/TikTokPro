// Tweak.xm
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

#pragma mark - helper: print view tree

static void printViewTreeRecursive(UIView *view, int depth) {
    if (!view) return;
    NSMutableString *pad = [NSMutableString string];
    for (int i=0;i<depth;i++) [pad appendString:@"  "];
    NSLog(@"[ViewTree] %@- %@ frame=%@", pad, NSStringFromClass([view class]), NSStringFromCGRect(view.frame));
    for (UIView *sub in view.subviews) {
        printViewTreeRecursive(sub, depth + 1);
    }
}

static void printCurrentWindowViewTree(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            // أفضل طريقة لجلب النافذة النشطة (iOS 13+ يدعم Scenes)
            UIWindow *activeWindow = nil;
            for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
                if (![scene isKindOfClass:[UIWindowScene class]]) continue;
                UIWindowScene *wscene = (UIWindowScene *)scene;
                if (wscene.activationState != UISceneActivationStateForegroundActive) continue;
                for (UIWindow *w in wscene.windows) {
                    if (w.isKeyWindow) { activeWindow = w; break; }
                }
                if (activeWindow) break;
            }
            if (!activeWindow) activeWindow = UIApplication.sharedApplication.keyWindow ?: UIApplication.sharedApplication.windows.firstObject;
            if (!activeWindow) {
                NSLog(@"[ViewTree] No active window found.");
                return;
            }
            NSLog(@"[ViewTree] === START view tree for window: %@ ===", activeWindow);
            printViewTreeRecursive(activeWindow, 0);
            NSLog(@"[ViewTree] === END view tree ===");
        } @catch (NSException *e) {
            NSLog(@"[ViewTree] Exception while printing view tree: %@", e.reason);
        }
    });
}

#pragma mark - Hooks

%hook AVURLAsset
+ (instancetype)URLAssetWithURL:(NSURL *)URL options:(NSDictionary *)options {
    @try {
        NSLog(@"[Hook][AVURLAsset] URLAssetWithURL: %@", URL);
    } @catch (NSException *e) { }
    return %orig(URL, options);
}
%end

%hook NSURLSession
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    @try {
        NSURL *u = request.URL;
        if (u) {
            NSLog(@"[Hook][NSURLSession] request URL: %@", u.absoluteString);
        } else {
            NSLog(@"[Hook][NSURLSession] request (no URL) - %@", request);
        }
    } @catch (NSException *e) { }
    return %orig(request, completionHandler);
}
%end

%hook AVPlayerItem
- (instancetype)initWithAsset:(AVAsset *)asset {
    @try {
        NSLog(@"[Hook][AVPlayerItem] initWithAsset: %@", asset);
        if ([asset isKindOfClass:[AVURLAsset class]]) {
            NSURL *u = ((AVURLAsset *)asset).URL;
            NSLog(@"[Hook][AVPlayerItem] asset URL: %@", u);
        }
    } @catch (NSException *e) { }
    return %orig(asset);
}
%end

// optional: also hook playerItem's setAsset: if applicable
%hook AVPlayerItem
- (void)setAsset:(AVAsset *)asset {
    @try {
        NSLog(@"[Hook][AVPlayerItem] setAsset: %@", asset);
        if ([asset isKindOfClass:[AVURLAsset class]]) {
            NSURL *u = ((AVURLAsset *)asset).URL;
            NSLog(@"[Hook][AVPlayerItem] setAsset URL: %@", u);
        }
    } @catch (NSException *e) { }
    %orig(asset);
}
%end

// print view tree automatically on viewDidAppear for debugging
%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    @try {
        // طباعة الشجرة بعد تأخير بسيط ليتم ترتيب الـ subviews
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            printCurrentWindowViewTree();
        });
    } @catch (NSException *e) {
        NSLog(@"[Hook][UIViewController] exception: %@", e.reason);
    }
}
%end

#pragma mark - ctor: log and optionally trigger an initial view tree print

%ctor {
    @try {
        NSLog(@"[Hook] AVURLAsset/NSURLSession/AVPlayerItem hooks installed.");
        // اطبع tree واحد عند تحميل التويك لتبدأ الفحص
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            printCurrentWindowViewTree();
        });
    } @catch (NSException *e) {
        NSLog(@"[Hook] ctor exception: %@", e.reason);
    }
}
