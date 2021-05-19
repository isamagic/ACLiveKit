//
//  ACPullStreamService.h
//  ACLiveKitDemo
//
//  Created by beichen on 2021/5/10.
//

#import <Foundation/Foundation.h>
#import "ACLiveAudioConfiguration.h"
#import "ACLiveVideoConfiguration.h"
#import "ACAudioAACFrame.h"
#import "ACVideoAVCFrame.h"
#import "ACLiveProtocol.h"

NS_ASSUME_NONNULL_BEGIN

// 拉流回调
@protocol ACPullStreamServiceDelegate <NSObject>

// 拉取的音频帧
- (void)pullStreamOutputAudioFrame:(ACAudioAACFrame *)aacFrame;

// 拉取的视频帧
- (void)pullStreamOutputVideoFrame:(ACVideoAVCFrame *)avcFrame;

@end

/// 拉流服务
@interface ACPullStreamService : NSObject <ACLiveProtocol>

// 拉流回调
@property (nonatomic, weak) id<ACPullStreamServiceDelegate> delegate;

// 音频配置（拉流解析得到的）
@property (nonatomic, strong, readonly) ACLiveAudioConfiguration *audioConfig;

// 视频配置（拉流解析得到的）
@property (nonatomic, strong, readonly) ACLiveVideoConfiguration *videoConfig;

/// 初始化
/// @param url 推流地址
- (instancetype)initWithUrl:(NSString *)url;

@end

NS_ASSUME_NONNULL_END
