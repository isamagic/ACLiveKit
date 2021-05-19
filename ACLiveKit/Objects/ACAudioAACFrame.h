//
//  ACAudioAACFrame.h
//  ACLivePlayer
//
//  Created by beichen on 2021/5/8.
//

#import <Foundation/Foundation.h>
#import "ACAVFrame.h"

NS_ASSUME_NONNULL_BEGIN

/// 音频压缩帧：AAC编码
@interface ACAudioAACFrame : ACAVFrame

// 是否为音频帧数据
@property (nonatomic, assign) BOOL isRawData;

@end

NS_ASSUME_NONNULL_END
