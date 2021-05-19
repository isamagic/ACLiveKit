//
//  ACAudioFLVFrame.h
//  ACLiveKitDemo
//
//  Created by beichen on 2021/5/8.
//

#import <Foundation/Foundation.h>
#import "ACAudioAACFrame.h"

NS_ASSUME_NONNULL_BEGIN

/// 音频传输帧：FLV封装
@interface ACAudioFLVFrame : ACAVFrame

// 封包
- (instancetype)initWithHeader:(ACAudioAACFrame *)frame;
- (instancetype)initWithBody:(ACAudioAACFrame *)frame;

// 解包
- (instancetype)initWithData:(NSData *)data;

// 获取封包数据
- (NSData *)flvTagData;

// 获取解包帧
- (ACAudioAACFrame *)aacFrame;

@end

NS_ASSUME_NONNULL_END
