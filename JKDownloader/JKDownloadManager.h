//
//  JKDownloadManager.h
//  JKDownloader
//
//  Created by 01 on 2017/6/26.
//  Copyright © 2017年 01. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "JKDownloadInfo.h"


static NSString * const JKDownloadBackgroundIdentifier = @"JKDownloadBackgroundIdentifier";

@interface JKDownloadManager : NSObject

#pragma mark ==backgoundLoad
// default is NO
@property (assign, nonatomic) BOOL enableBackgoundLoad;
// AppDelegate -application: handleEventsForBackgroundURLSession: completionHandler: 中 completionHandler回调
@property (copy, nonatomic) void(^backgroundTransferCompletionHandler)();

#pragma mark ==download config
// default is 1
@property (assign, nonatomic) NSInteger maxConcurrentCount;
// default is JKDownloadDefaultDirectory(宏定义，见.m)
@property (strong, nonatomic) NSString *downloadDirectoryPath;
// default is NO
@property (assign, nonatomic) BOOL needNoti;

+ (instancetype)shareManager;


- (JKDownloadInfo *)loadFileForURL:(NSString *)url progress:(JKDownloadProgressBlock)progress state:(JKDownloadStateBlock)state;

- (JKDownloadInfo *)loadFileForURL:(NSString *)url inDirectory:(NSString *)directory withProgress:(JKDownloadProgressBlock)progress state:(JKDownloadStateBlock)state;

- (JKDownloadInfo *)loadFileForURL:(NSString *)url inDirectory:(NSString *)directory withProgress:(JKDownloadProgressBlock)progress state:(JKDownloadStateBlock)state enableBackgoundLoad:(BOOL)enableBackgoundLoad;

- (JKDownloadInfo *)loadFileForURL:(NSString *)url encapsulateProgress:(JKDownloadEncapsulateProgressBlock)encapsulateProgress state:(JKDownloadStateBlock)state;


// 获取下载info对应的信息状态，不可用于下载
- (JKDownloadInfo *)downloadedInfoWithURL:(NSString *)url;
// 获取下载info对应的信息状态，可用于下载
- (JKDownloadInfo *)infoWithURL:(NSString *)url;


// 开始/继续
- (JKDownloadInfo *)resumeWithURL:(NSString *)url;
// 暂停
- (JKDownloadInfo *)suspendWithURL:(NSString *)url;
// 取消/删除
- (JKDownloadInfo *)cancelWithURL:(NSString *)url;

// 批量操作
- (void)resumeWithURLs:(NSArray <NSString *>*)urls;
- (void)suspendWithURLs:(NSArray <NSString *>*)urls;
- (void)cancelWithURLs:(NSArray <NSString *>*)urls;

- (void)resumeAll;
- (void)suspendAll;
- (void)cancelAll;

@end
