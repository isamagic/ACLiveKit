//
//  ACPushStreamService.m
//  ACLivePlayer
//
//  Created by beichen on 2021/5/8.
//

#import "ACPushStreamService.h"
#import "ACAudioFLVFrame.h"
#import "ACVideoFLVFrame.h"
#import "srs_librtmp.h"
#import "ACPushStreamBuffer.h"

@interface ACPushStreamService ()
{
    srs_rtmp_t rtmp; // RTMP实例
}

// 连接状态
@property (nonatomic, assign) BOOL connected;

// 发送状态
@property (atomic, assign) BOOL isSending;
@property (nonatomic, assign) BOOL sentMetaData;
@property (nonatomic, assign) BOOL sentAudioHeader;
@property (nonatomic, assign) BOOL sentVideoHeader;

// 推流地址
@property (nonatomic, strong) NSString *url;

// 发送线程
@property (nonatomic, strong) dispatch_queue_t queue;

// 发送缓冲区
@property (nonatomic, strong) ACPushStreamBuffer *buffer;

@end

@implementation ACPushStreamService

- (instancetype)initWithUrl:(NSString *)url {
    if (self = [super init]) {
        _queue = dispatch_queue_create("ACPushStreamService", NULL);
        _buffer = [[ACPushStreamBuffer alloc] init];
        _url = url;
    }
    return self;
}

// 开始
- (void)start {
    [self connect:self.url];
}

// 结束
- (void)stop {
    if ([self.delegate respondsToSelector:@selector(pushStreamServiceStatus:)]) {
        [self.delegate pushStreamServiceStatus:ACLiveStateStop];
    }
    
    // 重置状态
    self.isSending = NO;
    self.sentMetaData = NO;
    self.sentAudioHeader = NO;
    self.sentVideoHeader = NO;
    srs_rtmp_destroy(rtmp);
    rtmp = NULL;
}

// 建立连接：TCP、握手、流通道
- (void)connect:(NSString *)url {
    rtmp = srs_rtmp_create([url cStringUsingEncoding:NSASCIIStringEncoding]);
    if (srs_rtmp_handshake(rtmp) != 0) {
        srs_human_trace("simple handshake failed.");
        goto rtmp_destroy;
    }
    srs_human_trace("simple handshake success");
    
    if (srs_rtmp_connect_app(rtmp) != 0) {
        srs_human_trace("connect vhost/app failed.");
        goto rtmp_destroy;
    }
    srs_human_trace("connect vhost/app success");
    
    if (srs_rtmp_publish_stream(rtmp) != 0) {
        srs_human_trace("publish stream failed.");
        goto rtmp_destroy;
    }
    srs_human_trace("publish stream success");
    
    if ([self.delegate respondsToSelector:@selector(pushStreamServiceStatus:)]) {
        [self.delegate pushStreamServiceStatus:ACLiveStateStart];
    }
    
    _connected = YES;
    return;
    
rtmp_destroy:
    srs_rtmp_destroy(rtmp);
}

- (void)sendFrame:(ACAVFrame *)frame {
    if (!frame) {
        return;
    }
    [self.buffer appendObject:frame];
    
    if(!self.isSending){
        [self sendFrame];
    }
}

- (void)sendFrame {
    __weak typeof(self) wself = self;
     dispatch_async(self.queue, ^{
        if (!wself.isSending && wself.buffer.list.count > 0) {
            wself.isSending = YES;

            if (!wself.connected){
                wself.isSending = NO;
                return;
            }
            
            // 发送元数据
            if (!wself.sentMetaData) {
                wself.sentMetaData = YES;
                [wself sendMetaData];
            }

            // 发送音视频帧
            ACAVFrame *frame = [wself.buffer popFirstObject];
            if ([frame isKindOfClass:[ACVideoAVCFrame class]]) {
                [wself sendVideoFrame:(ACVideoAVCFrame *)frame];
            } else {
                [wself sendAudioFrame:(ACAudioAACFrame *)frame];
            }
        }
    });
}

// 发送元数据
// 参考：E.5 onMetaData
- (void)sendMetaData {
    
    srs_amf0_t amf_name = srs_amf0_create_string("onMetaData");
    srs_amf0_t amf_value = srs_amf0_create_object();
        
    // Audio
    srs_amf0_object_property_set(amf_value, "audiocodecid", srs_amf0_create_number(10)); // AAC
    srs_amf0_object_property_set(amf_value, "audiodatarate", srs_amf0_create_number(_audioConfig.audioBitrate/1000.f));
    srs_amf0_object_property_set(amf_value, "audiosamplerate", srs_amf0_create_number(_audioConfig.audioSampleRate));
    srs_amf0_object_property_set(amf_value, "audiosamplesize", srs_amf0_create_number(_audioConfig.audioSampleSize));
    srs_amf0_object_property_set(amf_value, "stereo", srs_amf0_create_number(_audioConfig.numberOfChannels == 2));
    
    // Video
    srs_amf0_object_property_set(amf_value, "videocodecid", srs_amf0_create_number(7)); // AVC(H264)
    srs_amf0_object_property_set(amf_value, "videodatarate", srs_amf0_create_number(_videoConfig.videoBitRate/1000.f));
    srs_amf0_object_property_set(amf_value, "framerate", srs_amf0_create_number(_videoConfig.videoFrameRate));
    srs_amf0_object_property_set(amf_value, "height", srs_amf0_create_number(_videoConfig.videoSize.height));
    srs_amf0_object_property_set(amf_value, "width", srs_amf0_create_number(_videoConfig.videoSize.width));
    
    // FLV
    srs_amf0_object_property_set(amf_value, "duration", srs_amf0_create_number(0));
    srs_amf0_object_property_set(amf_value, "filesize", srs_amf0_create_number(0));
    
    // 数据转换
    int size0 = srs_amf0_size(amf_name);
    int size1 = srs_amf0_size(amf_value);
    char *data0 = (char *)malloc(size0);
    char *data1 = (char *)malloc(size1);
    srs_amf0_serialize(amf_name, data0, size0);
    srs_amf0_serialize(amf_value, data1, size1);
    
    int totalSize = size0 + size1;
    char *metaData = (char *)malloc(totalSize);
    memcpy(metaData, data0, size0);
    memcpy(metaData+size0, data1, size1);
        
    int ret = srs_rtmp_write_packet(rtmp, SRS_RTMP_TYPE_SCRIPT, 0, metaData, totalSize);
    if (ret != 0) {
        srs_human_trace("send metaData failed");
        return;
    }
    srs_human_trace("send metaData success");
    srs_amf0_free(amf_name);
    srs_amf0_free(amf_value);
    free(data0);
    free(data1);
}

/// 发送音频数据
/// @param frame 音频帧
- (void)sendAudioFrame:(ACAudioAACFrame *)frame {
    ACAudioFLVFrame *tag = nil;
    if (!self.sentAudioHeader) {
        self.sentAudioHeader = YES;
        tag = [[ACAudioFLVFrame alloc] initWithHeader:frame];
    } else {
        tag = [[ACAudioFLVFrame alloc] initWithBody:frame];
    }
    [self sendAudioTag:tag];
}

- (void)sendAudioTag:(ACAudioFLVFrame *)audioTag {
    NSData *flvTagData = [audioTag flvTagData];
    int size = (int)flvTagData.length;
    char *data = (char *)malloc(size);
    memcpy(data, flvTagData.bytes, size);
    int ret = srs_rtmp_write_packet(rtmp, SRS_RTMP_TYPE_AUDIO, (uint32_t)audioTag.timestamp, data, size);
    if (ret != 0) {
        srs_human_trace("send audio tag failed : %d", ret);
    }
    
    // 继续发送下一帧
    self.isSending = NO;
    [self sendFrame];
}

/// 发送视频数据
/// @param frame 视频帧
- (void)sendVideoFrame:(ACVideoAVCFrame *)frame {
    ACVideoFLVFrame *tag = nil;
    if (!self.sentVideoHeader) {
        self.sentVideoHeader = YES;
        tag = [[ACVideoFLVFrame alloc] initWithHeader:frame];
    } else {
        tag = [[ACVideoFLVFrame alloc] initWithBody:frame];
    }
    [self sendVideoTag:tag];
}

- (void)sendVideoTag:(ACVideoFLVFrame *)videoTag {
    NSData *flvTagData = [videoTag flvTagData];
    int size = (int)flvTagData.length;
    char *data = (char *)malloc(size);
    memcpy(data, flvTagData.bytes, size);
    int ret = srs_rtmp_write_packet(rtmp, SRS_RTMP_TYPE_VIDEO, (uint32_t)videoTag.timestamp, data, size);
    if (ret != 0) {
        srs_human_trace("send video tag failed : %d", ret);
    }
    
    // 继续发送下一帧
    self.isSending = NO;
    [self sendFrame];
}

@end
