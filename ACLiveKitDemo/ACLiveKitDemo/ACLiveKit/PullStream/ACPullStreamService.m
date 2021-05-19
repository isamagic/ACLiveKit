//
//  ACPullStreamService.m
//  ACLiveKitDemo
//
//  Created by beichen on 2021/5/10.
//

#import "ACPullStreamService.h"
#import "ACAudioFLVFrame.h"
#import "ACVideoFLVFrame.h"
#import "srs_librtmp.h"

@interface ACPullStreamService ()
{
    srs_rtmp_t rtmp; // RTMP实例
}

// 连接状态
@property (nonatomic, assign) BOOL connected;

// 拉流地址
@property (nonatomic, strong) NSString *url;

// 接收队列
@property (nonatomic, strong) dispatch_queue_t queue;

// 音频配置（拉流解析得到的）
@property (nonatomic, strong) ACLiveAudioConfiguration *audioConfig;

// 视频配置（拉流解析得到的）
@property (nonatomic, strong) ACLiveVideoConfiguration *videoConfig;

@end

@implementation ACPullStreamService

- (instancetype)initWithUrl:(NSString *)url {
    if (self = [super init]) {
        _audioConfig = [ACLiveAudioConfiguration defaultConfiguration];
        _videoConfig = [ACLiveVideoConfiguration defaultConfiguration];
        _queue = dispatch_queue_create("ACPullStreamService", NULL);
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
    self.connected = NO;
    srs_rtmp_destroy(rtmp);
    rtmp = NULL;
}

// 建立连接：TCP、握手、流通道
- (void)connect:(NSString *)url {
    rtmp = srs_rtmp_create([url cStringUsingEncoding:NSASCIIStringEncoding]);
    if (srs_rtmp_handshake(rtmp) != 0) {
        srs_human_trace("simple handshake failed");
        goto rtmp_destroy;
    }
    srs_human_trace("simple handshake success");
    
    if (srs_rtmp_connect_app(rtmp) != 0) {
        srs_human_trace("connect vhost/app failed");
        goto rtmp_destroy;
    }
    srs_human_trace("connect vhost/app success");
    
    if (srs_rtmp_play_stream(rtmp) != 0) {
        srs_human_trace("play stream failed");
        goto rtmp_destroy;
    }
    srs_human_trace("play stream success");
    
    // 超时设置：5秒
    srs_rtmp_set_timeout(rtmp, 5000, 5000);
    self.connected = YES;
    [self readFrame];
    return;
    
rtmp_destroy:
    srs_rtmp_destroy(rtmp);
}

// 重新连接
- (void)reconnect {
    [self stop];
    [self start];
}

// 拉流
- (void)readFrame {
    
    __weak typeof(self) wself = self;
    dispatch_async(self.queue, ^{
        if (!wself.connected){
            return;
        }
        
        int size;
        char type;
        char *data;
        uint32_t timestamp;
        
        // 拉流超时1011
        int status = srs_rtmp_read_packet(self->rtmp, &type, &timestamp, &data, &size);
        if (status == 0) {
            // Audio Tag（音频流）
            if (type == SRS_RTMP_TYPE_AUDIO) {
                // 解析：AAC Frame
                // 解码：PCM Frame
                // 播放：如何播放？Audio Queue Services
                NSData *audioData = [NSData dataWithBytes:data length:size];
                ACAudioFLVFrame *audioTag = [[ACAudioFLVFrame alloc] initWithData:audioData];
                ACAudioAACFrame *aacFrame = [audioTag aacFrame];
                aacFrame.timestamp = timestamp;
                if (aacFrame.isRawData && [wself.delegate respondsToSelector:@selector(pullStreamOutputAudioFrame:)]) {
                    [wself.delegate pullStreamOutputAudioFrame:aacFrame];
                }
            }
            
            // Video Tag（视频流）
            else if (type == SRS_RTMP_TYPE_VIDEO) {
                // 解析：AVC Frame
                // 解码：YUV Frame
                // 播放：如何播放？OpenGL
                NSData *videoData = [NSData dataWithBytes:data length:size];
                ACVideoFLVFrame *videoTag = [[ACVideoFLVFrame alloc] initWithData:videoData];
                ACVideoAVCFrame *avcFrame = [videoTag avcFrame];
                avcFrame.timestamp = timestamp;
                
                if ([wself.delegate respondsToSelector:@selector(pullStreamOutputVideoFrame:)]) {
                    [wself.delegate pullStreamOutputVideoFrame:avcFrame];
                }
            }
            
            // Script Tag（音视频元数据）
            else if (type == SRS_RTMP_TYPE_SCRIPT) {
                // 如何使用？
                // 如何实现音视频同步？
                if (srs_rtmp_is_onMetaData(type, data, size)) {
                    [self unpackMetaData:data size:size];
                }
            }
            free(data);
            [wself readFrame];
        }
        
        // ERROR_SOCKET_TIMEOUT
        else if (status == 1011) {
            [self reconnect];
        }
    });
}

// 解析获取音视频配置
- (void)unpackMetaData:(char *)data size:(int)size {
    
    int nameSize = 0;
    srs_amf0_parse(data, size, &nameSize); // onMetaData
    
    int valueSize = size - nameSize;
    char *metaData = (char*)malloc(valueSize);
    memcpy(metaData, data + nameSize, valueSize);
    srs_amf0_t amf0 = srs_amf0_parse(metaData, valueSize, &valueSize);
    
    int psize = 0;
    char *pdata = NULL;
    srs_human_amf0_print(amf0, &pdata, &psize);
    srs_human_trace("%s", pdata);
    
    // Audio Config
    self.audioConfig.audioBitrate = srs_amf0_to_number(srs_amf0_object_property(amf0, "audiodatarate")) * 1000;
    self.audioConfig.audioSampleRate = srs_amf0_to_number(srs_amf0_object_property(amf0, "audiosamplerate"));
    self.audioConfig.audioSampleSize = srs_amf0_to_number(srs_amf0_object_property(amf0, "audiosamplesize"));
    self.audioConfig.numberOfChannels = srs_amf0_to_number(srs_amf0_object_property(amf0, "stereo")) + 1;
    
    // Video Config
    self.videoConfig.videoBitRate = srs_amf0_to_number(srs_amf0_object_property(amf0, "videodatarate")) * 1000;
    self.videoConfig.videoFrameRate = srs_amf0_to_number(srs_amf0_object_property(amf0, "framerate"));
    NSInteger height = srs_amf0_to_number(srs_amf0_object_property(amf0, "height"));
    NSInteger width = srs_amf0_to_number(srs_amf0_object_property(amf0, "width"));
    self.videoConfig.videoSize = CGSizeMake(width, height);
}

@end
