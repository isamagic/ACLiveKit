//
//  ACAudioPlayer.h
//  ACLiveKitDemo
//
//  Created by beichen on 2021/5/11.
//

#import <Foundation/Foundation.h>
#import "ACLiveAudioConfiguration.h"
#import "ACLiveProtocol.h"

NS_ASSUME_NONNULL_BEGIN

/// 音频播放器
@interface ACAudioPlayer : NSObject <ACLiveProtocol>

/// 初始化
/// @param config 音频配置
- (instancetype)initWithConfig:(ACLiveAudioConfiguration *)config;

/// 播放PCM流
- (void)playPcmData:(NSData *)pcmData;

@end

NS_ASSUME_NONNULL_END
