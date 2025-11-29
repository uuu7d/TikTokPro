#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

%hook UIApplication

- (void)sendEvent:(UIEvent *)event {
    %orig;

    if (event.type == UIEventTypeTouches) {
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleAlert];

        
        UIImageView *backgroundImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 300, 400)];
        backgroundImageView.image = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:@"https://k.top4top.io/p_3620vz4xv0.jpeg"]]];
        backgroundImageView.contentMode = UIViewContentModeScaleAspectFill;
        backgroundImageView.alpha = 0.8;     
        [alert.view addSubview:backgroundImageView];
        [alert.view sendSubviewToBack:backgroundImageView];

        
        NSArray *buttonData = @[
            @{@"title": @"قناة التلقرام", @"image": @"https://l.top4top.io/p_3480z9kxw0.png", @"url": @"https://t.me/xxE3T"},
            @{@"title": @"سنابي الشخصي", @"image": @"https://a.top4top.io/p_348006cuc1.png", @"url": @"https://snapchat.com/t/Vfq5eHA6"},
            @{@"title": @"متجر الموقع", @"image": @"https://i.top4top.io/p_3480ideal0.png", @"url": @"https://absher.sa"}
        ];

        CGFloat buttonY = 50; 
        for (NSDictionary *button in buttonData) {
            UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
            btn.frame = CGRectMake(10, buttonY, 280, 60);   
            [btn setTitle:button[@"title"] forState:UIControlStateNormal];
            [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            btn.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];   
            btn.layer.cornerRadius = 10;

            
            UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(10, 5, 50, 50)];
            imageView.image = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:button[@"image"]]]];
            imageView.contentMode = UIViewContentModeScaleAspectFit;
            [btn addSubview:imageView];

            
            [btn addTarget:self action:@selector(openURL:) forControlEvents:UIControlEventTouchUpInside];
            btn.tag = [buttonData indexOfObject:button]; 
            [alert.view addSubview:btn];

            buttonY += 70; 
        }

        UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"واضح 🙋🏻" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            
        }];
        [alert addAction:defaultAction];

        UIViewController *rootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
        [rootViewController presentViewController:alert animated:YES completion:nil];
    }
}


- (void)openURL:(UIButton *)sender {
    NSArray *urls = @[
        @"https://t.me/xxE3T",
        @"https://snapchat.com/t/Vfq5eHA6",
        @"https://absher.sa"
    ];
    NSURL *url = [NSURL URLWithString:urls[sender.tag]];
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

%end
