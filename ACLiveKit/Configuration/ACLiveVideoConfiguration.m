//
//  ACLiveVideoConfiguration.m
//  ACLivePlayer
//
//  Created by beichen on 2021/5/18.
//


#import "ACLiveVideoConfiguration.h"

@implementation ACLiveVideoConfiguration

+ (instancetype)defaultConfiguration {
    ACLiveVideoConfiguration *configuration = [ACLiveVideoConfiguration new];
    configuration.videoFrameRate = ACLiveVideoFrameRateDefault;
    configuration.videoBitRate = ACLiveVideoBitRateDefault;
    configuration.videoMaxKeyframeInterval = configuration.videoFrameRate * 2;
    configuration.outputImageOrientation = UIInterfaceOrientationPortrait;
    configuration.avSessionPreset = AVCaptureSessionPreset640x480;
    configuration.videoSize = CGSizeMake(480, 640);
    return configuration;
}

@end
