//
//  ACVideoPlayer.h
//  ACLiveKitDemo
//
//  Created by beichen on 2021/5/15.
//

#import <Foundation/Foundation.h>
#include <QuartzCore/QuartzCore.h>
#include <CoreVideo/CoreVideo.h>

NS_ASSUME_NONNULL_BEGIN

/// 视频播放器
@interface ACVideoPlayer : CAEAGLLayer

/// 初始化
/// @param frame 大小
- (instancetype)initWithFrame:(CGRect)frame;

/// 显示图像
/// @param pixelBuffer 图像数据
- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer;

@end

NS_ASSUME_NONNULL_END
