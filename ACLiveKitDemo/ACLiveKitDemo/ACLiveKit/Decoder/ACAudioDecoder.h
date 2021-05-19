//
//  ACAudioDecoder.h
//  ACLiveKitDemo
//
//  Created by beichen on 2021/5/10.
//

#import <Foundation/Foundation.h>
#import "ACLiveAudioConfiguration.h"
#import "ACAudioAACFrame.h"

NS_ASSUME_NONNULL_BEGIN

// 音频解码回调
@protocol ACAudioDecoderDelegate <NSObject>

// 解码数据
- (void)audioDecoderOutputData:(NSData *)data;

@end

// 音频解码器：基于AudioToolbox
@interface ACAudioDecoder : NSObject

// 解码回调
@property (nonatomic, weak) id<ACAudioDecoderDelegate> delegate;

/// 初始化
/// @param config 音频配置
- (instancetype)initWithConfig:(ACLiveAudioConfiguration *)config;

// 解码
- (void)decodeAACFrame:(ACAudioAACFrame *)frame;

@end

NS_ASSUME_NONNULL_END
