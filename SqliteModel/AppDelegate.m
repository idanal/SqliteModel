//
//  AppDelegate.m
//  SQLiteDAO
//
//  Created by 01369760 on 2017/7/24.
//  Copyright © 2017年 danal. All rights reserved.
//

#import "AppDelegate.h"
#import "SQLiteModel.h"
#import "User.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"empty.sqlite" ofType:nil];
    
    NSString *dest = [[SQLite shared] copyDB:path];
    [[SQLite shared] open:dest];
    
    NSMutableArray *list = [User findAll];
    for (User *u in list) {
        NSLog(@"%@:%@-%ld",u.rowid, u.name, u.age);
    }
    
    User *u = [User find:@"name = '%@'", @"usertest"].firstObject;
    if (!u){
        u = [User new];
        u.name = @"usertest";
        [u save];
    }
    
    if ([User count:@"age > 0"].integerValue < 3){
        for (int i = 0; i < 3; i++){
            User *u = [User new];
            u.name = [NSString stringWithFormat:@"user_%02d", i];
            u.age = 20+i;
            [u save];
        }
    }
    
    list = [User findAll];
    NSLog(@"%@", list);
    
    list = [User find:@"age > 0 order by rowid desc limit 1"];
    NSLog(@"%@", list);
    
    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


@end
