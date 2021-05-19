//
//  ACLiveSession.m
//  ACLivePlayer
//
//  Created by beichen on 2021/4/25.
//

#import "ACLiveSession.h"
#import "ACAudioRecorder.h"
#import "ACVideoRecorder.h"
#import "ACAudioEncoder.h"
#import "ACVideoEncoder.h"
#import "ACPushStreamService.h"

// 当前时间戳
#define NOW (CACurrentMediaTime() * 1000)

@interface ACLiveSession () <ACAudioRecorderDelegate,
                             ACVideoRecorderDelegate,
                             ACAudioEncodingDelegate,
                             ACVideoEncodingDelegate,
                             ACPushStreamServiceDelegate>

/// 音频采集
@property (nonatomic, strong) ACAudioRecorder *audioRecorder;
/// 视频采集
@property (nonatomic, strong) ACVideoRecorder *videoRecorder;

/// 音频编码
@property (nonatomic, strong) ACAudioEncoder *audioEncoder;
/// 视频编码
@property (nonatomic, strong) ACVideoEncoder *videoEncoder;

/// 推流服务
@property (nonatomic, strong) ACPushStreamService *pushService;

/// 音频配置
@property (nonatomic, strong) ACLiveAudioConfiguration *audioConfiguration;
/// 视频配置
@property (nonatomic, strong) ACLiveVideoConfiguration *videoConfiguration;

/// 推流地址
@property (nonatomic, strong) NSString *url;
/// 是否开始推流
@property (nonatomic, assign) BOOL uploading;
/// 时间戳锁
@property (nonatomic, strong) dispatch_semaphore_t lock;
/// 上传相对时间戳
@property (nonatomic, assign) uint64_t relativeTimestamps;
/// 音视频是否同步
@property (nonatomic, assign) BOOL AVAlignment;
/// 当前是否采集到了音频
@property (nonatomic, assign) BOOL hasCaptureAudio;
/// 当前是否采集到了关键帧
@property (nonatomic, assign) BOOL hasKeyFrameVideo;

@end

@implementation ACLiveSession

/// 初始化
/// @param audioConfiguration 音频配置
/// @param videoConfiguration 视频配置
- (instancetype)initWithAudioConfiguration:(ACLiveAudioConfiguration *)audioConfiguration
                        videoConfiguration:(ACLiveVideoConfiguration *)videoConfiguration
                                       url:(NSString *)url {
    
    if (self = [super init]) {
        _audioConfiguration = audioConfiguration;
        _videoConfiguration = videoConfiguration;
        _lock = dispatch_semaphore_create(1);
        _url = url;
        
        [self requestAccessForVideo];
        [self requestAccessForAudio];
        [self loadNotification];
    }
    return self;
}

/// 设置直播预览画面
/// @param preview 预览页
- (void)setLivePreview:(UIView *)preview {
    [self.videoRecorder setPreview:preview];
}

/// 开始直播
- (void)startLive {
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    [self.pushService start];
}

/// 结束直播
- (void)stopLive {
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [self.audioRecorder stop];
    [self.videoRecorder stop];
    [self.pushService stop];
    self.uploading = NO;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [UIApplication sharedApplication].idleTimerDisabled = NO;
}

#pragma mark - 通知

- (void)loadNotification {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(willEnterBackground:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(willEnterForeground:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
}

// 退入后台
- (void)willEnterBackground:(NSNotification*)notification {
    [UIApplication sharedApplication].idleTimerDisabled = NO; // 自动息屏
    [self.audioRecorder stop];
    [self.videoRecorder stop];
    [self.videoEncoder stop];
    [self.pushService stop];
    
    // 忽略该信号，避免闪退
    signal(SIGPIPE, SIG_IGN);
}

// 进入前台
- (void)willEnterForeground:(NSNotification*)notification {
    [UIApplication sharedApplication].idleTimerDisabled = YES; // 屏幕常亮
    [self.audioRecorder start];
    [self.videoRecorder start];
    [self.videoEncoder start];
    [self.pushService start];
}

#pragma mark - 权限

- (void)requestAccessForVideo {
    __weak typeof(self) weakSelf = self;
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    switch (status) {
    case AVAuthorizationStatusNotDetermined: {
        // 许可对话没有出现，发起授权许可
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            if (granted) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf startCapture];
                });
            }
        }];
        break;
    }
    case AVAuthorizationStatusAuthorized: {
        // 已经开启授权，可继续
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf startCapture];
        });
        break;
    }
    case AVAuthorizationStatusDenied:
    case AVAuthorizationStatusRestricted:
        // 用户明确地拒绝授权，或者相机设备无法访问
        break;
    default:
        break;
    }
}

- (void)requestAccessForAudio {
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    switch (status) {
    case AVAuthorizationStatusNotDetermined: {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
            }];
        break;
    }
    case AVAuthorizationStatusAuthorized: {
        break;
    }
    case AVAuthorizationStatusDenied:
    case AVAuthorizationStatusRestricted:
        break;
    default:
        break;
    }
}

#pragma mark - 录制

// 开始录制
- (void)startCapture {
    [self.audioRecorder start];
    [self.videoRecorder start];
}

/// 输出音频数据
/// @param pcmData 音频帧
- (void)recordOutputAudioData:(NSData *)pcmData {
    if (self.uploading) {
        [self.audioEncoder encodeAudioData:pcmData timestamp:NOW];
    }
}

/// 输出视频数据
/// @param yuvData 视频帧
- (void)recordOutputVideoData:(CVPixelBufferRef)yuvData {
    if (self.uploading) {
        [self.videoEncoder encodeVideoData:yuvData timestamp:NOW];
    }
}

#pragma mark - 编码

- (void)audioEncodeOutputAACFrame:(ACAudioAACFrame *)aacFrame {
    if (self.uploading){
        self.hasCaptureAudio = YES;
        
        // 时间戳对齐
        if (self.AVAlignment) {
            [self pushSendFrame:aacFrame];
        }
    }
}

- (void)videoEncodeOutputAVCFrame:(ACVideoAVCFrame *)avcFrame {
    if (self.uploading) {
        if (avcFrame.isKeyFrame && self.hasCaptureAudio) {
            self.hasKeyFrameVideo = YES;
        }
        
        // 时间戳对齐
        if (self.AVAlignment) {
            [self pushSendFrame:avcFrame];
        }
    }
}

#pragma mark - 推流

- (void)pushSendFrame:(ACAVFrame *)frame{
    if(self.relativeTimestamps == 0){
        self.relativeTimestamps = frame.timestamp;
    }
    frame.timestamp = [self uploadTimestamp:frame.timestamp];
    [self.pushService sendFrame:frame];
}

- (uint64_t)uploadTimestamp:(uint64_t)captureTimestamp{
    dispatch_semaphore_wait(self.lock, DISPATCH_TIME_FOREVER);
    uint64_t currentts = 0;
    currentts = captureTimestamp - self.relativeTimestamps;
    dispatch_semaphore_signal(self.lock);
    return currentts;
}

// 推流状态
- (void)pushStreamServiceStatus:(ACLiveState)status {
    if (status == ACLiveStateStart) {
        self.uploading = YES;
        self.AVAlignment = NO;
        self.hasCaptureAudio = NO;
        self.hasKeyFrameVideo = NO;
        self.relativeTimestamps = 0;
    } else {
        self.uploading = NO;
    }
}

#pragma mark - Getter

- (ACAudioRecorder *)audioRecorder {
    if (!_audioRecorder) {
        _audioRecorder = [[ACAudioRecorder alloc] initWithAudioConfiguration:_audioConfiguration];
        _audioRecorder.delegate = self;
    }
    return _audioRecorder;
}

- (ACVideoRecorder *)videoRecorder {
    if (!_videoRecorder) {
        _videoRecorder = [[ACVideoRecorder alloc] initWithVideoConfiguration:_videoConfiguration];
        _videoRecorder.delegate = self;
    }
    return _videoRecorder;
}

- (ACAudioEncoder *)audioEncoder {
    if (!_audioEncoder) {
        _audioEncoder = [[ACAudioEncoder alloc] initWithAudioStreamConfiguration:_audioConfiguration];
        _audioEncoder.delegate = self;
    }
    return _audioEncoder;
}

- (ACVideoEncoder *)videoEncoder {
    if (!_videoEncoder) {
        _videoEncoder = [[ACVideoEncoder alloc] initWithVideoStreamConfiguration:_videoConfiguration];
        _videoEncoder.delegate = self;
    }
    return _videoEncoder;
}

- (ACPushStreamService *)pushService {
    if (!_pushService) {
        _pushService = [[ACPushStreamService alloc] initWithUrl:_url];
        _pushService.audioConfig = self.audioConfiguration;
        _pushService.videoConfig = self.videoConfiguration;
        _pushService.delegate = self;
    }
    return _pushService;
}

// 音视频同步
- (BOOL)AVAlignment {
    if (self.hasCaptureAudio && self.hasKeyFrameVideo) {
        return YES;
    }
    return NO;
}

@end
