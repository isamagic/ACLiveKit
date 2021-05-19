//
//  ACPlaySession.m
//  ACLiveKitDemo
//
//  Created by beichen on 2021/5/15.
//

#import "ACPlaySession.h"
#import "ACPullStreamService.h"
#import "ACAudioDecoder.h"
#import "ACVideoDecoder.h"
#import "ACAudioPlayer.h"
#import "ACVideoPlayer.h"

@interface ACPlaySession () <   ACPullStreamServiceDelegate,
                                ACAudioDecoderDelegate,
                                ACVideoDecoderDelegate>

// 播放地址
@property (nonatomic, strong) NSString *url;

// 播放页面
@property (nonatomic, strong) UIView *playView;

// 拉流服务
@property (nonatomic, strong) ACPullStreamService *pullService;

// 音频解码器
@property (nonatomic, strong) ACAudioDecoder *audioDecoder;

// 视频解码器
@property (nonatomic, strong) ACVideoDecoder *videoDecoder;

// 音频播放器
@property (nonatomic, strong) ACAudioPlayer *audioPlayer;

// 视频播放器
@property (nonatomic, strong) ACVideoPlayer *videoPlayer;

@end

@implementation ACPlaySession

#pragma mark - Lifecycle

/// 初始化
/// @param url 播放地址
/// @param playView 播放画面
- (instancetype)initWithUrl:(NSString *)url playView:(UIView *)playView {
    if (self = [super init]) {
        [self loadNotification];
        _playView = playView;
        _url = url;
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [UIApplication sharedApplication].idleTimerDisabled = NO;
}

#pragma mark - 拉流

// 开始播放
- (void)startPlay {
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    [self.pullService start];
}

// 结束播放
- (void)stopPlay {
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [self.pullService stop];
}

#pragma mark - 解码

// 拉取的音频帧
- (void)pullStreamOutputAudioFrame:(ACAudioAACFrame *)aacFrame {
    [self.audioDecoder decodeAACFrame:aacFrame];
}

// 拉取的视频帧
- (void)pullStreamOutputVideoFrame:(ACVideoAVCFrame *)avcFrame {
    [self.videoDecoder decodeAVCFrame:avcFrame];
}

#pragma mark - 播放

// 音频解码回调
- (void)audioDecoderOutputData:(NSData *)data {
    [self.audioPlayer playPcmData:data];
}

// 视频解码回调
- (void)videoDecoderOutputData:(CVPixelBufferRef)pixelBuffer {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.videoPlayer displayPixelBuffer:pixelBuffer];
    });
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
    [self.videoDecoder stop];
    [self.audioPlayer stop];
    [self.pullService stop];
}

// 进入前台
- (void)willEnterForeground:(NSNotification*)notification {
    [UIApplication sharedApplication].idleTimerDisabled = YES; // 屏幕常亮
    [self.videoDecoder start];
    [self.audioPlayer start];
    [self.pullService start];
}

#pragma mark - Getters

- (ACPullStreamService *)pullService {
    if (!_pullService) {
        _pullService = [[ACPullStreamService alloc] initWithUrl:self.url];
        _pullService.delegate = self;
    }
    return _pullService;
}

- (ACAudioDecoder *)audioDecoder {
    if (!_audioDecoder) {
        _audioDecoder = [[ACAudioDecoder alloc] initWithConfig:_pullService.audioConfig];
        _audioDecoder.delegate = self;
    }
    return _audioDecoder;
}

- (ACVideoDecoder *)videoDecoder {
    if (!_videoDecoder) {
        _videoDecoder = [[ACVideoDecoder alloc] init];
        _videoDecoder.delegate = self;
    }
    return _videoDecoder;
}

- (ACAudioPlayer *)audioPlayer {
    if (!_audioPlayer) {
        _audioPlayer = [[ACAudioPlayer alloc] initWithConfig:_pullService.audioConfig];
    }
    return _audioPlayer;
}

- (ACVideoPlayer *)videoPlayer {
    if (!_videoPlayer) {
        _videoPlayer = [[ACVideoPlayer alloc] initWithFrame:self.playView.bounds];
        _videoPlayer.backgroundColor = self.playView.backgroundColor.CGColor;
        [self.playView.layer insertSublayer:_videoPlayer atIndex:0];
    }
    return _videoPlayer;
}

@end
