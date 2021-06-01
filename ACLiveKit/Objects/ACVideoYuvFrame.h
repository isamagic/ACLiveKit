//
//  ACVideoYuvFrame.h
//  ACLiveKitDemo
//
//  Created by beichen on 2021/6/1.
//

#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>

NS_ASSUME_NONNULL_BEGIN

// 封装CVPixelBufferRef数据
@interface ACVideoYuvFrame : NSObject

@property (nonatomic) CVPixelBufferRef pixelBuffer;

@end

NS_ASSUME_NONNULL_END
