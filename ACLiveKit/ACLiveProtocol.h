//
//  ACLiveProtocol.h
//  ACLivePlayer
//
//  Created by beichen on 2021/5/18.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 直播协议：录制/播放、编码/解码、推流/拉流
@protocol ACLiveProtocol <NSObject>

// 开始
- (void)start;

// 结束
- (void)stop;

@end

NS_ASSUME_NONNULL_END
