//
//  ACAudioEncoder.h
//  ACLiveKitDemo
//
//  Created by beichen on 2021/4/28.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <CoreMedia/CoreMedia.h>
#import "ACLiveAudioConfiguration.h"
#import "ACAudioAACFrame.h"

NS_ASSUME_NONNULL_BEGIN

@class ACAudioEncoder;

/// 编码回调
@protocol ACAudioEncodingDelegate <NSObject>

- (void)audioEncodeOutputAACFrame:(ACAudioAACFrame *)aacFrame;

@end

/// 音频编码器：AudioToolbox
@interface ACAudioEncoder : NSObject

// 编码回调
@property (nonatomic, weak) id<ACAudioEncodingDelegate> delegate;

/// 初始化
/// @param configuration 音频配置
- (instancetype)initWithAudioStreamConfiguration:(ACLiveAudioConfiguration *)configuration;

/// 编码
/// @param audioData 音频数据
/// @param timestamp 时间戳
- (void)encodeAudioData:(NSData *)audioData timestamp:(uint64_t)timestamp;

@end

NS_ASSUME_NONNULL_END
