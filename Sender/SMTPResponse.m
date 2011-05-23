//
//  SMTPResponse.m
//  Sender
//
//  Created by Zhenyi Tan on 5/23/11.
//  Copyright 2011 And a Dinosaur. All rights reserved.
//

#import "SMTPResponse.h"

@implementation SMTPResponse

@synthesize status, string;

+ (SMTPResponse *) responseByParse:(NSString *)str {
    return [[[SMTPResponse alloc] initWithStatus:[str substringToIndex:3] string:str] autorelease];
}

- (SMTPResponse *) initWithStatus:(NSString *)aStatus string:(NSString *)aString {
    if ((self = [super init])) {
        self.status = aStatus;
        self.string = aString;
    }
    return self;
}

- (NSString *) statusTypeChar {
    return [self.status substringToIndex:1];
}

- (BOOL) isSuccess {
    return [[self statusTypeChar] isEqualToString:@"2"];
}

- (BOOL) isContinue {
    return [[self statusTypeChar] isEqualToString:@"3"];
}

- (NSArray *) stringToArrayOfLines:(NSString *)str {
    return [str componentsSeparatedByString: @"\r\n"];
}

- (NSString *) message {
    return [[self stringToArrayOfLines:self.string] objectAtIndex:0];
}

- (NSString *) cramMD5Challenge {
    NSString *str = [[self.string componentsSeparatedByString: @" "] objectAtIndex:1];
    return [NSString stringFromBase64String:str];
}

- (NSDictionary *) capabilities {
    NSMutableDictionary *cap = [NSMutableDictionary dictionary];
    if ([[self.string substringWithRange:NSMakeRange(3, 1)] isEqualToString:@"-"]) {
        NSArray *lines = [self stringToArrayOfLines:self.string];
        for (int i = 1; i < [lines count]; i++) {
            NSString *str = [[lines objectAtIndex:i] substringFromIndex:4];
            str = [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            NSArray *keyAndValues = [str componentsSeparatedByString:@" "];
            NSString *key = [keyAndValues objectAtIndex:0];
            NSArray *values = [keyAndValues subarrayWithRange:NSMakeRange(1, [keyAndValues count] - 1)];
            [cap setObject:values forKey:key];
        }
    }
    return cap;
}

- (NSString *) exceptionName {
    if ([self.status hasPrefix:@"4"]) {
        return @"SMTPServerBusy";
    } else if ([self.status hasPrefix:@"50"]) {
        return @"SMTPSyntaxError";
    } else if ([self.status hasPrefix:@"53"]) {
        return @"SMTPAuthenticationError";
    } else if ([self.status hasPrefix:@"5"]) {
        return @"SMTPFatalError";
    } else {
        return @"SMTPUnknownError";
    }
}

@end