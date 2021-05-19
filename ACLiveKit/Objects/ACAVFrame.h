//
//  ACAVFrame.h
//  ACLivePlayer
//
//  Created by beichen on 2021/5/9.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 数据帧：抽象类
@interface ACAVFrame : NSObject

// 时间戳
@property (nonatomic, assign) uint64_t timestamp;

// 头部信息
@property (nonatomic, copy) NSData *header;

// 主体信息
@property (nonatomic, copy) NSData *body;

@end

NS_ASSUME_NONNULL_END
