#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface SandboxManager : NSObject
+ (NSString *)appDocumentsPath;
+ (NSArray *)listFiles;
+ (BOOL)deleteFile:(NSString *)path;
@end

@implementation SandboxManager

+ (NSString *)appDocumentsPath {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
}

+ (NSArray *)listFiles {
    NSString *docs = [self appDocumentsPath];
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:docs error:nil];
    return files;
}

+ (BOOL)deleteFile:(NSString *)path {
    return [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
}

@end


@interface SandboxViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UIDocumentPickerDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *files;
@end

@implementation SandboxViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Sandbox Tool";
    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];

    self.files = [SandboxManager listFiles];

    UIButton *importButton = [UIButton buttonWithType:UIButtonTypeSystem];
    importButton.frame = CGRectMake(20, 50, 150, 40);
    [importButton setTitle:@"📁 استيراد ملف" forState:UIControlStateNormal];
    [importButton addTarget:self action:@selector(importFile) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:importButton];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 100, self.view.frame.size.width, self.view.frame.size.height - 100)];
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
}

- (void)importFile {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[[UTType data]]];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *selected = [urls firstObject];
    NSString *destination = [[SandboxManager appDocumentsPath] stringByAppendingPathComponent:[selected lastPathComponent]];
    [[NSFileManager defaultManager] copyItemAtURL:selected toURL:[NSURL fileURLWithPath:destination] error:nil];
    self.files = [SandboxManager listFiles];
    [self.tableView reloadData];
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.files.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
    NSString *file = self.files[indexPath.row];
    cell.textLabel.text = file;
    cell.backgroundColor = [UIColor colorWithWhite:1 alpha:0.1];
    cell.textLabel.textColor = [UIColor whiteColor];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (style == UITableViewCellEditingStyleDelete) {
        NSString *file = self.files[indexPath.row];
        NSString *fullPath = [[SandboxManager appDocumentsPath] stringByAppendingPathComponent:file];
        [SandboxManager deleteFile:fullPath];
        self.files = [SandboxManager listFiles];
        [self.tableView reloadData];
    }
}

@end


%hook UIApplication
- (void)applicationDidBecomeActive:(UIApplication *)application {
    %orig;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        SandboxViewController *sandboxVC = [SandboxViewController new];
        sandboxVC.modalPresentationStyle = UIModalPresentationOverFullScreen;
        [window.rootViewController presentViewController:sandboxVC animated:YES completion:nil];
    });
}
%end
