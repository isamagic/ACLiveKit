//
//  ACVideoEncoder.m
//  ACLiveKitDemo
//
//  Created by beichen on 2021/4/28.
//

#import "ACVideoEncoder.h"

@interface ACVideoEncoder (){
    VTCompressionSessionRef compressionSession;
    NSInteger frameCount;
    NSData *sps;
    NSData *pps;
}

@property (nonatomic, strong) ACLiveVideoConfiguration *configuration;

@end

@implementation ACVideoEncoder

#pragma mark -- LifeCycle

- (instancetype)initWithVideoStreamConfiguration:(ACLiveVideoConfiguration *)configuration {
    if (self = [super init]) {
        _configuration = configuration;
        [self createSession];
    }
    return self;
}

- (void)createSession {
    // 创建编码器
    OSStatus status = VTCompressionSessionCreate(NULL,
                                                 _configuration.videoSize.width,
                                                 _configuration.videoSize.height,
                                                 kCMVideoCodecType_H264,
                                                 NULL,
                                                 NULL,
                                                 NULL,
                                                 VideoCompressionOutputCallback,
                                                 (__bridge void *)self,
                                                 &compressionSession);
    
    NSLog(@"ACVideoEncoder:VTCompressionSessionCreate: %@", @(status));
    if (status != noErr) {
        return;
    }

    // 设置编码参数
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, (__bridge CFTypeRef)@(_configuration.videoMaxKeyframeInterval));
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, (__bridge CFTypeRef)@(_configuration.videoMaxKeyframeInterval/_configuration.videoFrameRate));
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_ExpectedFrameRate, (__bridge CFTypeRef)@(_configuration.videoFrameRate));
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef)@(_configuration.videoBitRate));
    NSArray *limit = @[@(_configuration.videoBitRate * 1.5/8), @(1)];
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFArrayRef)limit);
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Main_AutoLevel);
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanTrue);
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_H264EntropyMode, kVTH264EntropyMode_CABAC);
    VTCompressionSessionPrepareToEncodeFrames(compressionSession);

}

- (void)dealloc {
    [self stop];
}

- (void)start {
    [self stop];
    [self createSession];
}

- (void)stop {
    if (compressionSession) {
        VTCompressionSessionCompleteFrames(compressionSession, kCMTimeInvalid);
        VTCompressionSessionInvalidate(compressionSession);
        CFRelease(compressionSession);
        compressionSession = NULL;
    }
}

#pragma mark - 编码

- (void)encodeVideoData:(CVPixelBufferRef)videoData timestamp:(uint64_t)timeStamp {
    
    frameCount++;
    
    // PTS:显示时间
    CMTime presentationTimeStamp = CMTimeMake(frameCount, (int32_t)_configuration.videoFrameRate);
    VTEncodeInfoFlags flags;
    CMTime duration = CMTimeMake(1, (int32_t)_configuration.videoFrameRate);

    // 关键帧
    NSDictionary *properties = nil;
    if (frameCount % (int32_t)_configuration.videoMaxKeyframeInterval == 0) {
        properties = @{(__bridge NSString *)kVTEncodeFrameOptionKey_ForceKeyFrame: @YES};
    }
    NSNumber *timeNumber = @(timeStamp);

    // 编码
    OSStatus status = VTCompressionSessionEncodeFrame(compressionSession,
                                                      videoData,
                                                      presentationTimeStamp,
                                                      duration,
                                                      (__bridge CFDictionaryRef)properties,
                                                      (__bridge_retained void *)timeNumber,
                                                      &flags);
    if(status != noErr){
        NSLog(@"ACVideoEncoder:VTCompressionSessionEncodeFrame: %@", @(status));
    }
}

#pragma mark - CallBack

static void VideoCompressionOutputCallback(void *VTref,
                                           void *VTFrameRef,
                                           OSStatus status,
                                           VTEncodeInfoFlags infoFlags,
                                           CMSampleBufferRef sampleBuffer) {
    
    if (status != noErr) {
        NSLog(@"ACVideoEncoder:VideoCompressionOutputCallback: %@", @(status));
        return;
    }
    
    
    CFArrayRef array = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true);
    CFDictionaryRef dic = (CFDictionaryRef)CFArrayGetValueAtIndex(array, 0);
    BOOL keyframe = !CFDictionaryContainsKey(dic, kCMSampleAttachmentKey_NotSync);
    uint64_t timeStamp = [((__bridge_transfer NSNumber *)VTFrameRef) longLongValue];

    ACVideoEncoder *videoEncoder = (__bridge ACVideoEncoder *)VTref;
    

    // 解析SPS和PPS（这是解码的关键信息）
    if (keyframe && !videoEncoder->sps) {
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);

        size_t sparameterSetSize, sparameterSetCount;
        const uint8_t *sparameterSet;
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0);
        if (statusCode == noErr) {
            size_t pparameterSetSize, pparameterSetCount;
            const uint8_t *pparameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0);
            if (statusCode == noErr) {
                videoEncoder->sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
                videoEncoder->pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
            }
        }
    }

    // dataBuffer就是压缩后的H264帧数据，包含一个或多个NAL单元
    // NAL单元 = NAL header + NAL body
    // NAL header：占1个字节，用于标记帧类型（IBP）
    // NAL body：原始字节序列
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if (statusCodeRet == noErr) {
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4; // 4个字节
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            // NAL单元前面有4个字节，存储了NAL单元的数据长度
            uint32_t NALUnitLength = 0;
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);

            // 大端转小端
            // 大端：从左到右，由低到高。网络传输数据采用大端模式
            // 小端：从左到右，从高到低。iOS的ARM架构采用小端模式
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);

            // 封装AVC帧
            ACVideoAVCFrame *avcFrame = [ACVideoAVCFrame new];
            avcFrame.timestamp = timeStamp;
            avcFrame.isKeyFrame = keyframe;
            avcFrame.sps = videoEncoder->sps;
            avcFrame.pps = videoEncoder->pps;
            avcFrame.body = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength)
                                                   length:NALUnitLength];
            
            // 压缩后的H264帧里面可能包含多个NAL unit数据吗？
            bufferOffset += AVCCHeaderLength + NALUnitLength;
            
            if ([videoEncoder.delegate respondsToSelector:@selector(videoEncodeOutputAVCFrame:)]) {
                [videoEncoder.delegate videoEncodeOutputAVCFrame:avcFrame];
            }
        }
    }
}

@end
