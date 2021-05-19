//
//  ACPushStreamService.h
//  ACLiveKitDemo
//
//  Created by beichen on 2021/5/8.
//

#import <Foundation/Foundation.h>
#import "ACLiveAudioConfiguration.h"
#import "ACLiveVideoConfiguration.h"
#import "ACAudioAACFrame.h"
#import "ACVideoAVCFrame.h"
#import "ACLiveProtocol.h"

/// 流状态
typedef NS_ENUM (NSUInteger, ACLiveState){
    ACLiveStateStart = 0, // 已连接
    ACLiveStateStop  = 1, // 已断开
};

NS_ASSUME_NONNULL_BEGIN

// 推流回调
@protocol ACPushStreamServiceDelegate <NSObject>

// 推流状态
- (void)pushStreamServiceStatus:(ACLiveState)status;

@end

// 推流服务：基于RTMP协议
@interface ACPushStreamService : NSObject <ACLiveProtocol>

// 推流回调
@property (nonatomic, weak) id<ACPushStreamServiceDelegate> delegate;

// 音频配置
@property (nonatomic, strong) ACLiveAudioConfiguration *audioConfig;

// 视频配置
@property (nonatomic, strong) ACLiveVideoConfiguration *videoConfig;

/// 初始化
/// @param url 推流地址
- (instancetype)initWithUrl:(NSString *)url;

/// 发送数据
/// @param frame 数据帧
- (void)sendFrame:(ACAVFrame *)frame;

@end

NS_ASSUME_NONNULL_END
