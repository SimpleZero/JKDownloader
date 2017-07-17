//
//  NSString+JKAdd_MD5.m
//  JKDownloader
//
//  Created by 01 on 2017/6/26.
//  Copyright © 2017年 01. All rights reserved.
//

#import "NSString+JKAdd_MD5.h"
#import <CommonCrypto/CommonDigest.h>

@implementation NSString (JKAdd_MD5)

- (NSString *)jk_md5 {
    const char *data = self.UTF8String;
    unsigned char md[CC_MD5_DIGEST_LENGTH];
    CC_MD5(data, (CC_LONG)strlen(data), md);
    
    NSMutableString *result = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i ++) {
        [result appendFormat:@"%02x", md[i]];
    }
    return result;
}

@end
