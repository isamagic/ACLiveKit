//
//  ACAudioRecorder.h
//  ACLiveKitDemo
//
//  Created by beichen on 2021/5/13.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "ACLiveAudioConfiguration.h"
#import "ACLiveProtocol.h"

NS_ASSUME_NONNULL_BEGIN

/// 音频录制回调
@protocol ACAudioRecorderDelegate <NSObject>

/// 输出音频数据
/// @param audioData 音频数据
- (void)recordOutputAudioData:(NSData *)audioData;

@end

// 录音：基于AudioQueue
@interface ACAudioRecorder : NSObject <ACLiveProtocol>

/// 录音回调
@property (nonatomic, weak) id<ACAudioRecorderDelegate> delegate;

/// 初始化
/// @param audioConfiguration 音频配置
- (instancetype)initWithAudioConfiguration:(ACLiveAudioConfiguration *)audioConfiguration;

@end

NS_ASSUME_NONNULL_END
