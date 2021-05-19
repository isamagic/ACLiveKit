//
//  ACPushStreamBuffer.h
//  ACLivePlayer
//
//  Created by beichen on 2021/5/9.
//

#import <Foundation/Foundation.h>
#import "ACAVFrame.h"

NS_ASSUME_NONNULL_BEGIN

@interface ACPushStreamBuffer : NSObject

/** current frame buffer */
@property (nonatomic, strong, readonly) NSMutableArray <ACAVFrame *> *list;

/** buffer count max size default 1000 */
@property (nonatomic, assign) NSUInteger maxCount;

/** count of drop frames in last time */
@property (nonatomic, assign) NSInteger lastDropFrames;

/** add frame to buffer */
- (void)appendObject:(ACAVFrame *)frame;

/** pop the first frome buffer */
- (ACAVFrame *)popFirstObject;

/** remove all objects from Buffer */
- (void)removeAllObject;

@end

NS_ASSUME_NONNULL_END
