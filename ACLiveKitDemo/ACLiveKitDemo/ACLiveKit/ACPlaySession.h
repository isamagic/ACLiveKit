//
//  ACPlaySession.h
//  ACLiveKitDemo
//
//  Created by beichen on 2021/5/15.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 播放会话：拉流 --> 解码 --> 播放
@interface ACPlaySession : NSObject

/// 初始化
/// @param url 播放地址
/// @param playView 播放页面
- (instancetype)initWithUrl:(NSString *)url playView:(UIView *)playView;

/// 开始播放
- (void)startPlay;

/// 结束播放
- (void)stopPlay;

@end

NS_ASSUME_NONNULL_END
