//
//  JKDownloadManager.m
//  JKDownloader
//
//  Created by 01 on 2017/6/26.
//  Copyright © 2017年 01. All rights reserved.
//

#import "JKDownloadManager.h"


#define JKDownloadDefaultDirectory [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject]stringByAppendingPathComponent:@"JKDownloader"]

@interface JKDownloadManager ()<NSURLSessionDataDelegate>

@property (strong, nonatomic) NSMutableArray <JKDownloadInfo *>*infos;
@property (strong, nonatomic) NSArray <JKDownloadInfo *>*loadingInfos;
@property (strong, nonatomic) NSArray <JKDownloadInfo *>*waitingInfos;

@property (strong, nonatomic) NSURLSession *session;

@end

@implementation JKDownloadManager

#pragma mark ==system

- (instancetype)init {
    if (self = [super init]) {
        self.enableBackgoundLoad = NO;
        self.infos = [NSMutableArray array];
        _maxConcurrentCount = -1; // setter 中有限制，这里只能用ivar
        self.needNoti = NO;
        self.downloadDirectoryPath = JKDownloadDefaultDirectory;
        self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:nil];
    }
    return self;
}

#pragma mark ==public

+ (instancetype)shareManager {
    static JKDownloadManager *mgr;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mgr = [[JKDownloadManager alloc] init];
    });
    return mgr;
}

+ (instancetype)manager {
    return [[self alloc] init];
}

- (void)managerInvalidateAndCancel {
    [self.session invalidateAndCancel];
}

- (void)managerFinishTasksAndInvalidate {
    [self.session finishTasksAndInvalidate];
}

- (JKDownloadInfo *)loadInfoWithURL:(NSString *)url progress:(JKDownloadProgressBlock)progress state:(JKDownloadStateBlock)state {
    
    if (url == nil) return nil;
    
    JKDownloadInfo *info = [self infoWithURL:url];
    
    if (info.state == JKDownloadStateSuccessed ||
        info.state == JKDownloadStateLoading) {
        return info;
    }
    
    [info infoConfigWithCustomDirectoryPath:self.downloadDirectoryPath progress:progress state:state];
    
    [self resumeWithURL:url];
    
    return info;
}

- (JKDownloadInfo *)loadInfoWithURL:(NSString *)url encapsulateProgress:(JKDownloadEncapsulateProgressBlock)encapsulateProgress state:(JKDownloadStateBlock)state {
    
    if (url == nil) return nil;
    
    JKDownloadInfo *info = [self infoWithURL:url];
    if (info.state == JKDownloadStateSuccessed ||
        info.state == JKDownloadStateLoading) {
        return info;
    }
    
    [info infoConfigWithCustomDirectoryPath:self.downloadDirectoryPath encapsulateprogress:encapsulateProgress state:state];
    
    [self resumeWithURL:url];
    
    return info;
}

- (JKDownloadInfo *)waitInfoWithURL:(NSString *)url progress:(JKDownloadProgressBlock)progress state:(JKDownloadStateBlock)state {
    
    if (url == nil) return nil;
    
    JKDownloadInfo *info = [self infoWithURL:url];
    
    if (info.state == JKDownloadStateSuccessed ||
        info.state == JKDownloadStateWaiting) {
        return info;
    }
    
    [info infoConfigWithCustomDirectoryPath:self.downloadDirectoryPath progress:progress state:state];
    
    [info waiting];
    
    return info;
}

- (JKDownloadInfo *)waitInfoWithURL:(NSString *)url encapsulateProgress:(JKDownloadEncapsulateProgressBlock)encapsulateProgress state:(JKDownloadStateBlock)state {
    if (url == nil) return nil;
    
    JKDownloadInfo *info = [self infoWithURL:url];
    if (info.state == JKDownloadStateSuccessed ||
        info.state == JKDownloadStateLoading) {
        return info;
    }
    
    [info infoConfigWithCustomDirectoryPath:self.downloadDirectoryPath encapsulateprogress:encapsulateProgress state:state];
    
    [info waiting];
    
    return info;
}

- (JKDownloadInfo *)downloadedInfoSizeWithURL:(NSString *)url {
    return [JKDownloadInfo downloadedInfoSizeWithURL:url];
}


- (JKDownloadInfo *)resumeWithURL:(NSString *)url {
    if (url == nil) return nil;
    JKDownloadInfo *info = [self infoWithURL:url];
    if (info.state == JKDownloadStateLoading ||
        info.state == JKDownloadStateSuccessed) {
    
        return info;
    }
    
    if (info.customDirectoryPath == nil) {
        [info infoConfigWithCustomDirectoryPath:self.downloadDirectoryPath progress:nil state:nil];
    }
    if (self.maxConcurrentCount !=0 && self.maxConcurrentCount == self.loadingInfos.count) {
        JKDownloadInfo *loadingFirstInfo = self.loadingInfos.firstObject;
        [loadingFirstInfo suspend];
    }
    
    [info resume];
    return info;
}

- (JKDownloadInfo *)suspendWithURL:(NSString *)url {
    if (url == nil) return nil;
    JKDownloadInfo *info = [self infoWithURL:url];
    if (info.state == JKDownloadStateSuspended) return info;
    
    [info suspend];
    [self resumeNextInfo];
    return info;
}

- (JKDownloadInfo *)cancel_deleteWithURL:(NSString *)url {
    if (url == nil) return nil;
    JKDownloadInfo *info = [self infoWithURL:url];
    if (info.state == JKDownloadStateCanceled) return info;
    
    [info cancel_delete];
    /*
     cancel 会触发 NSURLSessionDataDelegate 中的 didCompleteWithError，
     这个方法中已经调用 [self resumeNextInfo]，此处无需再次调用
     */
    
    return info;
}

- (JKDownloadInfo *)infoWithURL:(NSString *)url {
    if (url == nil) return nil;
    //内存中查找info
    JKDownloadInfo *info = [self.infos filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"url==%@", url]].firstObject;
    if (info == nil) {
        // 磁盘中查找info（判断是否已下载完成）
        info = [JKDownloadInfo downloadedInfoSizeWithURL:url];
        if (info.state != JKDownloadStateSuccessed ||
            (info.totalSize != 0 && info.totalSize == info.downloadedSize)) {
            // 磁盘中未下载完成、从未下载
            info = [JKDownloadInfo infoWithURL:url inSession:self.session];
            [self.infos addObject:info];;
        }
    }
    return info;
}

- (void)resumeWithURLs:(NSArray<NSString *> *)urls {
    NSMutableArray <JKDownloadInfo *>*arrM = @[].mutableCopy;
    [urls enumerateObjectsUsingBlock:^(NSString * _Nonnull url, NSUInteger idx, BOOL * _Nonnull stop) {
        [self suspendAll];
        JKDownloadInfo *info = [self infoWithURL:url];
        [arrM addObject:info];
    }];
    [arrM enumerateObjectsUsingBlock:^(JKDownloadInfo * _Nonnull info, NSUInteger idx, BOOL * _Nonnull stop) {
        
        if (self.maxConcurrentCount !=0 && self.maxConcurrentCount == self.loadingInfos.count) {
            [info waiting];
        } else {
            [info resume];
        }
    }];
}

- (void)suspendWithURLs:(NSArray<NSString *> *)urls {
    [urls enumerateObjectsUsingBlock:^(NSString * _Nonnull url, NSUInteger idx, BOOL * _Nonnull stop) {
        JKDownloadInfo *info = [self.infos filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"url==%@", url]].firstObject;
        [info suspend];
    }];
}

- (void)cancel_deleteWithURLs:(NSArray<NSString *> *)urls {
    [urls enumerateObjectsUsingBlock:^(NSString * _Nonnull url, NSUInteger idx, BOOL * _Nonnull stop) {
        JKDownloadInfo *info = [self.infos filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"url==%@", url]].firstObject;
        [info cancel_delete];
    }];
}

- (void)resumeAll {
    [self.infos enumerateObjectsUsingBlock:^(JKDownloadInfo * _Nonnull info, NSUInteger idx, BOOL * _Nonnull stop) {
        if (self.maxConcurrentCount !=0 && self.maxConcurrentCount == self.loadingInfos.count) {
            [info waiting];
        } else {
            [info resume];
        }
    }];
}

- (void)suspendAll {
    [self.infos enumerateObjectsUsingBlock:^(JKDownloadInfo * _Nonnull info, NSUInteger idx, BOOL * _Nonnull stop) {
        [info suspend];
    }];
}

- (void)cancel_deleteAll {
    [self.infos enumerateObjectsUsingBlock:^(JKDownloadInfo * _Nonnull info, NSUInteger idx, BOOL * _Nonnull stop) {
        [info cancel_delete];
    }];
}

#pragma mark ==setter、getter

- (NSArray<JKDownloadInfo *> *)loadingInfos {
    return [self.infos filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"state==%d", JKDownloadStateLoading]];
}

- (NSArray<JKDownloadInfo *> *)waitingInfos {
    return [self.infos filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"state==%d", JKDownloadStateWaiting]];
}

- (void)setEnableBackgoundLoad:(BOOL)enableBackgoundLoad {
    _enableBackgoundLoad = enableBackgoundLoad;
    if (enableBackgoundLoad) {
        NSURLSessionConfiguration *confi =  [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:JKDownloadBackgroundIdentifier];
        confi.networkServiceType = NSURLNetworkServiceTypeBackground;
        self.session = [NSURLSession sessionWithConfiguration:confi delegate:self delegateQueue:nil];
    }
}

- (void)setMaxConcurrentCount:(NSInteger)maxConcurrentCount {
    if (maxConcurrentCount > 0) {
        _maxConcurrentCount = maxConcurrentCount;
    }
}


#pragma mark ==private

- (void)resumeNextInfo {
    JKDownloadInfo *info = self.waitingInfos.firstObject;
    [info resume];
}

#pragma mark ==NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSHTTPURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    
    JKDownloadInfo *info = [self infoWithURL:dataTask.taskDescription];
    [info didReceiveResponse:response];
    
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    
    JKDownloadInfo *info = [self infoWithURL:dataTask.taskDescription];
    [info didReceiveData:data];
}

#pragma mark ==NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    
    JKDownloadInfo *info = [self infoWithURL:task.taskDescription];
    [info didCompleteWithError:error];
    
    [self resumeNextInfo];
}

#pragma mark ==NSURLSessionDelegate

- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session {
    
    if (self.backgroundTransferCompletionHandler != nil) {
        self.backgroundTransferCompletionHandler();
        self.backgroundTransferCompletionHandler = nil;
    }
}


@end
