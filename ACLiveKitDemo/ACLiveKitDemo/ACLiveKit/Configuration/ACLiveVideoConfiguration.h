//
//  ACLiveVideoConfiguration.h
//  ACLiveKitDemo
//
//  Created by beichen on 2021/5/18.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

/// 视频帧率
typedef NS_ENUM (NSUInteger, ACLiveVideoFrameRate){
    ACLiveVideoFrameRate15 = 15,
    ACLiveVideoFrameRate24 = 24,
    ACLiveVideoFrameRate30 = 30,
    ACLiveVideoFrameRateDefault = ACLiveVideoFrameRate15
};

/// 视频码率
typedef NS_ENUM (NSUInteger, ACLiveVideoBitRate){
    ACLiveVideoBitRate300   = 300 *  1000,  // 300kbps
    ACLiveVideoBitRate600   = 600 *  1000,  // 600kbps
    ACLiveVideoBitRate800   = 800 *  1000,  // 800kbps
    ACLiveVideoBitRate1000  = 1000 * 1000,  // 1000kbps
    ACLiveVideoBitRate1200  = 1200 * 1000,  // 1200kbps
    ACLiveVideoBitRateDefault = ACLiveVideoBitRate300
};

@interface ACLiveVideoConfiguration : NSObject

/// 默认视频配置
+ (instancetype)defaultConfiguration;

#pragma mark - Attribute

/// 视频分辨率
@property (nonatomic, assign) CGSize videoSize;

/// 视频输出方向
@property (nonatomic, assign) UIInterfaceOrientation outputImageOrientation;

/// 视频分辨率
@property (nonatomic, strong) AVCaptureSessionPreset avSessionPreset;

/// 视频的帧率，即 fps
@property (nonatomic, assign) ACLiveVideoFrameRate videoFrameRate;

/// 视频的码率，单位是 bps
@property (nonatomic, assign) ACLiveVideoBitRate videoBitRate;

/// 最大关键帧间隔，可设定为 fps 的2倍，影响一个 gop 的大小
@property (nonatomic, assign) NSUInteger videoMaxKeyframeInterval;

@end
