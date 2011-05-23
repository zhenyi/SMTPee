//
//  SMTPResponse.h
//  Sender
//
//  Created by Zhenyi Tan on 5/23/11.
//  Copyright 2011 And a Dinosaur. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSString+Additions.h"

@interface SMTPResponse : NSObject {

    NSString *status;
    NSString *string;
    
}

@property (copy) NSString *status;
@property (copy) NSString *string;

+ (SMTPResponse *) responseByParse:(NSString *)str;
- (SMTPResponse *) initWithStatus:(NSString *)aStatus string:(NSString *)aString;
- (NSString *) statusTypeChar;
- (BOOL) isSuccess;
- (BOOL) isContinue;
- (NSString *) message;
- (NSString *) cramMD5Challenge;
- (NSDictionary *) capabilities;
- (NSString *) exceptionName;

@end