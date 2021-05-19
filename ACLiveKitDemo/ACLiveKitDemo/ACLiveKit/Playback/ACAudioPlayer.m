//
//  ACAudioPlayer.m
//  ACLiveKitDemo
//
//  Created by beichen on 2021/5/11.
//

#import "ACAudioPlayer.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

// 输出音频队列缓冲个数
static const int kPlayBuffers = 1024;

@interface ACAudioPlayer ()
{
    dispatch_semaphore_t _lock;
    AudioQueueBufferRef mBuffers[kPlayBuffers];
    BOOL audioQueueBufferUsed[kPlayBuffers];  // 判断音频缓存是否在使用
}

/// 音频配置
@property (nonatomic, strong) ACLiveAudioConfiguration *config;

@property (nonatomic) AudioStreamBasicDescription asbd;
@property (nonatomic) AudioQueueRef audioQueue;
@property (nonatomic) dispatch_queue_t queue;
@property (nonatomic, assign) BOOL isRunning;
@property (nonatomic, assign) int bufferSize;

@end

@implementation ACAudioPlayer

- (instancetype)initWithConfig:(ACLiveAudioConfiguration *)config {
    if (self = [super init]) {
        _queue = dispatch_queue_create("ACAudioPlayer", DISPATCH_QUEUE_SERIAL);
        _config = config;
        [self start];
    }
    return self;
}

- (void)dealloc {
    AudioQueueStop(self.audioQueue, true);
}

// 开始播放
- (void)start {
    // 麦克风设置（静音健关闭也能播放声音）
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback
                  withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker |
                                AVAudioSessionCategoryOptionAllowBluetooth
                        error:nil];
    [audioSession setActive:YES error:nil];

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
    void *handle = (__bridge void *)self;
    OSStatus status = AudioQueueNewOutput(&_asbd, HandleOutputBuffer, handle, NULL, NULL, 0, &_audioQueue);
    NSLog(@"ACAudioPlayer:AudioQueueNewOutput: %@", @(status));
    
    // 设置音量
    status = AudioQueueSetParameter(_audioQueue, kAudioQueueParam_Volume, 1);
    NSLog(@"ACAudioPlayer:AudioQueueSetParameter: %@", @(status));
    
    // 创建AudioQueueBuffer
    _bufferSize = _asbd.mSampleRate * _asbd.mBytesPerPacket;
    for (int i = 0; i < kPlayBuffers; ++i) {
        AudioQueueBufferRef buffer;
        OSStatus status = AudioQueueAllocateBuffer(_audioQueue, _bufferSize, &buffer);
        NSLog(@"ACAudioPlayer:AudioQueueAllocateBuffer: %@", @(status));
        audioQueueBufferUsed[i] = NO;
        mBuffers[i] = buffer;
    }
    
    status = AudioQueueStart(self.audioQueue, NULL);
    if (status == noErr) {
        self.isRunning = YES;
    }
    NSLog(@"ACAudioPlayer:AudioQueueStart: %@", @(status));
}

// 停止播放
- (void)stop {
    for (int i = 0; i < kPlayBuffers; ++i) {
        AudioQueueFreeBuffer(self.audioQueue, mBuffers[i]);
        audioQueueBufferUsed[i] = NO;
    }
    OSStatus status = AudioQueueStop(self.audioQueue, true);
    if (status == noErr) {
        self.isRunning = NO;
    }
    NSLog(@"ACAudioPlayer:AudioQueueStop: %@", @(status));
}


// 播放PCM流
- (void)playPcmData:(NSData *)pcmData {
    if (!_isRunning) {
        return;
    }
    
    dispatch_async(_queue, ^{
        
        // 获取空闲的缓冲区
        int i = 0;
        while (true) {
            if (!self->audioQueueBufferUsed[i]) {
                self->audioQueueBufferUsed[i] = YES;
                break;
            }else {
                i++;
                if (i >= kPlayBuffers) {
                    i = 0;
                }
            }
        }
        
        AudioQueueBufferRef fillBuffer = self->mBuffers[i];
        fillBuffer->mAudioDataByteSize = (UInt32)pcmData.length;
        memcpy(fillBuffer->mAudioData, pcmData.bytes, pcmData.length);
        AudioQueueEnqueueBuffer(self.audioQueue, fillBuffer, 0, NULL);
    });
}

// 声音播放完毕的回调
static void HandleOutputBuffer(void *outUserData,
                               AudioQueueRef outAQ,
                               AudioQueueBufferRef outBuffer) {
    ACAudioPlayer *player = (__bridge ACAudioPlayer *)outUserData;
    if (!player.isRunning) {
        return;
    }

    [player resetBufferState:outAQ and:outBuffer];
}

- (void)resetBufferState:(AudioQueueRef)audioQueueRef and:(AudioQueueBufferRef)audioQueueBufferRef {
    for (int i = 0; i < kPlayBuffers; i++) {
        // 将这个buffer设为未使用
        if (audioQueueBufferRef == mBuffers[i]) {
            audioQueueBufferUsed[i] = NO;
        }
    }
}

@end
