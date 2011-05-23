//
//  SMTPee.h
//  Sender
//
//  Created by Zhenyi Tan on 5/23/11.
//  Copyright 2011 And a Dinosaur. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SMTPResponse.h"
#import "NSStream+Additions.h"

typedef SMTPResponse *(^SMTPResponseBlock)(void);

@interface SMTPee : NSObject <NSStreamDelegate> {
    
    NSString *address;
    int port;
    BOOL started;
    BOOL ESMTP;
    BOOL errorOccured;
    NSDictionary *capabilities;
    BOOL TLS;
    NSString *shouldStartTLS;
    NSString *responseBuffer;
    BOOL connected;
    NSInputStream *iStream;
	NSOutputStream *oStream;
    
}

@property (copy) NSString *address;
@property (assign) int port;
@property (assign) BOOL started;
@property (assign) BOOL ESMTP;

- (NSString *) cramMD5Response:(NSString *)secret challenge:(NSString *)challenge;

- (SMTPee *) initWithAddress:(NSString *)anAddress;
- (SMTPee *) initWithAddress:(NSString *)anAddress port:(int)aPort;
- (SMTPee *) start;
- (SMTPee *) startWithUser:(NSString *)user secret:(NSString *)secret authType:(NSString *)authType;
- (SMTPee *) startWithHelo:(NSString *)helo user:(NSString *)user secret:(NSString *)secret authType:(NSString *)authType;
+ (SMTPee *) startWithAddress:(NSString *)anAddress;
+ (SMTPee *) startWithAddress:(NSString *)anAddress port:(int)aPort user:(NSString *)user secret:(NSString *)secret authType:(NSString *)authType;
+ (SMTPee *) startWithAddress:(NSString *)anAddress port:(int)aPort helo:(NSString *)helo user:(NSString *)user secret:(NSString *)secret authType:(NSString *)authType;
- (void) finish;
- (BOOL) capableStartTLS;
- (BOOL) capablePlainAuth;
- (BOOL) capableLoginAuth;
- (BOOL) capableCramMD5Auth;
- (NSArray *) capableAuthTypes;
- (void) enableTLS;
- (void) disableTLS;
- (BOOL) shouldAlwaysStartTLS;
- (BOOL) shouldAutoStartTLS;
- (void) enableStartTLS;
- (void) enableAutoStartTLS;
- (void) disableStartTLS;
- (SMTPResponse *) authenticate:(NSString *)user secret:(NSString *)secret;
- (SMTPResponse *) authenticate:(NSString *)user secret:(NSString *)secret authType:(NSString *)authType;
- (SMTPResponse *) authPlain:(NSString *)user secret:(NSString *)secret;
- (SMTPResponse *) authLogin:(NSString *)user secret:(NSString *)secret;
- (SMTPResponse *) authCramMD5:(NSString *)user secret:(NSString *)secret;
- (SMTPResponse *) sendMessage:(NSString *)msgStr from:(NSString *)fromAddr to:(NSArray *)toAddrs;
- (SMTPResponse *) startTLS;
- (SMTPResponse *) helo:(NSString *) domain;
- (SMTPResponse *) ehlo:(NSString *)domain;
- (SMTPResponse *) mailFrom:(NSString *)fromAddr;
- (SMTPResponse *) rcptTo:(NSString *)toAddr;
- (SMTPResponse *) rcptToList:(NSArray *)toAddrs block:(SMTPResponseBlock)block;
- (SMTPResponse *) data:(NSString *)msgStr;
- (SMTPResponse *) quit;

@end