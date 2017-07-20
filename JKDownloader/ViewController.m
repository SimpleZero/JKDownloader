//
//  ViewController.m
//  JKDownloader
//
//  Created by 01 on 2017/6/26.
//  Copyright © 2017年 01. All rights reserved.
//

#import "ViewController.h"
#import "JKDownloadManager.h"
#import "JKMonitorView.h"

@interface ViewController ()
@property (weak, nonatomic) UIButton *resumeBtn;
@property (weak, nonatomic) UIButton *suspendBtn;
@property (weak, nonatomic) UIButton *cancelBtn;
@property (weak, nonatomic) JKMonitorView *monitorV;
@end

static NSString * const url = @"http://dldir1.qq.com/qqfile/QQforMac/QQ_V6.0.0.dmg";
@implementation ViewController


- (IBAction)crash:(id)sender {
    NSArray *arr = @[];
    [arr objectAtIndex:1];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
//    [[JKDownloadManager shareManager] setEnableBackgoundLoad:YES withIdentifier:nil];
    
    UIButton *resumeBtn = [[UIButton alloc] init];
    resumeBtn.frame = CGRectMake(20, 60, 60, 60);
    [resumeBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [resumeBtn setTitle:@"开始" forState:UIControlStateNormal];
    [resumeBtn addTarget:self action:@selector(resume:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:resumeBtn];
    _resumeBtn = resumeBtn;
    
    UIButton *suspendBtn = [[UIButton alloc] init];
    suspendBtn.frame = CGRectMake(90, 60, 60, 60);
    [suspendBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [suspendBtn setTitle:@"暂停" forState:UIControlStateNormal];
    [suspendBtn addTarget:self action:@selector(suspend:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:suspendBtn];
    _suspendBtn = suspendBtn;
    
    UIButton *cancelBtn = [[UIButton alloc] init];
    cancelBtn.frame = CGRectMake(160, 60, 60, 60);
    [cancelBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [cancelBtn setTitle:@"取消" forState:UIControlStateNormal];
    [cancelBtn addTarget:self action:@selector(cancel:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:cancelBtn];
    _cancelBtn = cancelBtn;
    
    
    JKMonitorView *monitorV = [JKMonitorView monitor];
    monitorV.frame = CGRectMake(10, 150, self.view.frame.size.width-20, 60);
    [self.view addSubview:monitorV];
    _monitorV = monitorV;
    
    
    JKDownloadInfo *info = [[JKDownloadManager shareManager] downloadedInfoSizeWithURL:url];
    [monitorV configMonitorWithDownloaded:info.downloadedSizeString total:info.totalSizeString speed:@"" progress:info.progress];
    [self btnTitleWithState:info.state];
    NSLog(@"state:%zd\nfilePath:%@", info.state, info.filePath);
}

- (void)btnTitleWithState:(JKDownloadState)state {
    switch (state) {
        case JKDownloadStateSuccessed:
            [_resumeBtn setTitle:@"完成" forState:UIControlStateNormal];
            break;
        case JKDownloadStateFailed:
            [_resumeBtn setTitle:@"重试" forState:UIControlStateNormal];
            break;
        case JKDownloadStateSuspended:
            [_resumeBtn setTitle:@"继续" forState:UIControlStateNormal];
            break;
        case JKDownloadStateLoading:
            [_resumeBtn setTitle:@"下载中" forState:UIControlStateNormal];
            break;
        case JKDownloadStateWaiting:
            [_resumeBtn setTitle:@"等待" forState:UIControlStateNormal];
            break;
        default:
            [_resumeBtn setTitle:@"开始" forState:UIControlStateNormal];
            break;
    }
}

- (void)resume:(UIButton *)btn {
    [[JKDownloadManager shareManager] loadFileForURL:url encapsulateProgress:^(NSString *speed, NSString *downloadedSize, NSString *totalSize, float progress) {
        [_monitorV configMonitorWithDownloaded:downloadedSize total:totalSize speed:speed progress:progress];
    } state:^(JKDownloadState state, NSString *filePath, NSError *error) {
        [self btnTitleWithState:state];
        NSLog(@"state:%zd\nfilePath:%@\nerror:%@", state, filePath, error);
    }];
}

- (void)suspend:(UIButton *)btn {
    [[JKDownloadManager shareManager] suspendWithURL:url];
}

- (void)cancel:(UIButton *)btn {
    [[JKDownloadManager shareManager] cancel_deleteWithURL:url];
}



@end
