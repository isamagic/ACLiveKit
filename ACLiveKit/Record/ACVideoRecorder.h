//
//  ACVideoRecorder.h
//  ACLivePlayer
//
//  Created by beichen on 2021/5/16.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "ACLiveVideoConfiguration.h"
#import "ACLiveProtocol.h"

NS_ASSUME_NONNULL_BEGIN

/// 视频录制回调
@protocol ACVideoRecorderDelegate <NSObject>

/// 输出视频数据
/// @param videoData 视频数据
- (void)recordOutputVideoData:(CVPixelBufferRef)videoData;

@end

// 视频录制：基于AVFoundation
@interface ACVideoRecorder : NSObject <ACLiveProtocol>

// 视频录制回调
@property (nonatomic, weak) id<ACVideoRecorderDelegate> delegate;

/// 初始化
/// @param configuration 视频配置
- (instancetype)initWithVideoConfiguration:(ACLiveVideoConfiguration *)configuration;

// 设置预览页
- (void)setPreview:(UIView *)preview;

@end

NS_ASSUME_NONNULL_END
