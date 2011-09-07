//
//  Util.m
//  TinyJukebox
//
//  Created by Michael Mattozzi on 6/25/11.
//  Copyright 2011 Michael Mattozzi. All rights reserved.
//

#import "Util.h"
#import <CommonCrypto/CommonDigest.h>

@implementation Util

+(NSString *) sha256HashStringFromSeedData:(NSString *)seedData {
    unsigned char hashValue[CC_SHA256_DIGEST_LENGTH];
    const char *seedCharData = [seedData UTF8String];
    CC_SHA256(seedCharData, strlen(seedCharData), &hashValue);
    
    NSInteger byteLength = CC_SHA256_DIGEST_LENGTH;
    
    NSMutableString *stringValue = [NSMutableString stringWithCapacity:byteLength * 2];
    NSInteger i;
    for (i = 0; i < byteLength; i++) {
        [stringValue appendFormat:@"%02x", hashValue[i]];
    }
    
    return stringValue;
}

@end
