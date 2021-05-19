//
//  ACLiveAudioConfiguration.h
//  ACLivePlayer
//
//  Created by beichen on 2021/5/18.
//

#import <Foundation/Foundation.h>

/// 音频码率 (默认96Kbps)
typedef NS_ENUM (NSUInteger, ACLiveAudioBitRate) {
    ACLiveAudioBitRate64 = 64000,   /// 64Kbps 音频码率
    ACLiveAudioBitRate96 = 96000,   /// 96Kbps 音频码率
    ACLiveAudioBitRate128 = 128000, /// 128Kbps 音频码率
    ACLiveAudioBitRateDefault = ACLiveAudioBitRate96
};

/// 音频采样率 (默认44.1KHz)
typedef NS_ENUM (NSUInteger, ACLiveAudioSampleRate){
    ACLiveAudioSampleRate16 = 16000,    /// 16KHz 采样率
    ACLiveAudioSampleRate44 = 44100,    /// 44.1KHz 采样率
    ACLiveAudioSampleRate48 = 48000,    /// 48KHz 采样率
    ACLiveAudioSampleRateDefault = ACLiveAudioSampleRate44
};

@interface ACLiveAudioConfiguration : NSObject

/// 默认音频配置
+ (instancetype)defaultConfiguration;

#pragma mark - Attribute

/// 声道数目(default 2)
@property (nonatomic, assign) NSUInteger numberOfChannels;
/// 采样大小（默认16 bit）
@property (nonatomic, assign) NSUInteger audioSampleSize;
/// 采样率
@property (nonatomic, assign) ACLiveAudioSampleRate audioSampleRate;
/// 码率
@property (nonatomic, assign) ACLiveAudioBitRate audioBitrate;

/// Audio Specific Config: AAC Profile + 采样率 + 声道数 + 保留字段
@property (nonatomic, assign, readonly) char *asc;
/// 缓存区长度
@property (nonatomic, assign,readonly) NSUInteger bufferLength;

@end
