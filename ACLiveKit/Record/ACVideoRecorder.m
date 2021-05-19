//
//  ACVideoRecorder.m
//  ACLivePlayer
//
//  Created by beichen on 2021/5/16.
//

#import "ACVideoRecorder.h"

@interface ACVideoRecorder () <AVCaptureVideoDataOutputSampleBufferDelegate>

// 视频录制配置
@property (nonatomic, strong) ACLiveVideoConfiguration *videoConfiguration;

// 视频输入源
@property (nonatomic, strong) AVCaptureDeviceInput *videoInputDevice;

// 视频输出源
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;

// 视频预览
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

// 录制会话
@property (nonatomic, strong) AVCaptureSession *captureSession;

@end


@implementation ACVideoRecorder

/// 初始化
/// @param videoConfiguration 视频配置
- (instancetype)initWithVideoConfiguration:(ACLiveVideoConfiguration *)videoConfiguration {
    if (self = [super init]) {
        _videoConfiguration = videoConfiguration;
        [self createSession];
    }
    return self;
}

// 创建录制会话
- (void)createSession {
    // 摄像头（前置）
    AVCaptureDeviceType deviceType = AVCaptureDeviceTypeBuiltInWideAngleCamera;
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithDeviceType:deviceType
                                                                      mediaType:AVMediaTypeVideo
                                                                       position:AVCaptureDevicePositionFront];
    self.videoInputDevice = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:nil];
    
    // 创建录制输出
    dispatch_queue_t captureQueue = dispatch_queue_create("aw.capture.queue", DISPATCH_QUEUE_SERIAL);
    self.videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [self.videoDataOutput setSampleBufferDelegate:self queue:captureQueue];
    [self.videoDataOutput setVideoSettings:@{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey:
                                                 @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
                                             }];
    
    // 创建会话
    self.captureSession = [AVCaptureSession new];
    [self.captureSession beginConfiguration];
    if ([self.captureSession canAddInput:self.videoInputDevice]) {
        [self.captureSession addInput:self.videoInputDevice];
    }
    if([self.captureSession canAddOutput:self.videoDataOutput]){
        [self.captureSession addOutput:self.videoDataOutput];
        for (AVCaptureConnection *conn in self.videoDataOutput.connections) {
            if (conn.isVideoStabilizationSupported) {
                [conn setPreferredVideoStabilizationMode:AVCaptureVideoStabilizationModeAuto];
            }
            if (conn.isVideoOrientationSupported) {
                [conn setVideoOrientation:AVCaptureVideoOrientationPortrait];
            }
            if (conn.isVideoMirroringSupported) {
                [conn setVideoMirrored:YES]; // 前置摄像头录制的视频需要翻转
            }
        }
    }
    self.captureSession.sessionPreset = self.videoConfiguration.avSessionPreset;
    [self.captureSession commitConfiguration];
}

// 设置预览页
- (void)setPreview:(UIView *)preview {
    self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.previewLayer.frame = preview.bounds;
    [preview.layer insertSublayer:self.previewLayer atIndex:0];
}

// 开始录制
- (void)start {
    [self.captureSession startRunning];
}

// 停止录制
- (void)stop {
    [self.captureSession stopRunning];
}

#pragma mark - Callback

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    
    // 视频数据
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if ([self.delegate respondsToSelector:@selector(recordOutputVideoData:)]) {
        [self.delegate recordOutputVideoData:pixelBuffer];
    }
}

@end
