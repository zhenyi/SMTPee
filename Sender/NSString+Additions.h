//
//  NSString+Additions.h
//  Sender
//
//  Created by Zhenyi Tan on 5/23/11.
//  Copyright 2011 And a Dinosaur. All rights reserved.
//

@interface NSString (Base64)

+ (NSString *) base64StringFromString:(NSString *)string;
+ (NSString *) stringFromBase64String:(NSString *)string;

@end