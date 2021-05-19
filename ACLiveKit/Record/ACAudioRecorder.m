//
//  ACAudioRecorder.m
//  ACLivePlayer
//
//  Created by beichen on 2021/5/13.
//

#import "ACAudioRecorder.h"
#import <AVFoundation/AVFoundation.h>

// 音频队列缓冲区大小
static const int kRecordBuffers = 3;

@interface ACAudioRecorder ()
{
    // 音频录制缓冲队列
    AudioQueueBufferRef mBuffers[kRecordBuffers];
}

/// 音频配置
@property (nonatomic, strong) ACLiveAudioConfiguration *config;

/// 音频输出格式描述
@property (nonatomic) AudioStreamBasicDescription asbd;

/// 录音队列（实现录音）
@property (nonatomic) AudioQueueRef audioQueue;

/// 录音线程
@property (nonatomic) dispatch_queue_t queue;

/// AudioQueueBuffer的大小
@property (nonatomic) UInt32 bufferSize;

/// 是否正在录制
@property (nonatomic) BOOL isRunning;

@end

@implementation ACAudioRecorder

/// 初始化
/// @param audioConfiguration 音频配置
- (instancetype)initWithAudioConfiguration:(ACLiveAudioConfiguration *)audioConfiguration {
    if (self = [super init]) {
        _queue = dispatch_queue_create("ACAudioRecorder", DISPATCH_QUEUE_SERIAL);
        _config = audioConfiguration;
        [self prepare];
    }
    return self;
}

- (void)prepare {
    // 输出音频格式
    _asbd.mFormatID = kAudioFormatLinearPCM; // 音频格式
    _asbd.mSampleRate = self.config.audioSampleRate; // 采样率
    _asbd.mBitsPerChannel = (UInt32)self.config.audioSampleSize; // 采样大小
    _asbd.mChannelsPerFrame = (UInt32)self.config.numberOfChannels; // 声道数
    _asbd.mFramesPerPacket = 1; // 对于PCM，每个Packet只包含一个Frame
    _asbd.mBytesPerFrame = _asbd.mChannelsPerFrame * _asbd.mBitsPerChannel/8; // Frame的大小
    _asbd.mBytesPerPacket = _asbd.mFramesPerPacket * _asbd.mBytesPerFrame; // Packet的大小
    _asbd.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    
    // 创建AudioQueue
    OSStatus status = AudioQueueNewInput(&_asbd,
                                         HandleInputBuffer,
                                         (__bridge void *)self,
                                         NULL,
                                         NULL,
                                         0,
                                         &_audioQueue);
    NSLog(@"ACAudioRecorder:AudioQueueNewInput: %@", @(status));
    
    // 创建AudioQueueBuffer
    _bufferSize = _asbd.mSampleRate * _asbd.mBytesPerPacket;
    for (int i = 0; i < kRecordBuffers; ++i) {
        AudioQueueBufferRef buffer;
        OSStatus status = AudioQueueAllocateBuffer(_audioQueue, _bufferSize, &buffer);
        NSLog(@"ACAudioRecorder:AudioQueueAllocateBuffer: %@", @(status));
        mBuffers[i] = buffer;
        status = AudioQueueEnqueueBuffer(_audioQueue, buffer, 0, NULL);
        NSLog(@"ACAudioRecorder:AudioQueueEnqueueBuffer: %@", @(status));
    }
}

// 开始录音
- (void)start {
    dispatch_async(_queue, ^{
        OSStatus status = AudioQueueStart(self.audioQueue, NULL);
        if (status == noErr) {
            self.isRunning = YES;
        }
        NSLog(@"ACAudioRecorder:AudioQueueStart: %@", @(status));
    });
}

// 停止录音
- (void)stop {
    OSStatus status = AudioQueuePause(self.audioQueue);
    if (status == noErr) {
        self.isRunning = NO;
    }
    NSLog(@"ACAudioRecorder:AudioQueuePause: %@", @(status));
}

- (void)dealloc {
    AudioQueueStop(_audioQueue, true);
}

#pragma mark - Callback

// 录制的音频数据
static void HandleInputBuffer(void *aqData,
                              AudioQueueRef inAQ,
                              AudioQueueBufferRef inBuffer,
                              const AudioTimeStamp *inStartTime,
                              UInt32 inNumPackets,
                              const AudioStreamPacketDescription *inPacketDesc) {
    // 解析数据，传给编码器
    ACAudioRecorder *recorder = (__bridge ACAudioRecorder *)(aqData);
    if (!recorder.isRunning) {
        return;
    }
    
    NSData *rawData = [NSData dataWithBytes:inBuffer->mAudioData
                                     length:inBuffer->mAudioDataByteSize];
    if ([recorder.delegate respondsToSelector:@selector(recordOutputAudioData:)]) {
        [recorder.delegate recordOutputAudioData:rawData];
    }
    
    // 将buffer给audio queue
    OSStatus status = AudioQueueEnqueueBuffer(recorder.audioQueue, inBuffer, 0, NULL);
    if (status != noErr) {
        NSLog(@"ACAudioRecorder:AudioQueueEnqueueBuffer: %@", @(status));
    }
}

@end
