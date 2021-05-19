//
//  ACAudioFLVFrame.m
//  ACLivePlayer
//
//  Created by beichen on 2021/5/8.
//

#import "ACAudioFLVFrame.h"

@implementation ACAudioFLVFrame

- (instancetype)initWithHeader:(ACAudioAACFrame *)frame {
    if (self = [super init]) {
        [self packetAudioHeader:frame];
    }
    return self;
}

- (instancetype)initWithBody:(ACAudioAACFrame *)frame {
    if (self = [super init]) {
        [self packetAudioBody:frame];
    }
    return self;
}

// 解包
- (instancetype)initWithData:(NSData *)data {
    if (self = [super init]) {
        [self unpackAudioData:data];
    }
    return self;
}

- (void)packetAudioHeader:(ACAudioAACFrame *)frame {
    NSInteger length = 2; // AudioTagHeader占用2个字节
    unsigned char *header = (unsigned char *)malloc(length);
    memset(header, 0, length);

    header[0] = 0xAF; // AudioHeader:|SoundFormat(4) | SoundRate(2) |SoundSize(1)|SoundType(1)|
    header[1] = 0x00; // AACPacketType(0:AAC sequence header, 1:AAC raw)
    
    self.header = [NSData dataWithBytes:header length:length];
    self.body = frame.header;
    self.timestamp = 0;
    free(header);
}

- (void)packetAudioBody:(ACAudioAACFrame *)frame {
    NSInteger length = 2; // AudioTagHeader占用2个字节
    unsigned char *header = (unsigned char *)malloc(length);
    memset(header, 0, length);

    header[0] = 0xAF; // AudioHeader:|SoundFormat(4) | SoundRate(2) |SoundSize(1)|SoundType(1)|
    header[1] = 0x01; // AACPacketType(0:AAC sequence header, 1:AAC raw)
    
    self.header = [NSData dataWithBytes:header length:length];
    self.body = frame.body;
    self.timestamp = frame.timestamp;
    free(header);
}

- (void)unpackAudioData:(NSData *)data {
    NSInteger len = data.length;
    if (len > 2) {
        self.header = [data subdataWithRange:NSMakeRange(0, 2)];
        self.body = [data subdataWithRange:NSMakeRange(2, len - 2)];
    }
}

- (NSData *)flvTagData {
    NSMutableData *data = [[NSMutableData alloc] init];
    [data appendData:self.header];
    [data appendData:self.body];
    return [data copy];
}

// 获取解包帧
- (ACAudioAACFrame *)aacFrame {
    ACAudioAACFrame *frame = [[ACAudioAACFrame alloc] init];
    if (self.header.length > 1) {
        Byte *data = (Byte*)self.header.bytes;
        Byte type = data[1];
        if (type == 1) { // AAC raw data
            frame.isRawData = YES;
        }
    }
    frame.body = self.body;
    return frame;
}

@end
