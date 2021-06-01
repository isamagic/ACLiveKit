//
//  ACAudioDecoder.m
//  ACLivePlayer
//
//  Created by beichen on 2021/5/10.
//

#import "ACAudioDecoder.h"
#import <AudioToolbox/AudioToolbox.h>

// 解码数据
typedef struct {
    char *data;
    UInt32 size;
    UInt32 channelCount;
    AudioStreamPacketDescription packetDesc;
} AudioUserData;

@interface ACAudioDecoder ()

// 解码线程
@property (nonatomic, strong) dispatch_queue_t queue;

// 解码转换
@property (nonatomic, assign) AudioConverterRef converter;

// 音频配置
@property (nonatomic, strong) ACLiveAudioConfiguration *config;

@end

@implementation ACAudioDecoder

- (instancetype)initWithConfig:(ACLiveAudioConfiguration *)config {
    if (self = [super init]) {
        _config = config;
        _queue = dispatch_queue_create("ACAudioDecoder", DISPATCH_QUEUE_SERIAL);
        [self createConverter];
    }
    return self;
}

- (void)dealloc {
    AudioConverterDispose(_converter);
}

- (void)createConverter {
    
    // 输入音频格式
    AudioStreamBasicDescription inputFormat = {0};
    inputFormat.mFormatID = kAudioFormatMPEG4AAC;           // AAC编码
    inputFormat.mFormatFlags = kMPEG4Object_AAC_LC;         // 格式标记
    inputFormat.mSampleRate = self.config.audioSampleRate;  // 采样率
    inputFormat.mChannelsPerFrame = (UInt32)self.config.numberOfChannels; // 声道数
    inputFormat.mFramesPerPacket = 1024;                    // AAC一帧是1024个字节
    
    // 输出音频格式
    AudioStreamBasicDescription outputFormat = {0};
    outputFormat.mSampleRate = self.config.audioSampleRate; // 采样率
    outputFormat.mFormatID = kAudioFormatLinearPCM; // 音频格式：PCM
    outputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    outputFormat.mFramesPerPacket = 1;
    outputFormat.mChannelsPerFrame = (UInt32)self.config.numberOfChannels; // 声道数
    outputFormat.mBitsPerChannel = (UInt32)self.config.audioSampleSize; // 每个声道占用的位数
    outputFormat.mBytesPerFrame = outputFormat.mChannelsPerFrame * outputFormat.mBitsPerChannel/8;
    outputFormat.mBytesPerPacket = outputFormat.mBytesPerFrame * outputFormat.mFramesPerPacket;
    
    // 创建解码器
    OSStatus status = AudioConverterNew(&inputFormat, &outputFormat, &_converter);
    NSLog(@"ACAudioDecoder:AudioConverterNew: %@", @(status));
}

// 解码三要素：输入数据、解码算法、输出数据
// 1. 输入：NSData(AAC) -> AudioBuffer
// 2. 算法：AudioConverterRef (AAC -> PCM)
// 3. 输出：AudioBuffer -> NSData(PCM) -> CMSampleBufferRef
- (void)decodeAACFrame:(ACAudioAACFrame *)frame {
    
    __weak typeof(self) wself = self;
    dispatch_async(_queue, ^{
        // 输入数据(AAC)
        AudioUserData userData = {0};
        userData.channelCount = (UInt32)wself.config.numberOfChannels;
        userData.data = (char*)[frame.body bytes];
        userData.size = (UInt32)[frame.body length];
        userData.packetDesc.mStartOffset = 0;
        userData.packetDesc.mVariableFramesInPacket = 0;
        userData.packetDesc.mDataByteSize = (UInt32)[frame.body length];
            
        // 输出数据(PCM)
        UInt32 pcmBufferSize = (UInt32)wself.config.bufferLength;
        char *pcmBuffer = malloc(pcmBufferSize);
        memset(pcmBuffer, 0, pcmBufferSize);
        AudioBufferList outBufferList = {0};
        outBufferList.mNumberBuffers = 1;
        outBufferList.mBuffers[0].mNumberChannels = (UInt32)wself.config.numberOfChannels;
        outBufferList.mBuffers[0].mDataByteSize = (UInt32)pcmBufferSize;
        outBufferList.mBuffers[0].mData = pcmBuffer;
        
        // 解码
        UInt32 outputDataPacketSize = pcmBufferSize;
        OSStatus status = AudioConverterFillComplexBuffer(wself.converter,
                                                          outputAudioDataProc,
                                                          &userData,
                                                          &outputDataPacketSize,
                                                          &outBufferList,
                                                          NULL);
        if (status != noErr) {
            NSLog(@"ACAudioDecoder:AudioConverterFillComplexBuffer: %@", @(status));
            return;
        }
        
        // 获取结果
        AudioBuffer buffer = outBufferList.mBuffers[0];
        if (buffer.mDataByteSize > 0) {
            NSData *rawData = [NSData dataWithBytes:buffer.mData length:buffer.mDataByteSize];
            if ([wself.delegate respondsToSelector:@selector(audioDecoderOutputData:)]) {
                [wself.delegate audioDecoderOutputData:rawData];
            }
        }
        free(pcmBuffer);
    });
}

// 解码过程中，会要求这个函数来填充输入数据，也就是AAC数据
OSStatus outputAudioDataProc(AudioConverterRef inConverter,
                             UInt32 *ioNumberDataPackets,
                             AudioBufferList *ioData,
                             AudioStreamPacketDescription **aPacketDesc,
                             void *inUserData) {
    
    AudioUserData *userData = (AudioUserData *)(inUserData);
    if (userData->size <= 0) {
        ioNumberDataPackets = 0;
        return -1;
    }
    
    // 填充数据
    if (aPacketDesc) {
        userData->packetDesc.mStartOffset = 0;
        userData->packetDesc.mVariableFramesInPacket = 0;
        userData->packetDesc.mDataByteSize = userData->size;
        *aPacketDesc = &userData->packetDesc;
    }
    
    ioData->mBuffers[0].mData = userData->data;
    ioData->mBuffers[0].mDataByteSize = userData->size;
    ioData->mBuffers[0].mNumberChannels = userData->channelCount;
    
    return noErr;
}

@end
