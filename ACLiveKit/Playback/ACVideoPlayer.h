//
//  ACVideoPlayer.h
//  ACLivePlayer
//
//  Created by beichen on 2021/5/15.
//

#import <UIKit/UIKit.h>
#import <CoreVideo/CoreVideo.h>
#import "ACVideoYuvFrame.h"

NS_ASSUME_NONNULL_BEGIN

/// 视频播放器
@interface ACVideoPlayer : NSObject

/// 初始化
/// @param playView 播放容器
- (instancetype)initWithView:(UIView *)playView;

/// 显示图像
/// @param pixelBuffer 图像数据
- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer;

/// 渲染YUV图像
/// @param yuvFrame YUV数据
- (void)displayYuvFrame:(ACVideoYuvFrame*)yuvFrame;

@end

NS_ASSUME_NONNULL_END
