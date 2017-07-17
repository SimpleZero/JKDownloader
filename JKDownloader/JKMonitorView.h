//
//  JKMonitorView.h
//  JKDownloader
//
//  Created by 01 on 2017/6/30.
//  Copyright © 2017年 SimpleZero. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface JKMonitorView : UIView

+ (instancetype)monitor;

- (void)configMonitorWithDownloaded:(NSString *)downloaded total:(NSString *)total speed:(NSString *)speed progress:(float)progress;

@end
