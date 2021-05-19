//
//  ACVideoDecoder.m
//  ACLivePlayer
//
//  Created by beichen on 2021/5/14.
//

#import "ACVideoDecoder.h"
#import <VideoToolbox/VideoToolbox.h>

@interface ACVideoDecoder ()
{
    dispatch_queue_t _queue;                                // 解码线程
    VTDecompressionSessionRef _deocderSession;              // 解码session
    CMVideoFormatDescriptionRef _decoderFormatDescription;  // 解码format, 封装了sps和pps
}

@end

@implementation ACVideoDecoder

- (instancetype)init {
    if (self = [super init]) {
        _queue = dispatch_queue_create("ACVideoDecoder", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)createSession {
    
    NSNumber *formatType = @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange);
    NSDictionary *pbAttributes = @{(id)kCVPixelBufferPixelFormatTypeKey : formatType,
                                   (id)kCVPixelBufferOpenGLCompatibilityKey : @(YES)};
    
    VTDecompressionOutputCallbackRecord callBackRecord;
    callBackRecord.decompressionOutputCallback = didDecompress;
    callBackRecord.decompressionOutputRefCon = (__bridge void *)self;
    OSStatus status = VTDecompressionSessionCreate(kCFAllocatorDefault,
                                                   _decoderFormatDescription,
                                                   NULL,
                                                   (__bridge CFDictionaryRef)pbAttributes,
                                                   &callBackRecord,
                                                   &_deocderSession);
    VTSessionSetProperty(_deocderSession, kVTDecompressionPropertyKey_ThreadCount, (__bridge CFTypeRef)@(1));
    VTSessionSetProperty(_deocderSession, kVTDecompressionPropertyKey_RealTime, kCFBooleanTrue);
    NSLog(@"ACVideoDecoder:VTDecompressionSessionCreate: %@", @(status));
}

- (void)dealloc {
    [self stop];
}

- (void)start {
    [self stop];
    [self createSession];
}

- (void)stop {
    if (_deocderSession) {
        VTDecompressionSessionInvalidate(_deocderSession);
        CFRelease(_deocderSession);
        _deocderSession = NULL;
    }
}

#pragma mark - 解码

- (void)decodeAVCFrame:(ACVideoAVCFrame *)frame {
    if (frame.isKeyFrame && frame.sps && frame.pps) {
        // AVC Sequence Header
        const Byte* const parameterSetPointers[2] = { frame.sps.bytes, frame.pps.bytes };
        const size_t parameterSetSizes[2] = { frame.sps.length, frame.pps.length };
        OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                              2,
                                                                              parameterSetPointers,
                                                                              parameterSetSizes,
                                                                              4,
                                                                              &_decoderFormatDescription);
        NSLog(@"ACVideoDecoder:CMVideoFormatDescriptionCreateFromH264ParameterSets: %@", @(status));
        if (status == noErr) {
            [self start];
        }
        return;
    }
    
    // NALU
    __weak typeof(self) wself = self;
    dispatch_async(_queue, ^{
        [wself decodeNaluFrame:frame];
    });
}

- (CVPixelBufferRef)decodeNaluFrame:(ACVideoAVCFrame *)frame {
    CVPixelBufferRef outputPixelBuffer = NULL;

    Byte *naluData = (Byte*)frame.body.bytes;
    size_t naluSize = frame.body.length;
    CMBlockBufferRef blockBuffer = NULL;
    OSStatus status  = CMBlockBufferCreateWithMemoryBlock(NULL,
                                                          naluData,
                                                          naluSize,
                                                          kCFAllocatorNull,
                                                          NULL,
                                                          0,
                                                          naluSize,
                                                          FALSE,
                                                          &blockBuffer);
    if(status == kCMBlockBufferNoErr) {
        CMSampleBufferRef sampleBuffer = NULL;
        const size_t sampleSizeArray[] = {naluSize};
        status = CMSampleBufferCreateReady(kCFAllocatorDefault,
                                           blockBuffer,
                                           _decoderFormatDescription ,
                                           1, 0, NULL, 1, sampleSizeArray,
                                           &sampleBuffer);
        
        if (status == kCMBlockBufferNoErr && sampleBuffer) {
            VTDecodeFrameFlags flags = 0;
            VTDecodeInfoFlags flagOut = 0;
            status = VTDecompressionSessionDecodeFrame(_deocderSession,
                                                        sampleBuffer,
                                                        flags,
                                                        &outputPixelBuffer,
                                                        &flagOut);
            
            if (status != noErr) {
                NSLog(@"ACVideoDecoder:VTDecompressionSessionDecodeFrame: %@", @(status));
            }
            CFRelease(sampleBuffer);
        } else {
            NSLog(@"ACVideoDecoder:CMSampleBufferCreateReady: %@", @(status));
        }
        CFRelease(blockBuffer);
    } else {
        NSLog(@"ACVideoDecoder:CMBlockBufferCreateWithMemoryBlock: %@", @(status));
    }
    return outputPixelBuffer;
}

// 解码回调函数
static void didDecompress(void *decompressionOutputRefCon,
                          void *sourceFrameRefCon,
                          OSStatus status,
                          VTDecodeInfoFlags infoFlags,
                          CVImageBufferRef pixelBuffer,
                          CMTime presentationTimeStamp,
                          CMTime presentationDuration ) {
    CVPixelBufferRef *outputPixelBuffer = (CVPixelBufferRef *)sourceFrameRefCon;
    *outputPixelBuffer = CVPixelBufferRetain(pixelBuffer);
    ACVideoDecoder *decoder = (__bridge ACVideoDecoder *)decompressionOutputRefCon;
    if ([decoder.delegate respondsToSelector:@selector(videoDecoderOutputData:)]) {
        [decoder.delegate videoDecoderOutputData:pixelBuffer];
    }
}

@end
