#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <Photos/Photos.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <objc/runtime.h>

@interface CustomPopupView : UIView <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;
@property (nonatomic, strong) NSArray *sandboxFiles;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSString *currentPath;
@end

@implementation CustomPopupView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupBlurBackground];
        [self setupButtons];
        [self startObservingMedia];
        [self startObservingImages];
    }
    return self;
}

- (void)setupBlurBackground {
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialDark];
    self.blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    self.blurView.frame = self.bounds;
    self.blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:self.blurView];
}

- (void)setupButtons {
    NSArray *titles = @[@"🧹 تنظيف الكاش", @"🔁 إعادة التشغيل", @"❌ إغلاق", @"📂 تصفح الملفات"];
    SEL actions[] = {@selector(cleanCache), @selector(restartApp), @selector(closePopup), @selector(openSandbox)};

    CGFloat buttonWidth = self.frame.size.width - 60;
    CGFloat buttonHeight = 50;
    CGFloat startY = 150;

    for (int i = 0; i < titles.count; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.frame = CGRectMake(30, startY + (i * 70), buttonWidth, buttonHeight);
        [button setTitle:titles[i] forState:UIControlStateNormal];
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        button.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.25];
        button.layer.cornerRadius = 12.0;
        button.clipsToBounds = YES;
        [button addTarget:self action:actions[i] forControlEvents:UIControlEventTouchUpInside];
        [self.blurView.contentView addSubview:button];
    }
}

#pragma mark - Actions

- (void)playClickSound {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"click" ofType:@"wav"];
    if (!path) return;
    NSURL *url = [NSURL fileURLWithPath:path];
    self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
    [self.audioPlayer play];
}

- (void)cleanCache {
    [self playClickSound];
    NSString *cachePath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches"];
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:cachePath error:nil];

    unsigned long long totalSize = 0;
    for (NSString *file in files) {
        NSString *filePath = [cachePath stringByAppendingPathComponent:file];
        NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
        totalSize += [attrs fileSize];
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
    }

    double mb = totalSize / (1024.0 * 1024.0);
    NSString *msg = [NSString stringWithFormat:@"تم حذف %.2f ميغابايت من ملفات الكاش.", mb];

    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"✅ تم التنظيف"
                                                                       message:msg
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"موافق" style:UIAlertActionStyleDefault handler:nil]];
        [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
    });
}

- (void)restartApp {
    [self playClickSound];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        exit(0);
    });
}

- (void)closePopup {
    [self playClickSound];
    [UIView animateWithDuration:0.3 animations:^{
        self.alpha = 0.0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

#pragma mark - Sandbox & File Preview

- (void)openSandbox {
    [self playClickSound];
    self.currentPath = NSHomeDirectory();
    [self loadFilesAtPath:self.currentPath];

    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    UIViewController *sandboxVC = [[UIViewController alloc] init];
    sandboxVC.view.backgroundColor = [UIColor systemBackgroundColor];
    sandboxVC.title = @"ملفات التطبيق";

    self.tableView = [[UITableView alloc] initWithFrame:sandboxVC.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [sandboxVC.view addSubview:self.tableView];

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:sandboxVC];
    [window.rootViewController presentViewController:nav animated:YES completion:nil];
}

- (void)loadFilesAtPath:(NSString *)path {
    self.sandboxFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil];
}

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.sandboxFiles.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"fileCell"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"fileCell"];
    cell.textLabel.text = self.sandboxFiles[indexPath.row];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *fileName = self.sandboxFiles[indexPath.row];
    NSString *fullPath = [self.currentPath stringByAppendingPathComponent:fileName];

    BOOL isDir;
    [[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDir];
    if (isDir) {
        self.currentPath = fullPath;
        [self loadFilesAtPath:fullPath];
        [self.tableView reloadData];
        return;
    }

    NSString *ext = fullPath.pathExtension.lowercaseString;
    UIWindow *window = [UIApplication sharedApplication].keyWindow;

    if ([ext isEqualToString:@"mp4"] || [ext isEqualToString:@"mov"]) {
        AVPlayer *player = [AVPlayer playerWithURL:[NSURL fileURLWithPath:fullPath]];
        AVPlayerViewController *playerVC = [[AVPlayerViewController alloc] init];
        playerVC.player = player;

        UIBarButtonItem *saveBtn = [[UIBarButtonItem alloc] initWithTitle:@"💾 حفظ" style:UIBarButtonItemStylePlain target:self action:@selector(^{
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:[NSURL fileURLWithPath:fullPath]];
            } completionHandler:nil];
        })];

        playerVC.navigationItem.rightBarButtonItem = saveBtn;
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:playerVC];
        [window.rootViewController presentViewController:nav animated:YES completion:^{
            [player play];
        }];
    } else if ([ext isEqualToString:@"jpg"] || [ext isEqualToString:@"png"]) {
        UIViewController *imgVC = [[UIViewController alloc] init];
        imgVC.view.backgroundColor = [UIColor blackColor];
        UIImageView *imgView = [[UIImageView alloc] initWithFrame:imgVC.view.bounds];
        imgView.contentMode = UIViewContentModeScaleAspectFit;
        imgView.image = [UIImage imageWithContentsOfFile:fullPath];
        imgView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [imgVC.view addSubview:imgView];

        UIBarButtonItem *saveBtn = [[UIBarButtonItem alloc] initWithTitle:@"💾 حفظ" style:UIBarButtonItemStylePlain target:self action:@selector(^{
            UIImage *img = [UIImage imageWithContentsOfFile:fullPath];
            if (img) {
                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                    [PHAssetChangeRequest creationRequestForAssetFromImage:img];
                } completionHandler:nil];
            }
        })];
        imgVC.navigationItem.rightBarButtonItem = saveBtn;

        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:imgVC];
        [window.rootViewController presentViewController:nav animated:YES completion:nil];
    }
}

@end

#pragma mark - Floating Button

%ctor {
    if (@available(iOS 16.0, *)) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *window = [UIApplication sharedApplication].keyWindow;

            UIButton *floatingButton = [UIButton buttonWithType:UIButtonTypeSystem];
            floatingButton.frame = CGRectMake(window.bounds.size.width - 80, window.bounds.size.height - 150, 60, 60);
            floatingButton.layer.cornerRadius = 30;
            floatingButton.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.8];
            [floatingButton setTitle:@"🛠" forState:UIControlStateNormal];
            [floatingButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            floatingButton.clipsToBounds = YES;
            [floatingButton addTarget:nil action:@selector(showCustomPopup) forControlEvents:UIControlEventTouchUpInside];

            [window addSubview:floatingButton];
        });
    }
}

%hook UIApplication

- (void)showCustomPopup {
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    CustomPopupView *popup = [[CustomPopupView alloc] initWithFrame:window.bounds];
    popup.alpha = 0.0;
    [window addSubview:popup];
    [UIView animateWithDuration:0.4 animations:^{
        popup.alpha = 1.0;
    }];
}

%end
