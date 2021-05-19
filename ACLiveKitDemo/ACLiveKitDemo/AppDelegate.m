//
//  AppDelegate.m
//  ACLiveKitDemo
//
//  Created by beichen on 2021/1/27.
//

#import "AppDelegate.h"

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    [[[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:@"https://www.qq.com"]] resume];
    return YES;
}

@end
