//
//  ACVideoDecoder.h
//  ACLivePlayer
//
//  Created by beichen on 2021/5/14.
//

#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import "ACVideoAVCFrame.h"
#import "ACLiveProtocol.h"

NS_ASSUME_NONNULL_BEGIN

// 视频解码回调
@protocol ACVideoDecoderDelegate <NSObject>

// 解码数据
- (void)videoDecoderOutputData:(CVPixelBufferRef)pixelBuffer;

@end

// 视频解码器：基于VideoToolbox
@interface ACVideoDecoder : NSObject <ACLiveProtocol>

// 解码回调
@property (nonatomic, weak) id<ACVideoDecoderDelegate> delegate;

// 解码
- (void)decodeAVCFrame:(ACVideoAVCFrame *)frame;

@end

NS_ASSUME_NONNULL_END
