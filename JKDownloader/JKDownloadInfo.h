//
//  JKDownloadInfo.h
//  JKDownloader
//
//  Created by 01 on 2017/6/26.
//  Copyright © 2017年 01. All rights reserved.
//

#import <Foundation/Foundation.h>


typedef NS_ENUM(NSInteger, JKDownloadState) {
    JKDownloadStateNone = 0, // 空闲、占位
    JKDownloadStateLoading, // 下载中
    JKDownloadStateWaiting, // 等待中
    JKDownloadStateSuspend, // 暂停
    JKDownloadStateStop, // 停止（有此标识不再进行下载，直接跳过）
    JKDownloadStateSuccessed, // 成功
    JKDownloadStateCanceled, // 取消
    JKDownloadStateFailed // 失败
};

typedef void (^JKDownloadProgressBlock)(NSInteger currentSize, NSInteger downloadedSize, NSInteger totalSize);
typedef void (^JKDownloadEncapsulateProgressBlock)(NSString *speed, NSString *downloadedSize, NSString *totalSize, float progress);

typedef void (^JKDownloadStateBlock)(JKDownloadState state, NSString *filePath, NSError *error);

static NSString * const JKDownloadProgressChangedNoti = @"JKDownloadProgressChangedNoti";
static NSString * const JKDownloadStateChangedNoti = @"JKDownloadStateChangedNoti";

@interface JKDownloadInfo : NSObject

// default is NO
@property (assign, nonatomic) BOOL needNoti;

@property (copy, nonatomic, readonly) NSString *url;
@property (copy, nonatomic, readonly) NSString *customDirectoryPath;
@property (copy, nonatomic, readonly) NSString *filePath;

// 单位：bytes
@property (assign, nonatomic, readonly) NSInteger currentSize; // 当前下载大小，可做网速监测
@property (assign, nonatomic, readonly) NSInteger downloadedSize;
@property (assign, nonatomic, readonly) NSInteger totalSize;

@property (copy, nonatomic, readonly) NSString *speed;
@property (copy, nonatomic, readonly) NSString *downloadedSizeString;
@property (copy, nonatomic, readonly) NSString *totalSizeString;
@property (assign, nonatomic, readonly) float progress;



@property (assign, nonatomic, readonly) JKDownloadState state;
@property (strong, nonatomic, readonly) NSError *error;

@property (strong, nonatomic, readonly) NSURLSessionDataTask *dataTask;

+ (instancetype)infoWithURL:(NSString *)url inSession:(NSURLSession *)session;


- (void)infoConfigWithCustomDirectoryPath:(NSString *)customDirectoryPath progress:(JKDownloadProgressBlock)progress state:(JKDownloadStateBlock)state;
- (void)infoConfigWithCustomDirectoryPath:(NSString *)customDirectoryPath encapsulateprogress:(JKDownloadEncapsulateProgressBlock)encapsulateprogress state:(JKDownloadStateBlock)state;


+ (JKDownloadInfo *)downloadedInfoWithURL:(NSString *)url;
- (NSString *)transferBytesToString:(NSInteger)bytes;

- (void)waiting;

- (void)resume;
- (void)suspend;
- (void)cancel;

- (void)didReceiveResponse:(NSHTTPURLResponse *)response;
- (void)didReceiveData:(NSData *)data;
- (void)didCompleteWithError:(NSError *)error;

@end
