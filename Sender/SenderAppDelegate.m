//
//  SenderAppDelegate.m
//  Sender
//
//  Created by Zhenyi Tan on 5/23/11.
//  Copyright 2011 And a Dinosaur. All rights reserved.
//

#import "SenderAppDelegate.h"
#import "SMTPee.h"

@implementation SenderAppDelegate


@synthesize window=_window;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    NSArray *messages = [NSArray arrayWithObjects:
                         @"From: <from@gmail.com>",
                         @"To: <to@gmail.com>",
                         @"Subject: O HAI",
                         @"",
                         @"I CAN HAZ SMTP?\nKTHXBAI!",
                         @".",
                         nil];
    SMTPee *smtp = [[SMTPee alloc] initWithAddress:@"smtp.gmail.com" port:465];
    [smtp enableTLS];
    [smtp startWithUser:@"from@gmail.com" secret:@"password" authType:@"login"];
    [smtp sendMessage:[messages componentsJoinedByString:@"\r\n"] from:@"from@gmail.com" to:[NSArray arrayWithObjects:@"to@gmail.com", nil]];
    [smtp finish];

    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
     */
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    /*
     Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
     */
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    /*
     Called when the application is about to terminate.
     Save data if appropriate.
     See also applicationDidEnterBackground:.
     */
}

- (void)dealloc
{
    [_window release];
    [super dealloc];
}

@end
