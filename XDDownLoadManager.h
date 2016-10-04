//
//  XDDownLoadManager.h
//  离线断点下载
//
//  Created by xKing on 16/5/6.
//  Copyright © 2015年 xKing. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol XDDownLoadManagerDelegate <NSObject>
@optional
- (void)downLoadManagerProgress:(CGFloat)progress;

@end

typedef void(^successBlock)( NSString * _Nonnull filePath ,CGFloat completed,BOOL finished);

typedef void(^failedBlock)(NSError *_Nonnull error);

@interface XDDownLoadManager : NSObject

+ (_Nonnull instancetype)sharedDownLoadManager;

- (void)downLoadWithUrl:(NSString *_Nonnull)url downLoadSuccess:(_Nonnull successBlock)success downLoadFailed:(_Nonnull failedBlock)error;

- (void)downLoadSuspend;

- (void)downLoadResumeWithDelegate:(nullable id<XDDownLoadManagerDelegate>) delegate;

@end
