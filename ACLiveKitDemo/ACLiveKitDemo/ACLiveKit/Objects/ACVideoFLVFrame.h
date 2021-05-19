//
//  ACVideoFLVFrame.h
//  ACLiveKitDemo
//
//  Created by beichen on 2021/5/8.
//

#import <Foundation/Foundation.h>
#import "ACVideoAVCFrame.h"

NS_ASSUME_NONNULL_BEGIN

/// 视频传输帧：FLV封装
@interface ACVideoFLVFrame : ACAVFrame

// 封包
- (instancetype)initWithHeader:(ACVideoAVCFrame *)frame;
- (instancetype)initWithBody:(ACVideoAVCFrame *)frame;

// 解包
- (instancetype)initWithData:(NSData *)data;

// 获取待发送的数据
- (NSData *)flvTagData;

// 获取解包帧
- (ACVideoAVCFrame *)avcFrame;

@end

NS_ASSUME_NONNULL_END
