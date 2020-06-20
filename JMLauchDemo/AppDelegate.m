//
//  AppDelegate.m
//  JMLauchDemo
//
//  Created by JM on 2020/6/19.
//  Copyright © 2020 JM. All rights reserved.
//

#import "AppDelegate.h"
#import "ViewController.h"
#import "JMLaunchAdView.h"

#define kScreen_Bounds  [UIScreen mainScreen].bounds
#define kScreen_Height  [UIScreen mainScreen].bounds.size.height
#define kScreen_Width   [UIScreen mainScreen].bounds.size.width


@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    //  1.初始化启动页广告
    [JMLaunchAdView initImageWithAttribute:3.0 showSkipType:JMSkipShowTypeAnimation setLaunchAd:^(JMLaunchAdView *launchAd) {
        __block JMLaunchAdView *weakSelf = launchAd;
       
        //如果选择 SkipShowTypeAnimation 需要设置动画跳过按钮的属性
        [weakSelf setAnimationSkipWithAttribute:[UIColor yellowColor] lineWidth:3.0 backgroundColor:[UIColor grayColor] textColor:[UIColor blueColor]];
       
        [launchAd setWebImageWithURL:@"http://seopic.699pic.com/photo/50162/6115.jpg_wh1200.jpg" options:JMWebImageDefault result:^(UIImage *image, NSURL *url) {
            //  2.异步加载图片完成回调(设置图片尺寸)
            weakSelf.launchAdViewFrame = CGRectMake(10, 10, kScreen_Width, kScreen_Height);
            
        } adClickBlock:^{
            //  3.点击广告回调
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://www.baidu.com"] options:@{} completionHandler:nil];
        }];
    }];
    
    self.window.rootViewController = [ViewController new];
    [self.window makeKeyAndVisible];
    return YES;
}


@end
