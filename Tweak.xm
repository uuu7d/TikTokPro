#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface MyWelcomeViewController : UIViewController <WKNavigationDelegate, WKScriptMessageHandler>
@end

@implementation MyWelcomeViewController

- (NSString *)htmlContent {
    
    NSString *imageURL = @"https://k.top4top.io/p_3620vz4xv0.jpeg";
    NSString *groupLink = @"https://quran.ksu.edu.sa/m.php#aya=56_1";

    return [NSString stringWithFormat:
    @"<!DOCTYPE html>"
    "<html lang=\"ar\" dir=\"rtl\">"
    "<head>"
    "<meta charset=\"UTF-8\">"
    "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">"
    "<title>مرحبًا بالنور 🙋🏻✨</title>"
    "<style>"
        "@import url('https://fonts.googleapis.com/css2?family=Beiruti:wght@200..900&display=swap');"
        "body{font-family:'Beiruti',sans-serif;background:#22223b;color:white;margin:0;height:100%%;"
        "display:flex;align-items:center;justify-content:center;overflow:hidden;}"
        ".box{background:#4a4e69;padding:35px;border-radius:28px;max-width:460px;width:92%%;"
        "text-align:center;animation:fadeIn 1s forwards;opacity:0;}"
        "@keyframes fadeIn{to{opacity:1;}}"
        "a{display:block;padding:14px;border-radius:12px;margin-bottom:12px;font-weight:700;"
        "text-decoration:none;box-shadow:0 4px 12px rgba(0,0,0,0.3);}"
        ".fake-btn{background:#ffb703;color:#000;}"
        ".snap-btn{background:#e56b6f;color:white;}"
        ".close-btn{background:#2a9d8f;color:white;}"
        "img{width:85px;height:85px;border-radius:50%%;margin-bottom:18px;border:3px solid #c9ada7;}"
    "</style>"
    "</head>"
    "<body>"
        "<div class='box'>"
            "<img src='%@'>"
            "<h2>(وَفِي السَّمَاءِ رِزْقُكُمْ وَمَا تُوعَدُونَ)</h2>"

            "<a href=\"javascript:window.webkit.messageHandlers.fakeLocation.postMessage('open-map');\" class='fake-btn'>تحديد موقع وهمي</a>"

            "<a href=\"%@\" class='snap-btn' target=\"_blank\">سنابي يالشيّخ ✨</a>"

            "<a href=\"javascript:window.webkit.messageHandlers.actionHandler.postMessage('start');\" class='close-btn'>🔥 متابعة وفتح التطبيق</a>"
        "</div>"
    "</body>"
    "</html>",
    imageURL,
    groupLink];
}

#pragma mark - Fake Location Page

- (NSString *)mapHTML {
    return @"<!DOCTYPE html>"
    "<html><head><meta name='viewport' content='initial-scale=1.0'/>"
    "<style>html,body,#map{height:100%%;margin:0;padding:0;} button{position:absolute;top:20px;left:20px;padding:12px;background:white;border-radius:12px;font-weight:bold;}</style>"
    "<script src='https://maps.googleapis.com/maps/api/js?key=AIzaSyB-LIVE-DUMMY'></script>"
    "<script>"
    "let map;"
    "function init(){"
        "map=new google.maps.Map(document.getElementById('map'),{center:{lat:24.7136,lng:46.6753},zoom:14,mapTypeId:'satellite'});"
        "map.addListener('click',function(e){sendCoord(e.latLng.lat(),e.latLng.lng());});"
    "}"
    "function sendCoord(lat,lng){window.webkit.messageHandlers.fakeLocation.postMessage({lat:lat,lng:lng});}"
    "</script>"
    "</head>"
    "<body onload='init()'>"
        "<div id='map'></div>"
    "</body></html>";
}

#pragma mark - viewDidLoad

- (void)viewDidLoad {
    [super viewDidLoad];

    WKUserContentController *userContent = [WKUserContentController new];
    [userContent addScriptMessageHandler:self name:@"actionHandler"];
    [userContent addScriptMessageHandler:self name:@"fakeLocation"];

    WKWebViewConfiguration *config = [WKWebViewConfiguration new];
    config.userContentController = userContent;

    WKWebView *web = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:config];
    web.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    [web loadHTMLString:[self htmlContent] baseURL:nil];

    web.opaque = NO;
    web.backgroundColor = UIColor.clearColor;
    self.view.backgroundColor = UIColor.clearColor;

    [self.view addSubview:web];
}

#pragma mark - Handle JS Messages

- (void)userContentController:(WKUserContentController*)c didReceiveScriptMessage:(WKScriptMessage*)m {

    if ([m.name isEqual:@"actionHandler"] && [m.body isEqual:@"start"]) {

        NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:@"com.yourcompany.welcam-tool"];
        [d setDouble:[[NSDate date] timeIntervalSince1970] forKey:@"lastWelcomeTime"];
        [d synchronize];

        [self.view removeFromSuperview];
        return;
    }

    if ([m.name isEqual:@"fakeLocation"]) {

        if ([m.body isKindOfClass:[NSString class]] && [m.body isEqual:@"open-map"]) {

            WKWebView *mapView = [self.view viewWithTag:777];
            if (!mapView) {
                WKWebViewConfiguration *conf = [WKWebViewConfiguration new];
                WKWebView *map = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:conf];
                map.tag = 777;
                [map loadHTMLString:[self mapHTML] baseURL:nil];
                [self.view addSubview:map];
            }
            return;
        }

        if ([m.body isKindOfClass:[NSDictionary class]]) {

            double lat = [m.body[@"lat"] doubleValue];
            double lon = [m.body[@"lng"] doubleValue];

            NSLog(@"[welcam-tool] Fake Location Selected: %f, %f", lat, lon);

            // هنا تربط الهُوك الحقيقي للموقع داخل الـ tweak
            [[NSNotificationCenter defaultCenter] postNotificationName:@"FakeLocationChanged"
                                                                object:nil
                                                              userInfo:@{@"lat": @(lat), @"lon": @(lon)}];
        }
    }
}

@end