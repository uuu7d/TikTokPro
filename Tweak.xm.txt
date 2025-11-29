// هاذي الاداة مقدمة هدية لا يتم بيعها او شي أخر رجاءً 

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface MyWelcomeViewController : UIViewController <WKNavigationDelegate, WKScriptMessageHandler>
@end

@implementation MyWelcomeViewController

- (NSString *)htmlContent {
    
    NSString *imageURL = @"https://g.top4top.io/p_3573a5fi00.png";
    NSString *channelLink = @"https://t.me/Dopamine202416";
    NSString *groupLink = @"https://t.me/OSI_GOD";
    
    return [NSString stringWithFormat:
            @"<!DOCTYPE html>"
            "<html lang=\"ar\" dir=\"rtl\">"
            "<head>"
                "<meta charset=\"UTF-8\">"
                "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">"
                "<title>حييّت يا مسيّر 🙋🏻</title>"
                "<style>"
                    "@import url('https://fonts.googleapis.com/css2?family=Cairo:wght@400;700&display=swap');"
                    "html, body {"
                        "height: 100%%;"
                        "overflow: hidden;"
                    "}"
                    ":root {"
                        "--primary-color: #4a4e69;"
                        "--accent-color: #9a8c98;"
                        "--bg-color: #22223b;"
                        "--text-color: #f2e9e4;"
                    "}"
                    "body {"
                        "font-family: 'Cairo', sans-serif;"
                        "background-color: var(--bg-color);"
                        "color: var(--text-color);"
                        "display: flex;"
                        "justify-content: center;"
                        "align-items: center;"
                        "margin: 0;"
                        "padding: 0;"
                    "}"
                    ".welcome-container {"
                        "background-color: var(--primary-color);"
                        "border-radius: 25px;"
                        "padding: 40px;"
                        "box-shadow: 0 15px 30px rgba(0, 0, 0, 0.5);"
                        "text-align: center;"
                        "max-width: 450px;"
                        "width: 90%%;"
                        "opacity: 0;"
                        "animation: fadeIn 1s ease-out forwards;"
                        "box-sizing: border-box;"
                    "}"
                    "@keyframes fadeIn { to { opacity: 1; } }"
                    ".animated-image {"
                        "width: 80px;"
                        "height: 80px;"
                        "margin-bottom: 20px;"
                        "border-radius: 50%%;"
                        "border: 3px solid var(--accent-color);"
                        "display: inline-block;"
                        "animation: pulse 1.5s infinite ease-in-out;"
                    "}"
                    "@keyframes pulse {"
                        "0%%, 100%% { transform: scale(1); }"
                        "50%% { transform: scale(1.05); }"
                    "}"
                    "h1 {"
                        "color: var(--text-color);"
                        "font-weight: 700;"
                        "margin-top: 0;"
                        "margin-bottom: 10px;"
                        "font-size: 2.2rem;"
                        "letter-spacing: 1px;"
                    "}"
                    "p {"
                        "color: var(--text-color);"
                        "font-size: 1.1rem;"
                        "line-height: 1.6;"
                        "margin-bottom: 30px;"
                    "}"
                    ".buttons-group a {"
                        "display: block;"
                        "text-decoration: none;"
                        "color: var(--primary-color);"
                        "background-color: var(--accent-color);"
                        "padding: 15px 25px;"
                        "border-radius: 12px;"
                        "font-weight: 700;"
                        "font-size: 1.1rem;"
                        "margin-bottom: 15px;"
                        "transition: background-color 0.3s ease, transform 0.2s ease;"
                        "box-shadow: 0 4px 10px rgba(0, 0, 0, 0.3);"
                    "}"
                    ".buttons-group a:hover {"
                        "background-color: #c9ada7;"
                        "transform: translateY(-2px);"
                    "}"
                    ".channel-btn {"
                        "background-color: #0088cc !important;"
                        "color: white !important;"
                    "}"
                    ".group-btn {"
                        "background-color: #e56b6f !important;"
                        "color: white !important;"
                    "}"
                    ".close-btn {"
                        "background-color: #2a9d8f !important;"
                        "color: white !important;"
                    "}"
                "</style>"
            "</head>"
            "<body>"
                "<div class=\"welcome-container\">"
                    
                    "<img class=\"animated-image\" src=\"%@\" alt=\"نجمة الترحيب\">"

                    "<h1>(وَفِي السَّمَاءِ رِزْقُكُمْ وَمَا تُوعَدُونَ)</h1>"
                    "<p>الدنيا بخير</p>"
                    
                    "<div class=\"buttons-group\">"
                        
                        "<a href=\"%@\" target=\"_blank\" class=\"channel-btn\">قناتي بالتيليجرام </a>"
                        
                        "<a href=\"%@\" target=\"_blank\" class=\"group-btn\">سنابي يالشييّخ ✨</a>"
                        
                        "<a href=\"javascript:window.webkit.messageHandlers.actionHandler.postMessage('start');\" class=\"close-btn\">🔥 متابعة وفتح التطبيق</a>"
                    "</div>"
                "</div>"
            "</body>"
            "</html>",
  
            imageURL,
            channelLink,
            groupLink
    ];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    WKUserContentController *userContentController = [[WKUserContentController alloc] init];
    [userContentController addScriptMessageHandler:self name:@"actionHandler"];
    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    configuration.userContentController = userContentController;
    
    WKWebView *webView = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:configuration];
    webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    webView.scrollView.scrollEnabled = NO;
    webView.scrollView.bounces = NO;
    
    [webView loadHTMLString:[self htmlContent] baseURL:nil];
    
    
    webView.opaque = NO;
    webView.backgroundColor = [UIColor clearColor]; 
    self.view.backgroundColor = [UIColor clearColor]; 
    
    [self.view addSubview:webView];
}


- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.name isEqualToString:@"actionHandler"]) {
        NSString *action = (NSString *)message.body;
        if ([action isEqualToString:@"start"]) {
            
            [self.view removeFromSuperview];
            NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.yourcompany.welcam-tool"];
            [defaults setBool:YES forKey:@"hasSeenWelcomeScreen"];
            [defaults synchronize];
        }
    }
}

@end



%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.yourcompany.welcam-tool"];
    BOOL hasSeenWelcome = [defaults boolForKey:@"hasSeenWelcomeScreen"];
    if (!hasSeenWelcome && self.parentViewController == nil && keyWindow && self.view.window == keyWindow) {
        
        
        if ([self isKindOfClass:[MyWelcomeViewController class]]) {
            return;
        }

        MyWelcomeViewController *welcomeVC = [[MyWelcomeViewController alloc] init];
        
        
        welcomeVC.view.frame = self.view.bounds;
        [self.view addSubview:welcomeVC.view];
        [self addChildViewController:welcomeVC];
        [welcomeVC didMoveToParentViewController:self];

        NSLog(@"[welcam-tool] Welcome Screen Displayed.");
    }
}

%end

%ctor {
    
    CFStringRef appID = CFSTR("com.yourcompany.welcam-tool");
    CFPreferencesAppSynchronize(appID);
}
