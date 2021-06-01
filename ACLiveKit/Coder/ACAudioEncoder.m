//
//  ACAudioEncoder.m
//  ACLivePlayer
//
//  Created by beichen on 2021/4/28.
//

#import "ACAudioEncoder.h"
#import <CoreAudio/CoreAudioTypes.h>
#import "ACAudioAACFrame.h"

@interface ACAudioEncoder ()
{
    char *leftBuf;
    char *aacBuf;
    NSInteger leftLength;
}

/// 音频编码器
@property (nonatomic) AudioConverterRef converter;

/// 音频配置
@property (nonatomic, strong) ACLiveAudioConfiguration *configuration;

@end

@implementation ACAudioEncoder

- (instancetype)initWithAudioStreamConfiguration:(ACLiveAudioConfiguration *)configuration {
    if (self = [super init]) {
        _configuration = configuration;
        leftBuf = malloc(_configuration.bufferLength);
        aacBuf = malloc(_configuration.bufferLength);
        [self createAudioConvert];
    }
    return self;
}

- (void)createAudioConvert {
    
    // 输入的音频格式
    AudioStreamBasicDescription inputFormat = {0};
    inputFormat.mFormatID = kAudioFormatLinearPCM; // 音频格式：PCM
    inputFormat.mSampleRate = self.configuration.audioSampleRate; // 采样率
    inputFormat.mChannelsPerFrame = (UInt32)self.configuration.numberOfChannels; // 声道数
    inputFormat.mBitsPerChannel = (UInt32)self.configuration.audioSampleSize; // 采样大小
    inputFormat.mFramesPerPacket = 1;
    inputFormat.mBytesPerFrame = inputFormat.mChannelsPerFrame * inputFormat.mBitsPerChannel/8;
    inputFormat.mBytesPerPacket = inputFormat.mBytesPerFrame * inputFormat.mFramesPerPacket;
    inputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    
    // 输出的音频格式
    AudioStreamBasicDescription outputFormat = {0};
    outputFormat.mFormatID = kAudioFormatMPEG4AAC;            // AAC编码
    outputFormat.mSampleRate = inputFormat.mSampleRate;       // 采样率保持一致
    outputFormat.mChannelsPerFrame = (UInt32)self.configuration.numberOfChannels; // 声道数
    outputFormat.mFramesPerPacket = 1024;                     // AAC一帧是1024个字节
    
    // 创建编码器
    OSStatus status = AudioConverterNew(&inputFormat,
                                        &outputFormat,
                                        &_converter);
    NSLog(@"ACAudioEncoder:AudioConverterNew: %@", @(status));
    
    if (status == noErr) {
        // 设置码率
        UInt32 outSize = (UInt32)self.configuration.audioBitrate;
        UInt32 inSize = sizeof(outSize);
        AudioConverterSetProperty(_converter, kAudioConverterEncodeBitRate, inSize, &outSize);
    }
}

- (void)dealloc {
    if (aacBuf) free(aacBuf);
    if (leftBuf) free(leftBuf);
    AudioConverterDispose(_converter);
}

#pragma mark -- ACAudioEncoder

- (void)encodeAudioData:(NSData *)audioData timestamp:(uint64_t)timestamp {
    
    // 先累积到一定数量（4KB）再进行编码
    if (leftLength + audioData.length >= self.configuration.bufferLength) {
        /// 编码
        NSInteger totalSize = leftLength + audioData.length;
        NSInteger encodeCount = totalSize/self.configuration.bufferLength;
        char *totalBuf = malloc(totalSize);
        char *p = totalBuf;
        
        memset(totalBuf, 0, (int)totalSize);
        memcpy(totalBuf, leftBuf, leftLength);
        memcpy(totalBuf + leftLength, audioData.bytes, audioData.length);
        
        for (int i = 0; i < encodeCount; i++){
            [self encodeBuffer:p timeStamp:timestamp];
            p += self.configuration.bufferLength;
        }
        
        leftLength = totalSize % self.configuration.bufferLength;
        memset(leftBuf, 0, self.configuration.bufferLength);
        memcpy(leftBuf, totalBuf + (totalSize - leftLength), leftLength);
        
        free(totalBuf);
    } else {
        /// 积累
        memcpy(leftBuf+leftLength, audioData.bytes, audioData.length);
        leftLength = leftLength + audioData.length;
    }
}

// 编码3要素：输入数据、编码算法、输出数据
// 1. 输入：CMSampleBufferRef -> NSData(PCM) -> AudioBuffer
// 2. 算法：AudioConverterRef (PCM -> AAC)
// 3. 输出：AudioBuffer -> NSData(AAC)
- (void)encodeBuffer:(char*)buf timeStamp:(uint64_t)timeStamp {
    
    // 输入数据
    AudioBuffer inBuffer;
    inBuffer.mNumberChannels = 1;
    inBuffer.mData = buf; // 输入缓冲区
    inBuffer.mDataByteSize = (UInt32)self.configuration.bufferLength;
    
    AudioBufferList inBufferList;
    inBufferList.mNumberBuffers = 1;
    inBufferList.mBuffers[0] = inBuffer;
    
    
    // 输出数据
    AudioBufferList outBufferList;
    outBufferList.mNumberBuffers = 1;
    outBufferList.mBuffers[0].mNumberChannels = inBuffer.mNumberChannels;
    outBufferList.mBuffers[0].mDataByteSize = inBuffer.mDataByteSize;
    outBufferList.mBuffers[0].mData = aacBuf; // 设置AAC缓冲区
    UInt32 outputDataPacketSize = 1;
    
    // 编码转换
    OSStatus status = AudioConverterFillComplexBuffer(_converter,
                                                      InputAudioDataProc,
                                                      &inBufferList,
                                                      &outputDataPacketSize,
                                                      &outBufferList,
                                                      NULL);
    
    if (status != noErr) {
        NSLog(@"ACAudioEncoder:AudioConverterFillComplexBuffer: %@", @(status));
        return;
    }
    
    // 封装为AAC帧
    ACAudioAACFrame *aacFrame = [ACAudioAACFrame new];
    aacFrame.timestamp = timeStamp;
    
    char exeData[2];
    exeData[0] = _configuration.asc[0];
    exeData[1] = _configuration.asc[1];
    aacFrame.header = [NSData dataWithBytes:exeData length:2];
    aacFrame.body = [NSData dataWithBytes:aacBuf length:outBufferList.mBuffers[0].mDataByteSize];
    
    if ([self.delegate respondsToSelector:@selector(audioEncodeOutputAACFrame:)]) {
        [self.delegate audioEncodeOutputAACFrame:aacFrame];
    }
}

#pragma mark -- AudioCallBack

// 编码过程中，会要求这个函数来填充输入数据，也就是原始PCM数据
OSStatus InputAudioDataProc(AudioConverterRef inConverter,
                            UInt32 *ioNumberDataPackets,
                            AudioBufferList *ioData,
                            AudioStreamPacketDescription **outDataPacketDescription,
                            void *inUserData) {
    AudioBufferList bufferList = *(AudioBufferList *)inUserData;
    ioData->mBuffers[0].mNumberChannels = 1;
    ioData->mBuffers[0].mData = bufferList.mBuffers[0].mData;
    ioData->mBuffers[0].mDataByteSize = bufferList.mBuffers[0].mDataByteSize;
    return noErr;
}

@end
