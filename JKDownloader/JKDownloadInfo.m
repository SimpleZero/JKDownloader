//
//  JKDownloadInfo.m
//  JKDownloader
//
//  Created by 01 on 2017/6/26.
//  Copyright © 2017年 01. All rights reserved.
//

#import "JKDownloadInfo.h"
#import "NSString+JKAdd_MD5.h"
#import "JKDownloadManager.h"

#define JKDownloadRootDirectory self.customDirectoryPath ?: [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] \
stringByAppendingPathComponent:@"JKDownloader"]

#define JKDownloadDirectory [JKDownloadRootDirectory stringByAppendingPathComponent:@"download"]


#define JKTotalFilesSizePlistPath [JKDownloadRootDirectory stringByAppendingPathComponent:@"totalFilesSize.plist"]
#define JKTotalFilesSizeDictionary [NSDictionary dictionaryWithContentsOfFile:JKTotalFilesSizePlistPath]

@interface JKDataTaskInfo : NSObject<NSURLSessionDataDelegate>

@end

@implementation JKDataTaskInfo



@end


@interface JKDownloadInfo ()<NSURLSessionDataDelegate>

@property (copy, nonatomic) NSString *url;
@property (copy, nonatomic) NSString *customDirectoryPath;

@property (copy, nonatomic) NSString *fileName;

@property (copy, nonatomic) NSString *filePath;

@property (assign, nonatomic) NSInteger currentSize;
@property (assign, nonatomic) NSInteger currentSizePerSec;
@property (assign, nonatomic) NSInteger downloadSizePerSec;
@property (assign, nonatomic) NSInteger downloadedSize;
@property (assign, nonatomic) NSInteger totalSize;

@property (assign, nonatomic) JKDownloadState state;
@property (strong, nonatomic) NSError *error;


@property (copy, nonatomic) JKDownloadProgressBlock progressBlock;
@property (copy, nonatomic) JKDownloadEncapsulateProgressBlock encapsulateProgressBlock;
@property (copy, nonatomic) JKDownloadStateBlock stateBlock;

// dataTask
@property (strong, nonatomic) NSURLSessionDataTask *dataTask;
@property (strong, nonatomic) NSOutputStream *outputStream;
// downloadTask
@property (strong, nonatomic) NSURLSessionDownloadTask *downloadTask;


@property (weak, nonatomic) NSURLSession *unownedSession;

@property (strong, nonatomic) NSTimer *timer;

@end


static NSFileManager *_fileMgr;
static NSNotificationCenter *_notiCenter;

@implementation JKDownloadInfo

@synthesize state = _state;

#pragma mark ==system

+ (void)initialize {
    _fileMgr = [NSFileManager defaultManager];
    _notiCenter = [NSNotificationCenter defaultCenter];
}

- (instancetype)init {
    if (self = [super init]) {
        if (![_fileMgr fileExistsAtPath:JKDownloadRootDirectory]) {
            [_fileMgr createDirectoryAtPath:JKDownloadRootDirectory withIntermediateDirectories:YES attributes:nil error:nil];
            [_fileMgr createDirectoryAtPath:JKDownloadDirectory withIntermediateDirectories:YES attributes:nil error:nil];
        }
        self.needNoti = NO;
    }
    return self;
}

#pragma mark ==public

+ (instancetype)infoWithURL:(NSString *)url inSession:(NSURLSession *)session {
    
    JKDownloadInfo *info = [[JKDownloadInfo alloc] init];
    info.url = [url copy];
    if (session == nil) return info;
    
    info.unownedSession = session;
    /*
    NSMutableURLRequest *requestM = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:url]];
    requestM.timeoutInterval = 60;
    [requestM setValue:[NSString stringWithFormat:@"bytes=%zd-", info.downloadedSize] forHTTPHeaderField:@"Range"];
    info.dataTask = [session dataTaskWithRequest:requestM];
    info.dataTask.taskDescription = info.url;
     */
    return info;
}

- (void)infoConfigWithCustomDirectoryPath:(NSString *)customDirectoryPath progress:(JKDownloadProgressBlock)progress state:(JKDownloadStateBlock)state {
    if (customDirectoryPath != nil) self.customDirectoryPath = [customDirectoryPath copy];
    if (progress != nil) self.progressBlock = [progress copy];
    if (state != nil) self.stateBlock = [state copy];
}

- (void)infoConfigWithCustomDirectoryPath:(NSString *)customDirectoryPath encapsulateprogress:(JKDownloadEncapsulateProgressBlock)encapsulateprogress state:(JKDownloadStateBlock)state {
    if (customDirectoryPath != nil) self.customDirectoryPath = [customDirectoryPath copy];
    if (encapsulateprogress != nil) self.encapsulateProgressBlock = [encapsulateprogress copy];
    if (state != nil) self.stateBlock = [state copy];
}

- (NSString *)transferBytesToString:(NSInteger)bytes {
    
    // 以1000为进位，不用1024
    
    NSInteger K = bytes / 1000;
    float M = 1.0 * K / 1000;
    if (M >= 1.0) {
        
        return [NSString stringWithFormat:@"%.1fM", M];
    } else if (K <= 1) {
        return [NSString stringWithFormat:@"%ldB", bytes];
    } else {
        return [NSString stringWithFormat:@"%ldK", K];
    }
}



- (void)waiting {
    if (self.state == JKDownloadStateLoading ||
        self.state == JKDownloadStateWaiting ||
        self.state == JKDownloadStateSuccessed) {
        return;
    }
    self.state = JKDownloadStateWaiting;
}

- (void)resume {
    
    if (self.state == JKDownloadStateSuccessed ||
        self.state == JKDownloadStateLoading) {
        return;
    }

    self.error = nil;
    [self.dataTask resume];
    [self.timer setFireDate:[NSDate date]];
    self.state = JKDownloadStateLoading;
}

- (void)suspend {
    
    if (self.state == JKDownloadStateLoading ||
        self.state == JKDownloadStateWaiting) {
        [self.dataTask suspend];
        [self.timer setFireDate:[NSDate distantFuture]];
        
        self.state = JKDownloadStateSuspended;
    }
    
}

- (void)cancel_delete {
 
    if (self.state == JKDownloadStateCanceled) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{

        if (self.state != JKDownloadStateSuccessed) {
            [self.dataTask cancel];
        }
        self.state = JKDownloadStateCanceled;

        [_fileMgr removeItemAtPath:self.filePath error:nil];
        NSMutableDictionary *totalFilesSizeDic = JKTotalFilesSizeDictionary.mutableCopy;
        [totalFilesSizeDic removeObjectForKey:self.url.jk_md5];
        [totalFilesSizeDic writeToFile:JKTotalFilesSizePlistPath atomically:YES];
    });

}

- (void)didReceiveResponse:(NSHTTPURLResponse *)response {
    
    self.currentSize = 0;
    
    NSString *range = response.allHeaderFields[@"Content-Range"];

    if (range != nil) {
        NSString *totalSize = range.lastPathComponent;
        self.totalSize = totalSize.integerValue;
        
        if (self.downloadedSize == 0) {
            NSString *str = [range componentsSeparatedByString:@"-"].lastObject;
            NSArray *strArr = [str componentsSeparatedByString:@"/"];
            self.downloadedSize = [strArr.lastObject integerValue] - [strArr.firstObject integerValue];
        }
        
        
    } else {
        self.totalSize = response.expectedContentLength + self.downloadedSize;
    }
    
    [self saveSizeToPlist];
    
    [self.outputStream open];
}

- (void)didReceiveData:(NSData *)data {
    NSInteger result = [self.outputStream write:data.bytes maxLength:data.length];
    
    if (result == -1) {
        self.error = self.outputStream.streamError;
    }else{
        
        if (self.dataTask.error != nil) {
            self.error = self.dataTask.error;
        } else {
            self.currentSize = data.length;
            self.currentSizePerSec += self.currentSize;
            
            [self changeProgress];
            
        }
    }
}

- (void)didCompleteWithError:(NSError *)error {
    
    if (error != nil) {
        self.error = error;
    }
    if (self.state == JKDownloadStateSuspended ||
        self.state == JKDownloadStateSuccessed) {
        return;
    }
    
    if (self.state != JKDownloadStateCanceled &&
        self.state != JKDownloadStateFailed) {
        self.state = JKDownloadStateSuccessed;
    }
    
    [self changeProgress];
}

#pragma mark ==setter、getter

- (NSURLSessionDataTask *)dataTask {
    if (_dataTask == nil) {
        NSMutableURLRequest *requestM = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:self.url]];
        requestM.timeoutInterval = 60;
        [requestM setValue:[NSString stringWithFormat:@"bytes=%zd-", self.downloadedSize] forHTTPHeaderField:@"Range"];
        _dataTask = [self.unownedSession dataTaskWithRequest:requestM];
        _dataTask.taskDescription = self.url;
    }
    return _dataTask;
}

- (NSInteger)totalSize {
    
    if (_totalSize == 0) {
        _totalSize = [JKTotalFilesSizeDictionary[self.url.jk_md5] integerValue];
    }
    return _totalSize;
}

- (NSInteger)downloadedSize {
    
    NSDictionary *attri = [_fileMgr attributesOfItemAtPath:self.filePath error:nil];
    if (attri == nil) {
        _downloadedSize = 0;
    } else {
        _downloadedSize = [attri[NSFileSize] integerValue];
    }
    return _downloadedSize;
}

- (NSString *)speed {
    
    if (self.state != JKDownloadStateLoading) {
        return @"";
    }
    
    if (_timer == nil) {
        self.timer = [NSTimer timerWithTimeInterval:1.0 target:self selector:@selector(sizePerSec) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
    }
    
//    if (self.downloadSizePerSec == 0) return @"";
    
    return [[self transferBytesToString:self.downloadSizePerSec] stringByAppendingString:@"/s"];
}

- (NSString *)downloadedSizeString {
    return [self transferBytesToString:self.downloadedSize];
}

- (NSString *)totalSizeString {
    return [self transferBytesToString:self.totalSize];
}

- (float)progress {
    return 1.0 * _downloadedSize/_totalSize;
}

- (void)setError:(NSError *)error {
    _error = error;
    
    if (error != nil) {
        // 挂起后请求超时 The request timed out.
        if (error.code == -1001 || _state == JKDownloadStateSuspended) {
            _error = nil;
            [self done];
        } else if (error.code == -999) {
            if (_state != JKDownloadStateCanceled) {
                self.state = JKDownloadStateCanceled;
            }
        } else {
            if (_state != JKDownloadStateFailed) {
                self.state = JKDownloadStateFailed;
            }
        }
        
        [self changeProgress];
    }
}

- (NSString *)fileName {
    if (_fileName == nil) {
        NSString *pathExtension = self.url.pathExtension;
        if (pathExtension != nil) {
            _fileName = [NSString stringWithFormat:@"%@.%@", self.url.jk_md5, pathExtension];
        } else {
            _fileName = self.url.jk_md5;
        }
    }
    return _fileName;
}

- (NSString *)filePath {
    
    if (_filePath == nil) {
        _filePath = [JKDownloadDirectory stringByAppendingPathComponent:self.fileName];
    }
    return _filePath;
}

- (NSOutputStream *)outputStream {
    if (_outputStream == nil) {
        _outputStream = [NSOutputStream outputStreamToFileAtPath:self.filePath append:YES];
        [_outputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
    return _outputStream;
}


- (JKDownloadState)state {
    if (self.totalSize != 0 && self.totalSize == self.downloadedSize) {
        if (_state != JKDownloadStateSuccessed) {
            self.state = JKDownloadStateSuccessed;
        }
    }
    return _state;
}

- (void)setState:(JKDownloadState)state {
    
    if (_state == state) return;
    
    _state = state;
    if (state == JKDownloadStateFailed ||
        state == JKDownloadStateCanceled ||
        state == JKDownloadStateSuccessed) {
        [self done];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        !self.stateBlock ? : self.stateBlock(state, self.filePath, self.error);
        if (self.needNoti) {
            [_notiCenter postNotificationName:JKDownloadStateChangedNoti object:self];
        }
    });
}


#pragma mark ==private

- (void)done {

    [_outputStream close];
    [_outputStream removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    _outputStream = nil;
    
    [_dataTask cancel];
    _dataTask = nil;
    
    _currentSize = 0;
    _currentSizePerSec = 0;
    _downloadSizePerSec = 0;
    
    [_timer invalidate];
    _timer = nil;
}

- (void)changeProgress {
    dispatch_async(dispatch_get_main_queue(), ^{
        !self.progressBlock ? : self.progressBlock(self.currentSize, self.downloadedSize, self.totalSize);
        !self.encapsulateProgressBlock ? : self.encapsulateProgressBlock(self.speed, self.downloadedSizeString, self.totalSizeString, self.progress);
        if (self.needNoti) {
            [_notiCenter postNotificationName:JKDownloadProgressChangedNoti object:self];
        }
    });
}

- (void)saveSizeToPlist {
    if (self.totalSize == 0) return;
    
    NSMutableDictionary *totalFilesSizeDic = JKTotalFilesSizeDictionary.mutableCopy ? : [NSMutableDictionary dictionary];
    totalFilesSizeDic[self.url.jk_md5] = @(self.totalSize);
    [totalFilesSizeDic writeToFile:JKTotalFilesSizePlistPath atomically:YES];
}

- (void)sizePerSec {
    self.downloadSizePerSec = self.currentSizePerSec;
    self.currentSizePerSec = 0;
}

@end
