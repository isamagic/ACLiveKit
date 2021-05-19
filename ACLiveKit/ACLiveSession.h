//
//  ACLiveSession.h
//  ACLivePlayer
//
//  Created by beichen on 2021/4/25.
//

#import <Foundation/Foundation.h>
#import "ACLiveAudioConfiguration.h"
#import "ACLiveVideoConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

/// 直播会话：录制 --> 编码 --> 推流
@interface ACLiveSession : NSObject

/// 初始化
/// @param audioConfiguration 音频配置
/// @param videoConfiguration 视频配置
/// @param url 推流地址
- (instancetype)initWithAudioConfiguration:(ACLiveAudioConfiguration *)audioConfiguration
                        videoConfiguration:(ACLiveVideoConfiguration *)videoConfiguration
                                       url:(NSString *)url;

/// 设置直播预览画面
/// @param preview 预览页
- (void)setLivePreview:(UIView *)preview;

/// 开始直播
- (void)startLive;

/// 结束直播
- (void)stopLive;

@end

NS_ASSUME_NONNULL_END
