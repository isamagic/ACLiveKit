//
//  ACVideoEncoder.h
//  ACLiveKitDemo
//
//  Created by beichen on 2021/4/28.
//

#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import "ACLiveVideoConfiguration.h"
#import "ACVideoAVCFrame.h"
#import "ACLiveProtocol.h"

NS_ASSUME_NONNULL_BEGIN

/// 编码回调
@protocol ACVideoEncodingDelegate <NSObject>

- (void)videoEncodeOutputAVCFrame:(ACVideoAVCFrame *)avcFrame;

@end

// 视频编码器：VideoToolbox
@interface ACVideoEncoder : NSObject <ACLiveProtocol>

// 编码回调
@property (nonatomic, weak) id<ACVideoEncodingDelegate> delegate;

/// 初始化
/// @param configuration 视频配置
- (instancetype)initWithVideoStreamConfiguration:(ACLiveVideoConfiguration *)configuration;

/// 编码
/// @param videoData 视频数据
/// @param timestamp 时间戳
- (void)encodeVideoData:(CVPixelBufferRef)videoData timestamp:(uint64_t)timestamp;

@end

NS_ASSUME_NONNULL_END
