//
//  ACVideoAVCFrame.h
//  ACLivePlayer
//
//  Created by beichen on 2021/5/8.
//

#import <Foundation/Foundation.h>
#import "ACAVFrame.h"

NS_ASSUME_NONNULL_BEGIN

/// 视频压缩帧：AVC编码（H264）
@interface ACVideoAVCFrame : ACAVFrame

@property (nonatomic, assign) BOOL isKeyFrame;
@property (nonatomic, strong) NSData *sps;
@property (nonatomic, strong) NSData *pps;

@end

NS_ASSUME_NONNULL_END
