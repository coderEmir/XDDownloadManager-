//
//  ViewController.m
//  离线断点下载
//
//  Created by xKing on 16/9/6.
//  Copyright © 2016年 xKing. All rights reserved.
//



//  下载文件需要的URL
// 所需要下载的文件的URL

// 文件名（沙盒中的文件名）
#define XDFilename [self md5StringWithStr:_fileUrl]

// 文件的存放路径（caches）
#define XDFileFullpath [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:XDFilename]

// 存储文件总长度的文件路径（caches）
#define XDTotalLengthFullpath [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"totalLength.xd"]

// 文件的已下载长度
#define XDDownloadLength [[[NSFileManager defaultManager] attributesOfItemAtPath:XDFileFullpath error:nil][NSFileSize] integerValue]

#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonHMAC.h>

#import "XDDownLoadManager.h"

@interface XDDownLoadManager () <NSURLSessionDataDelegate>


/** delegate */
@property (nonatomic , assign) id<XDDownLoadManagerDelegate> delegate;

/** 下载任务 */
@property (nonatomic, strong) NSURLSessionDataTask *dataTask;
/** session */
@property (nonatomic, strong) NSURLSession *session;
/** 写文件的流对象 */
@property (nonatomic, strong) NSOutputStream *stream;
/** 文件的总长度 */
@property (nonatomic, assign) NSInteger totalLength;
/** 需文件的Url */
@property (nonatomic , copy) NSString *fileUrl;
/** 下载进度 */
@property (nonatomic , assign) CGFloat progress;
/** 下载失败 */
@property (nonatomic, strong) NSError *error;
/** 下载是否完成 */
@property (nonatomic , assign) BOOL mark;

@end

@implementation XDDownLoadManager

#pragma mark ---- 外部接口


static XDDownLoadManager * _manager;

+ (instancetype)sharedDownLoadManager
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _manager = [[self alloc] init];
    });
    return _manager;
}

- (void)downLoadWithUrl:(NSString *)url downLoadSuccess:(successBlock)success downLoadFailed:(failedBlock)error
{
    self.fileUrl = url;
    NSArray *arr = [self checkDocument];
//    NSLog(@"下载量：%@ ---------- 是否完成：%@",arr.firstObject , arr.lastObject );
//    B->KB->MB->GB
    CGFloat  completed = [arr.firstObject integerValue] / 1000;
//    if (completed > 1000) {
//        completed = completed / 1000;
//    }

    success(XDFileFullpath,completed,[arr.lastObject boolValue]);
    error(self.error);
}

- (void)downLoadResumeWithDelegate:(id<XDDownLoadManagerDelegate>)delegate
{
    [self.dataTask resume];
    self.delegate = delegate;
}


- (void)downLoadSuspend
{
    [self.dataTask suspend];
    
}

- (NSURLSession *)session
{
    if (!_session) {
        _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[[NSOperationQueue alloc] init]];
    }
    return _session;
}

- (NSOutputStream *)stream
{
    if (!_stream) {
        _stream = [NSOutputStream outputStreamToFileAtPath:XDFileFullpath append:YES];
    }
    return _stream;
}

- (NSURLSessionDataTask *)dataTask
{
    if (![[self checkDocument].lastObject boolValue]){
            // 创建请求
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:self.fileUrl]];
            
            // 设置请求头
            // Range : bytes=xxx-xxx
            NSString *range = [NSString stringWithFormat:@"bytes=%zd-", XDDownloadLength];
            [request setValue:range forHTTPHeaderField:@"Range"];
            
            // 创建一个Data任务
            _dataTask = [self.session dataTaskWithRequest:request];
        }
           return _dataTask;
}

- (NSArray *)checkDocument
{
    NSMutableArray *array = [NSMutableArray array];
    NSInteger totalLength = [[NSDictionary dictionaryWithContentsOfFile:XDTotalLengthFullpath][XDFilename] integerValue];
    if (totalLength && (XDDownloadLength == totalLength)) {
        NSLog(@"已经下载完毕！");

        self.mark = YES;
    }else{
    NSLog(@"还需要下载-------");
    self.mark = NO;
   
    }
    [array addObject:@(XDDownloadLength)];
    [array addObject:@(self.mark)];
    return array;
}


#pragma mark - <NSURLSessionDataDelegate>
/**
 * 1.接收到响应
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSHTTPURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    // 打开流
    [self.stream open];
    
    // 获得服务器这次请求 返回数据的总长度
    self.totalLength = [response.allHeaderFields[@"Content-Length"] integerValue] + XDDownloadLength;
    
    // 存储总长度
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:XDTotalLengthFullpath];
    if (dict == nil) dict = [NSMutableDictionary dictionary];
    dict[XDFilename] = @(self.totalLength);
    [dict writeToFile:XDTotalLengthFullpath atomically:YES];
    
    // 接收这个请求，允许接收服务器的数据
    completionHandler(NSURLSessionResponseAllow);
}

/**
 * 2.接收到服务器返回的数据（这个方法可能会被调用N次）
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    // 写入数据
    [self.stream write:data.bytes maxLength:data.length];
    
    // 下载进度
    self.progress = 1.0 *XDDownloadLength / self.totalLength;
    
    if ([self.delegate respondsToSelector:@selector(downLoadManagerProgress:)]) {
        [self.delegate downLoadManagerProgress:self.progress];
    }
    //    NSLog(@"%f",self.progress);
}

/**
 * 3.请求完毕（成功\失败）
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    self.error = error;
    // 关闭流
    [self.stream close];
    self.stream = nil;
    
    // 清除任务
    self.dataTask = nil;
}

- (NSString *)md5StringWithStr:(NSString *)str
{
    const char *string = str.UTF8String;
    int length = (int)strlen(string);
    unsigned char bytes[CC_MD5_DIGEST_LENGTH];
    CC_MD5(string, length, bytes);
    return [self stringFromBytes:bytes length:CC_MD5_DIGEST_LENGTH];
}

- (NSString *)stringFromBytes:(unsigned char *)bytes length:(NSUInteger)length
{
    NSMutableString *mutableString = @"".mutableCopy;
    for (int i = 0; i < length; i++)
        [mutableString appendFormat:@"%02x", bytes[i]];
    return [NSString stringWithString:mutableString];
}

@end
