//
//  JKMonitorView.m
//  JKDownloader
//
//  Created by 01 on 2017/6/30.
//  Copyright © 2017年 SimpleZero. All rights reserved.
//

#import "JKMonitorView.h"

@interface JKMonitorView ()
@property (strong, nonatomic) UILabel *downloadedLabel;
@property (strong, nonatomic) UILabel *totalLabel;
@property (strong, nonatomic) UILabel *speedLabel;
@property (strong, nonatomic) UIProgressView *progressView;
@end

@implementation JKMonitorView

- (instancetype)init {
    if (self = [super init]) {
        _downloadedLabel = [[UILabel alloc] init];
        _downloadedLabel.textAlignment = NSTextAlignmentRight;
        _downloadedLabel.text = @"0K";
        _totalLabel = [[UILabel alloc] init];
        _totalLabel.textAlignment = NSTextAlignmentLeft;
        _totalLabel.text = @"0K";
        _speedLabel = [[UILabel alloc] init];
        _speedLabel.textAlignment = NSTextAlignmentCenter;
        _speedLabel.text = @"";
        _progressView = [[UIProgressView alloc] init];
        _progressView.progress = 0.0;
        
        [self addSubview:_downloadedLabel];
        [self addSubview:_totalLabel];
        [self addSubview:_speedLabel];
        [self addSubview:_progressView];
    }
    return self;
}

+ (instancetype)monitor {
    JKMonitorView *monitor = [[JKMonitorView alloc] init];
    return monitor;
}

- (void)configMonitorWithDownloaded:(NSString *)downloaded total:(NSString *)total speed:(NSString *)speed progress:(float)progress {
    _downloadedLabel.text = downloaded;
    _totalLabel.text = total;
    _speedLabel.text = speed;
    [_progressView setProgress:progress animated:YES];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGFloat labelW = 80.0;
    _downloadedLabel.frame = CGRectMake(0, 0, labelW, self.frame.size.height);
    _totalLabel.frame = CGRectMake(self.frame.size.width-labelW, 0, labelW, self.frame.size.height);
    _progressView.frame = CGRectMake(0, 0, self.frame.size.width-2*labelW-20, 2);
    _progressView.center = CGPointMake(self.frame.size.width/2, self.frame.size.height/2);
    _speedLabel.frame = CGRectMake(0, 0, labelW, self.frame.size.height/2-_progressView.frame.size.height);
    _speedLabel.center = CGPointMake(self.frame.size.width/2, _speedLabel.frame.size.height/2);

}

@end
