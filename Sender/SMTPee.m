//
//  SMTPee.m
//  Sender
//
//  Created by Zhenyi Tan on 5/23/11.
//  Copyright 2011 And a Dinosaur. All rights reserved.
//

#import "SMTPee.h"

@interface SMTPee()

@property (assign) BOOL errorOccured;
@property (copy) NSDictionary *capabilities;
@property (assign) BOOL TLS;
@property (copy) NSString *shouldStartTLS;
@property (copy) NSString *responseBuffer;
@property (assign) BOOL connected;

@end


@implementation SMTPee

@synthesize address, port;
@synthesize started;
@synthesize ESMTP;
@synthesize errorOccured;
@synthesize capabilities;
@synthesize TLS;
@synthesize shouldStartTLS;
@synthesize responseBuffer;
@synthesize connected;


- (SMTPee *) initWithAddress:(NSString *)anAddress port:(int)aPort {
    if ((self = [super init])) {
        self.address = anAddress;
        self.port = aPort;
        self.ESMTP = YES;
        self.errorOccured = NO;
        self.capabilities = nil;
        self.started = NO;
        self.TLS = NO;
        self.shouldStartTLS = @"no";
        self.responseBuffer = nil;
        self.connected = NO;
    }
    return self;
}

#define SMTP_DEFAULT_PORT 25

- (SMTPee *) initWithAddress:(NSString *)anAddress {
    return [self initWithAddress:anAddress port:SMTP_DEFAULT_PORT];
}

- (void) doFinish {
    if (self.connected && !self.errorOccured) {
        [self quit];
    }
    self.started = NO;
    self.errorOccured = NO;
    self.connected = NO;
    [iStream close];
    [oStream close];
    [iStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [oStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [iStream setDelegate:nil];
    [oStream setDelegate:nil];
    [iStream release];
    [oStream release];
    iStream = nil;
    oStream = nil;
}

- (void) finish {
    if (!self.started) {
        @throw [NSException exceptionWithName:@"IOError" reason:@"not yet started" userInfo:nil];
    }
    [self doFinish];
}

- (BOOL) capable:(NSString *)key {
    if (!self.capabilities) {
        return NO;
    } else if ([self.capabilities objectForKey:key]) {
        return YES;
    } else {
        return NO;
    }
}

- (BOOL) capableStartTLS {
    return [self capable:@"STARTTLS"];
}

- (BOOL) authCapable:(NSString *)type {
    if (!self.capabilities) {
        return NO;
    } else if (![self.capabilities objectForKey:@"AUTH"]) {
        return NO;
    } else {
        return [[self.capabilities objectForKey:@"AUTH"] containsObject:type];
    }
}

- (BOOL) capablePlainAuth {
    return [self authCapable:@"PLAIN"];
}

- (BOOL) capableLoginAuth {
    return [self authCapable:@"LOGIN"];
}

- (BOOL) capableCramMD5Auth {
    return [self authCapable:@"CRAM-MD5"];
}

- (NSArray *) capableAuthTypes {
    if (!self.capabilities) {
        return [NSArray array];
    } else if (![self.capabilities objectForKey:@"AUTH"]) {
        return [NSArray array];
    } else {
        return [self.capabilities objectForKey:@"AUTH"];
    }
}

- (void) enableTLS {
    if (![self.shouldStartTLS isEqualToString:@"no"]) {
        @throw [NSException exceptionWithName:@"ArgumentError" reason:@"SMTPS and STARTTLS are exclusive" userInfo:nil];
    }
    self.TLS = YES;
}

- (void) disableTLS {
    self.TLS = NO;
}

- (BOOL) shouldAlwaysStartTLS {
    return [self.shouldStartTLS isEqualToString:@"always"];
}

- (BOOL) shouldAutoStartTLS {
    return [self.shouldStartTLS isEqualToString:@"auto"];
}

- (void) enableStartTLS {
    if (self.TLS) {
        @throw [NSException exceptionWithName:@"ArgumentError" reason:@"SMTPS and STARTTLS are exclusive" userInfo:nil];
    }
    self.shouldStartTLS = @"always";
}

- (void) enableAutoStartTLS {
    if (self.TLS) {
        @throw [NSException exceptionWithName:@"ArgumentError" reason:@"SMTPS and STARTTLS are exclusive" userInfo:nil];
    }
    self.shouldStartTLS = @"auto";
}

- (void) disableStartTLS {
    self.shouldStartTLS = @"no";
}

- (SMTPResponse *) sendMessage:(NSString *)msgStr from:(NSString *)fromAddr to:(NSArray *)toAddrs {
    if (!self.connected) {
        @throw [NSException exceptionWithName:@"IOError" reason:@"closed session" userInfo:nil];        
    }
    [self mailFrom:fromAddr];
    return [self rcptToList:toAddrs block:^ {
        return [self data:msgStr];
    }];
}

- (NSString *) authMethodName:(NSString *)type {
    type = [type stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:[[type substringToIndex:1] uppercaseString]];
    return [NSString stringWithFormat:@"auth%@:secret:", type];
}

- (void) checkAuthMethod:(NSString *)type {
    SEL sel = NSSelectorFromString([self authMethodName:type]);
    if (![self respondsToSelector:sel]) {
        @throw [NSException exceptionWithName:@"ArgumentError" reason:[NSString stringWithFormat:@"wrong authentication type %@", type] userInfo:nil];
    }
}

- (void) checkUserArgs:(NSString *)user secret:(NSString *)secret {
    if (!user) {
        @throw [NSException exceptionWithName:@"ArgumentError" reason:@"SMTP-AUTH requested but missing user name" userInfo:nil];
    }
    if (!secret) {
        @throw [NSException exceptionWithName:@"ArgumentError" reason:@"SMTP-AUTH requested but missing secret phrase" userInfo:nil];
    }
}

- (void) doHelo:(NSString *)helo {
    @try {
        SMTPResponse *res = self.ESMTP ? [self ehlo:helo] : [self helo:helo];
        self.capabilities = [res capabilities];
    }
    @catch (NSException *exception) {
        if (self.ESMTP) {
            self.ESMTP = NO;
            self.errorOccured = NO;
            SMTPResponse *res = [self helo:helo];
            self.capabilities = [res capabilities];
        }
        @throw exception;
    }
}

#define CRAM_BUFSIZE 64

- (NSString *) cramSecret:(NSString *)secret mask:(int)mask {
    if ([secret length] > CRAM_BUFSIZE) {
        secret = [secret MD5Digest];
    }
    secret = [secret stringByPaddingToLength:CRAM_BUFSIZE withString:@"\0" startingAtIndex:0];
    NSMutableString *buf = [NSMutableString string];
    for (int i = 0; i < [secret length]; i++) {
        int num = (int)[secret characterAtIndex:i] ^ mask;
        [buf appendFormat:@"%c", num];
    }
    return buf;
}

#define IMASK 0x36
#define OMASK 0x5c

- (NSString *) cramMD5Response:(NSString *)secret challenge:(NSString *)challenge {
    NSString *tmp = [[NSString stringWithFormat:@"%@%@", [self cramSecret:secret mask:IMASK], challenge] MD5Digest];
    return [[NSString stringWithFormat:@"%@%@", [self cramSecret:secret mask:OMASK], tmp] MD5HexDigest];
}

- (void) write:(NSString *)msgStr {
    NSLog(@"C: %@", msgStr);
    NSString *stringToSend = [NSString stringWithFormat:@"%@\r\n", msgStr];
    NSData *dataToSend = [stringToSend dataUsingEncoding:NSUTF8StringEncoding];
    int remainingToWrite = [dataToSend length];
    void *marker = (void *)[dataToSend bytes];
    while (0 < remainingToWrite) {
        int actuallyWritten = 0;
        actuallyWritten = [oStream write:marker maxLength:remainingToWrite];
        remainingToWrite -= actuallyWritten;
        marker += actuallyWritten;
    }
    self.responseBuffer = nil;
}

- (void) parseInputStream {
    uint8_t buffer[1024];
    int len;
    while ([iStream hasBytesAvailable]) {
        len = [iStream read:buffer maxLength:sizeof(buffer)];
        if (len > 0) {
            NSString *res = [[NSString alloc] initWithBytes:buffer 
                                                     length:len 
                                                   encoding:NSASCIIStringEncoding];
            if (res) {
                NSLog(@"S: %@", res);
                self.responseBuffer = res;
            }
        }
    }
}

- (void) stream:(NSStream *)stream handleEvent:(NSStreamEvent)event {
    switch (event) {
        case NSStreamEventHasBytesAvailable: {
            if (stream == iStream) {
                [self parseInputStream];
            }
            break;
        }
    }
}

- (SMTPResponse *) recvResponse {
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    while (!self.responseBuffer && [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]);
    return [SMTPResponse responseByParse:self.responseBuffer];
}

- (SMTPResponse *) getResponse:(NSString *)reqLine {
    [self write:reqLine];
    return [self recvResponse];
}

- (SMTPResponse *) critical:(SMTPResponseBlock)block {
    if (self.errorOccured) {
        return [SMTPResponse responseByParse:@"200 dummy reply code"];
    } else {
        @try {
            return block();
        }
        @catch (NSException *exception) {
            self.errorOccured = YES;
            @throw exception;
        }
    }
}

- (void) checkResponse:(SMTPResponse *)res {
    if (![res isSuccess]) {
        @throw [NSException exceptionWithName:[res exceptionName] reason:[res message] userInfo:nil];
    }
}

- (void) checkContinue:(SMTPResponse *)res {
    if (![res isContinue]) {
        @throw [NSException exceptionWithName:@"SMTPUnknownError" reason:[NSString stringWithFormat:@"could not get 3xx (%@)", res.status] userInfo:nil];                
    }
}

- (void) checkAuthResponse:(SMTPResponse *)res {
    if (![res isSuccess]) {
        @throw [NSException exceptionWithName:@"SMTPAuthenticationError" reason:[res message] userInfo:nil];        
    }
}

- (void) checkAuthContinue:(SMTPResponse *)res {
    if (![res isContinue]) {
        @throw [NSException exceptionWithName:[res exceptionName] reason:[res message] userInfo:nil];
    }
}

- (SMTPResponse *) getOk:(NSString *)reqLine {
    SMTPResponse *res = [self critical:^ {
        [self write:reqLine];
        return [self recvResponse];
    }];
    [self checkResponse:res];
    return res;
}

- (SMTPResponse *) startTLS {
    return [self getOk:@"STARTTLS"];
}

- (SMTPResponse *) helo:(NSString *) domain {
    return [self getOk:[NSString stringWithFormat:@"HELO %@", domain]];
}

- (SMTPResponse *) ehlo:(NSString *)domain {
    return [self getOk:[NSString stringWithFormat:@"EHLO %@", domain]];
}

- (SMTPResponse *) mailFrom:(NSString *)fromAddr {
    return [self getOk:[NSString stringWithFormat:@"MAIL FROM:<%@>", fromAddr]];
}

- (SMTPResponse *) rcptTo:(NSString *)toAddr {
    return [self getOk:[NSString stringWithFormat:@"RCPT TO:<%@>", toAddr]];
}

- (SMTPResponse *) rcptToList:(NSArray *)toAddrs block:(SMTPResponseBlock)block {
    if ([toAddrs count] == 0) {
        @throw [NSException exceptionWithName:@"ArgumentError" reason:@"mail destination not given" userInfo:nil];
    }
    NSMutableArray *okUsers = [NSMutableArray array];
    NSMutableArray *unknownUsers = [NSMutableArray array];
    for (NSString *toAddr in toAddrs) {
        BOOL error = NO;
        @try {
            [self rcptTo:toAddr];
        }
        @catch (NSException *exception) {
            if ([[exception name] isEqualToString:@"SMTPAuthenticationError"]) {
                error = YES;
                [unknownUsers addObject:toAddr];
            }
        }
        @finally {
            if (!error) {
                [okUsers addObject:toAddr];
            }
        }
    }
    if ([okUsers count] == 0) {
        @throw [NSException exceptionWithName:@"ArgumentError" reason:@"mail destination not given" userInfo:nil];
    }
    SMTPResponse *ret = block();
    if ([unknownUsers count] != 0) {
        @throw [NSException exceptionWithName:@"SMTPAuthenticationError"
                                       reason:[NSString stringWithFormat:@"failed to deliver for %@",
                                               [unknownUsers componentsJoinedByString:@", "]] userInfo:nil];
    }
    return ret;
}

- (SMTPResponse *) data:(NSString *)msgStr {
    SMTPResponse *res = [self critical:^ {
        [self checkContinue:[self getResponse:@"DATA"]];
        [self write:msgStr];
        return [self recvResponse];
    }];
    [self checkResponse:res];
    return res;
}

- (SMTPResponse *) quit {
    return [self getOk:@"QUIT"];
}

- (SMTPResponse *) authenticate:(NSString *)user secret:(NSString *)secret authType:(NSString *)authType {
    [self checkAuthMethod:authType];
    [self checkUserArgs:user secret:secret];
    SEL sel = NSSelectorFromString([self authMethodName:authType]);
    return [self performSelector:sel withObject:user withObject:secret];
}

- (SMTPResponse *) authenticate:(NSString *)user secret:(NSString *)secret {
    return [self authenticate:user secret:secret authType:@"plain"];
}

- (SMTPResponse *) authPlain:(NSString *)user secret:(NSString *)secret {
    [self checkUserArgs:user secret:secret];
    SMTPResponse *res = [self critical:^ {
        return [self getResponse:[NSString stringWithFormat:@"AUTH PLAIN %@",
                                  [NSString base64StringFromString:[NSString stringWithFormat:@"\000%@\000%@", user, secret]]]];
    }];
    [self checkAuthResponse:res];
    return res;
}

- (SMTPResponse *) authLogin:(NSString *)user secret:(NSString *)secret {
    [self checkUserArgs:user secret:secret];
    SMTPResponse *res = [self critical:^ {
        [self checkAuthContinue:[self getResponse:@"AUTH LOGIN"]];
        [self checkAuthContinue:[self getResponse:[NSString base64StringFromString:user]]];
        return [self getResponse:[NSString base64StringFromString:secret]];
    }];
    [self checkAuthResponse:res];
    return res;
}

- (SMTPResponse *) authCramMD5:(NSString *)user secret:(NSString *)secret {
    [self checkUserArgs:user secret:secret];
    SMTPResponse *res = [self critical:^ {
        SMTPResponse *res0 = [self getResponse:@"AUTH CRAM-MD5"];
        [self checkAuthContinue:res0];
        NSString *crammed = [self cramMD5Response:secret challenge:[res0 cramMD5Challenge]];
        return [self getResponse:[NSString base64StringFromString:[NSString stringWithFormat:@"%@ %@", user, crammed]]];
    }];
    [self checkAuthResponse:res];
    return res;
}

- (void) doStartWithHelo:(NSString *)helo user:(NSString *)user secret:(NSString *)secret authType:(NSString *)authType {
    @try {
        if (self.started) {
            @throw [NSException exceptionWithName:@"IOError" reason:@"SMTP session already started" userInfo:nil];
        }
        if (user || secret) {
            if (!authType) {
                authType = @"plain";
            }
            [self checkAuthMethod:authType];
            [self checkUserArgs:user secret:secret];
        }
        [NSStream getStreamsToHostNamed:self.address port:self.port inputStream:&iStream outputStream:&oStream];
        [iStream retain];
        [oStream retain];
        [iStream setDelegate:self];
        [oStream setDelegate:self];
        [iStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [oStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        if (self.TLS) {
            [iStream setProperty:NSStreamSocketSecurityLevelNegotiatedSSL forKey:NSStreamSocketSecurityLevelKey];
            [oStream setProperty:NSStreamSocketSecurityLevelNegotiatedSSL forKey:NSStreamSocketSecurityLevelKey];
            [iStream open];
            [oStream open];
            self.connected = YES;
        }
        [self checkResponse:[self critical:^ {
            return [self recvResponse];
        }]];
        [self doHelo:helo];
        if ([self shouldAlwaysStartTLS] || ([self capableStartTLS] && [self shouldAutoStartTLS])) {
            if (![self capableStartTLS]) {
                @throw [NSException exceptionWithName:@"SMTPUnsupportedCommand" reason:@"STARTTLS is not supported on this server" userInfo:nil];
            }
            [self startTLS];
            [iStream setProperty:NSStreamSocketSecurityLevelNegotiatedSSL forKey:NSStreamSocketSecurityLevelKey];
            [oStream setProperty:NSStreamSocketSecurityLevelNegotiatedSSL forKey:NSStreamSocketSecurityLevelKey];
            [iStream open];
            [oStream open];
            self.connected = YES;
            [self doHelo:helo];
        }
        if (user) {
            if (!authType) {
                authType = @"plain";
            }
            [self authenticate:user secret:secret authType:authType];
        }
        if (self.connected) {
            [iStream open];
            [oStream open];
            self.connected = YES;
        }
        self.started = YES;
    }
    @catch (NSException *exception) {
        @throw exception;
    }
    @finally {
        if (!self.started) {
            [iStream close];
            [oStream close];
            [iStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
            [oStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
            [iStream setDelegate:nil];
            [oStream setDelegate:nil];
            [iStream release];
            [oStream release];
            iStream = nil;
            oStream = nil;
        }
    }
}

- (SMTPee *) startWithHelo:(NSString *)helo user:(NSString *)user secret:(NSString *)secret authType:(NSString *)authType {
    [self doStartWithHelo:helo user:user secret:secret authType:authType];
    return self;
}

- (SMTPee *) startWithUser:(NSString *)user secret:(NSString *)secret authType:(NSString *)authType {
    return [self startWithHelo:@"localhost" user:user secret:secret authType:authType];
}

- (SMTPee *) start {
    [self doStartWithHelo:@"localhost" user:nil secret:nil authType:nil];
    return self;
}

+ (SMTPee *) startWithAddress:(NSString *)anAddress {
    SMTPee *smtp = [[[SMTPee alloc] initWithAddress:anAddress] autorelease];
    return [smtp start];
}

+ (SMTPee *) startWithAddress:(NSString *)anAddress port:(int)aPort user:(NSString *)user secret:(NSString *)secret authType:(NSString *)authType {
    return [SMTPee startWithAddress:anAddress port:aPort helo:@"localhost" user:user secret:secret authType:authType];
}

+ (SMTPee *) startWithAddress:(NSString *)anAddress port:(int)aPort helo:(NSString *)helo user:(NSString *)user secret:(NSString *)secret authType:(NSString *)authType {
    SMTPee *smtp = [[[SMTPee alloc] initWithAddress:anAddress port:aPort] autorelease];
    return [smtp startWithHelo:helo user:user secret:secret authType:authType];
}

@end