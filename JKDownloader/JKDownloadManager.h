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


@interface JKDownloadManager : NSObject

#pragma mark ==backgoundLoad

// default is NO
@property (assign, nonatomic) BOOL enableBackgoundLoad;
// AppDelegate -application: handleEventsForBackgroundURLSession: completionHandler: 中 completionHandler回调
@property (copy, nonatomic) void(^backgroundTransferCompletionHandler)();
@property (copy, nonatomic) NSString *backgroundIdentify;


// default is -1
@property (assign, nonatomic) NSInteger maxConcurrentCount;
// default is JKDownloadDefaultDirectory(宏定义，见.m)
@property (strong, nonatomic) NSString *downloadDirectoryPath;
// default is NO
@property (assign, nonatomic) BOOL needNoti;


+ (instancetype)shareManager;
+ (instancetype)manager;

// 如果不使用shareManager生成实例，在不使用实例时需调用这两个方法之一，否则会有内存泄漏
- (void)managerInvalidateAndCancel;
- (void)managerFinishTasksAndInvalidate;

// 下载
- (JKDownloadInfo *)loadInfoWithURL:(NSString *)url progress:(JKDownloadProgressBlock)progress state:(JKDownloadStateBlock)state;
- (JKDownloadInfo *)loadInfoWithURL:(NSString *)url encapsulateProgress:(JKDownloadEncapsulateProgressBlock)encapsulateProgress state:(JKDownloadStateBlock)state;

// 等待
- (JKDownloadInfo *)waitInfoWithURL:(NSString *)url progress:(JKDownloadProgressBlock)progress state:(JKDownloadStateBlock)state;
- (JKDownloadInfo *)waitInfoWithURL:(NSString *)url encapsulateProgress:(JKDownloadEncapsulateProgressBlock)encapsulateProgress state:(JKDownloadStateBlock)state;


// 获取下载info对应的size，不可用于下载
//- (JKDownloadInfo *)downloadedInfoSizeWithURL:(NSString *)url;
// 获取下载info对应的所有属性信息，可用于下载
- (JKDownloadInfo *)infoWithURL:(NSString *)url;

// 开始/继续
- (JKDownloadInfo *)resumeWithURL:(NSString *)url;
// 暂停
- (JKDownloadInfo *)suspendWithURL:(NSString *)url;
// 取消/删除
- (JKDownloadInfo *)cancel_deleteWithURL:(NSString *)url;

// 批量操作
- (void)resumeWithURLs:(NSArray <NSString *>*)urls;
- (void)suspendWithURLs:(NSArray <NSString *>*)urls;
- (void)cancel_deleteWithURLs:(NSArray <NSString *>*)urls;

- (void)resumeAll;
- (void)suspendAll;
- (void)cancel_deleteAll;

@end
