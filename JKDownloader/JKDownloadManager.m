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





- (JKDownloadInfo *)loadFileForURL:(NSString *)url progress:(JKDownloadProgressBlock)progress state:(JKDownloadStateBlock)state {
    
    return [self loadFileForURL:url inDirectory:nil withProgress:progress state:state];
}

- (JKDownloadInfo *)loadFileForURL:(NSString *)url inDirectory:(NSString *)directory withProgress:(JKDownloadProgressBlock)progress state:(JKDownloadStateBlock)state {
    
    if (url == nil) return nil;
    
//    JKDownloadInfo *info = [self infoForURL:url];
    JKDownloadInfo *info = [self infoWithURL:url];
    
//    if (info == nil) return;
    
    if (info.state == JKDownloadStateSuccessed ||
        info.state == JKDownloadStateLoading ||
        info.state == JKDownloadStateWaiting) {
        return info;
    }
    
    
    [info infoConfigWithCustomDirectoryPath:directory progress:progress state:state];
    if (self.maxConcurrentCount !=0 && self.maxConcurrentCount == self.loadingInfos.count) {
        [info waiting];
    } else {
        [info resume];
    }
    return info;
}

- (JKDownloadInfo *)loadFileForURL:(NSString *)url inDirectory:(NSString *)directory withProgress:(JKDownloadProgressBlock)progress state:(JKDownloadStateBlock)state enableBackgoundLoad:(BOOL)enableBackgoundLoad {
    
    self.enableBackgoundLoad = enableBackgoundLoad;
    return [self loadFileForURL:url inDirectory:directory withProgress:progress state:state];
}

- (JKDownloadInfo *)loadFileForURL:(NSString *)url encapsulateProgress:(JKDownloadEncapsulateProgressBlock)encapsulateProgress state:(JKDownloadStateBlock)state {
    
    if (url == nil) return nil;
    
//    JKDownloadInfo *info = [self infoForURL:url];
    JKDownloadInfo *info = [self infoWithURL:url];
    
    // 已完成
    if (info.state == JKDownloadStateSuccessed) {
        
        !encapsulateProgress ? : encapsulateProgress ([info transferBytesToString:info.currentSize], [info transferBytesToString:info.downloadedSize], [info transferBytesToString:info.totalSize], info.progress);
        !state ? : state(JKDownloadStateSuccessed, info.filePath, nil);
        
        info.needNoti = self.needNoti;
        
        return info;
    }
    
    
    [info infoConfigWithCustomDirectoryPath:self.downloadDirectoryPath encapsulateprogress:encapsulateProgress state:state];
    if (info.state == JKDownloadStateSuccessed ||
        info.state == JKDownloadStateLoading ||
        info.state == JKDownloadStateWaiting) {
        
        !encapsulateProgress ? : encapsulateProgress ([info transferBytesToString:info.currentSize], [info transferBytesToString:info.downloadedSize], [info transferBytesToString:info.totalSize], info.progress);
        !state ? : state(JKDownloadStateSuccessed, info.filePath, nil);
        return info;
    }
    
    if (self.maxConcurrentCount !=0 && self.maxConcurrentCount == self.loadingInfos.count) {
        [info waiting];
    } else {
        [info resume];
    }
    return info;

}

- (BOOL)isDownloadedWithURL:(NSString *)url {
    return [JKDownloadInfo infoIsDownloadedForURL:url];
}

- (CGFloat)hasDownloadedProgressOfURL:(NSString *)url {
    if (url == nil) return 0.0;
//    JKDownloadInfo *info = [self infoForURL:url];
    JKDownloadInfo *info = [self infoWithURL:url];
    return MIN(1.0, 1.0 * info.downloadedSize / info.totalSize);
}

- (NSInteger)hasDownloadedSizeOfURL:(NSString *)url {
    if (url == nil) return 0.0;
//    JKDownloadInfo *info = [self infoForURL:url];
    JKDownloadInfo *info = [self infoWithURL:url];
    return info.downloadedSize;
}

- (NSInteger)totalDownloadFileSizeOfURL:(NSString *)url {
    if (url == nil) return 0.0;
//    JKDownloadInfo *info = [self infoForURL:url];
    JKDownloadInfo *info = [self infoWithURL:url];
    return info.totalSize;
}

- (JKDownloadInfo *)resumeWithURL:(NSString *)url {
    if (url == nil) return nil;
//    JKDownloadInfo *info = [self infoForURL:url];
    JKDownloadInfo *info = [self infoWithURL:url];
    if (info.customDirectoryPath == nil) {
        [info infoConfigWithCustomDirectoryPath:self.downloadDirectoryPath progress:nil state:nil];
    }
    [info resume];
    return info;
}

- (JKDownloadInfo *)suspendWithURL:(NSString *)url {
    if (url == nil) return nil;
//    JKDownloadInfo *info = [self infoForURL:url];
    JKDownloadInfo *info = [self infoWithURL:url];
    [info suspend];
    [self resumeNextInfo];
    return info;
}

- (JKDownloadInfo *)cancelWithURL:(NSString *)url {
    if (url == nil) return nil;
//    JKDownloadInfo *info = [self infoForURL:url];
    JKDownloadInfo *info = [self infoWithURL:url];
    [info cancel];
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
        info = [JKDownloadInfo downloadedInfoWithURL:url];
        if (info.state != JKDownloadStateSuccessed) {
            // 磁盘中未下载完成、从未下载
            info = [JKDownloadInfo infoWithURL:url inSession:self.session];
            [self.infos addObject:info];;
        }
    }
    return info;
}

- (void)resumeAll {
    [self.infos enumerateObjectsUsingBlock:^(JKDownloadInfo * _Nonnull info, NSUInteger idx, BOOL * _Nonnull stop) {
        [info resume];
    }];
}

- (void)suspendAll {
    [self.infos enumerateObjectsUsingBlock:^(JKDownloadInfo * _Nonnull info, NSUInteger idx, BOOL * _Nonnull stop) {
        [info suspend];
    }];
}

- (void)cancelAll {
    [self.infos enumerateObjectsUsingBlock:^(JKDownloadInfo * _Nonnull info, NSUInteger idx, BOOL * _Nonnull stop) {
        [info cancel];
    }];
}

#pragma mark ==setter、getter

- (NSArray<JKDownloadInfo *> *)loadingInfos {
    return [self.infos filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"state==%d", JKDownloadStateLoading]];
}

- (NSArray *)waitingInfosAtIndexes:(NSIndexSet *)indexes {
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

/*
// 如果infos不存在该info，配置info基本信息，并加入infos
- (JKDownloadInfo *)infoForURL:(NSString *)url {
    if (url == nil) return nil;
    //内存中查找info
    JKDownloadInfo *info = [self.infos filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"url==%@", url]].firstObject;
    if (info == nil) {
        // 磁盘中查找info（判断是否已下载完成）
        if ([JKDownloadInfo infoIsDownloadedForURL:url]) {
            return nil;
        } else {
            // 磁盘中未下载完成、从未下载
            info = [JKDownloadInfo infoWithURL:url inSession:self.session];
            [self.infos addObject:info];;
        }
    }
    return info;
}
 */

- (void)resumeNextInfo {
    JKDownloadInfo *info = self.waitingInfos.firstObject;
    [info resume];
}

#pragma mark ==NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSHTTPURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    
//    JKDownloadInfo *info = [self infoForURL:dataTask.taskDescription];
    JKDownloadInfo *info = [self infoWithURL:dataTask.taskDescription];
    [info didReceiveResponse:response];
    
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    
//    JKDownloadInfo *info = [self infoForURL:dataTask.taskDescription];
    JKDownloadInfo *info = [self infoWithURL:dataTask.taskDescription];
    [info didReceiveData:data];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    
//    JKDownloadInfo *info = [self infoForURL:task.taskDescription];
    JKDownloadInfo *info = [self infoWithURL:task.taskDescription];
    [info didCompleteWithError:error];
    
    [self resumeNextInfo];
}


- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session {
    /*
    [session getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
        if (downloadTasks.count == 0) {
            if (self.backgroundTransferCompletionHandler != nil) {
                
                self.backgroundTransferCompletionHandler();
                
                UILocalNotification *localNoti = [[UILocalNotification alloc] init];
                localNoti.alertBody = @"下载结束";
                [[UIApplication sharedApplication] presentLocalNotificationNow:localNoti];
                
                self.backgroundTransferCompletionHandler = nil;
            }
        }
    }];
    */
    
    self.backgroundTransferCompletionHandler();
    self.backgroundTransferCompletionHandler = nil;

}


@end