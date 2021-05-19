//
//  ACVideoFLVFrame.m
//  ACLivePlayer
//
//  Created by beichen on 2021/5/8.
//

#import "ACVideoFLVFrame.h"

@implementation ACVideoFLVFrame

- (instancetype)initWithHeader:(ACVideoAVCFrame *)frame {
    if (self = [super init]) {
        [self packetVideoHeader:frame];
    }
    return self;
}

- (instancetype)initWithBody:(ACVideoAVCFrame *)frame {
    if (self = [super init]) {
        [self packetVideoBody:frame];
    }
    return self;
}

- (instancetype)initWithData:(NSData *)data {
    if (self = [super init]) {
        [self unpackVideoData:data];
    }
    return self;
}

- (void)unpackVideoData:(NSData *)data {
    NSInteger len = data.length;
    NSInteger headerLen = 5; // VideoTagHeader占用5个字节
    if (len > headerLen) {
        self.header = [data subdataWithRange:NSMakeRange(0, headerLen)];
        self.body = [data subdataWithRange:NSMakeRange(headerLen, len - headerLen)];
    }
}

// 获取解包帧
- (ACVideoAVCFrame *)avcFrame {
    ACVideoAVCFrame *avcFrame = [ACVideoAVCFrame new];
    
    // Video Tag Header
    NSInteger headerLength = self.header.length;
    Byte *header = (Byte*)malloc(headerLength);
    memcpy(header, self.header.bytes, headerLength);
    Byte frameType = header[0]; // 帧类型
    avcFrame.isKeyFrame = (frameType == 0x17);
    
    // Video Tag Body
    NSInteger bodyLength = self.body.length;
    Byte *body = (Byte*)malloc(bodyLength);
    memcpy(body, self.body.bytes, bodyLength);
    char packetType = header[1]; // 包类型
    if (packetType == 0x00) {
        // AVC Sequence Header
        
        int i = 6; // body[0-5]是其他信息
        int spsLen = body[i++] * 256;
        spsLen += body[i++];
        Byte *sps = (Byte*)malloc(spsLen);
        memcpy(sps, body + i, spsLen);
        i += spsLen;
        
        i++;
        int ppsLen = body[i++] * 256;
        ppsLen += body[i++];
        Byte *pps = (Byte*)malloc(ppsLen);
        memcpy(pps, body + i, ppsLen);
        i += ppsLen;
        
        avcFrame.sps = [NSData dataWithBytes:sps length:spsLen];
        avcFrame.pps = [NSData dataWithBytes:pps length:ppsLen];
        free(sps);
        free(pps);
        
    } else {
        // NALU
//        NSInteger packetLen = bodyLength - 4; // 前4个字节是NALU的长度
//        avcFrame.body = [NSData dataWithBytes:body+4 length:packetLen];
        
        avcFrame.body = [NSData dataWithBytes:body length:bodyLength];
    }
    
    free(header);
    free(body);
    
    return avcFrame;
}

- (void)packetVideoHeader:(ACVideoAVCFrame *)frame {
    // Video Tag Header
    NSInteger headerLength = 5; // 占用5个字节
    unsigned char *header = (unsigned char *)malloc(headerLength);
    memset(header, 0, headerLength);
    header[0] = 0x17;   // FrameType(1:avc key frame, 2:avc inter frame)
                        // CodecID(7:avc)
    header[1] = 0x00;   // AVCPacketType(0:AVC Sequence Header, 1:NALU)
    header[2] = 0x00;   // CompositionTime[0]
    header[3] = 0x00;   // CompositionTime[1]
    header[4] = 0x00;   // CompositionTime[2]
    
    // Video Tag Body(AVCDecoderConfigurationRecord)
    NSInteger i = 0;
    NSInteger bodyLength = 1024;
    unsigned char *body = (unsigned char *)malloc(bodyLength);
    memset(body, 0, bodyLength);
    
    const char *sps = frame.sps.bytes;
    const char *pps = frame.pps.bytes;
    NSInteger sps_len = frame.sps.length;
    NSInteger pps_len = frame.pps.length;
    
    body[i++] = 0x01;   // ConfigurationVersion
    body[i++] = sps[1]; // AVCProfileIndication
    body[i++] = sps[2]; // profile_compatibility
    body[i++] = sps[3]; // AVCLevelIndication
    body[i++] = 0xff;   // 低2位表示视频中NALU的长度

    // sps
    body[i++] = 0xe1; // 低4位表示SPS的个数
    body[i++] = (sps_len >> 8) & 0xff; // SPS的长度，高位字节
    body[i++] = sps_len & 0xff;        // SPS的长度，低位字节
    memcpy(&body[i], sps, sps_len);    // SPS数据
    i += sps_len;

    // pps
    body[i++] = 0x01; // PPS 的个数
    body[i++] = (pps_len >> 8) & 0xff; // PPS的长度，高位字节
    body[i++] = (pps_len) & 0xff;      // PPS的长度，低位字节
    memcpy(&body[i], pps, pps_len);    // PPS数据
    i += pps_len;
    bodyLength = i;
    
    self.header = [NSData dataWithBytes:header length:headerLength];
    self.body = [NSData dataWithBytes:body length:bodyLength];
    self.timestamp = 0;
    free(header);
    free(body);
}

- (void)packetVideoBody:(ACVideoAVCFrame *)frame {
    // Video Tag Header
    NSInteger headerLength = 5; // 占用5个字节
    unsigned char *header = (unsigned char *)malloc(headerLength);
    memset(header, 0, headerLength);
    header[0] = frame.isKeyFrame ? 0x17 : 0x27;   // FrameType(1:avc key frame, 2:avc inter frame) CodecID(7:avc)
    header[1] = 0x01;   // AVCPacketType(0:AVC Sequence Header, 1:NALU)
    header[2] = 0x00;   // CompositionTime[0]
    header[3] = 0x00;   // CompositionTime[1]
    header[4] = 0x00;   // CompositionTime[2]
    
    // Video Tag Body : NALU length + NALU body
    NSInteger i = 0;
    NSInteger bodyLength = frame.body.length + 4;
    unsigned char *body = (unsigned char *)malloc(bodyLength);
    memset(body, 0, bodyLength);
    body[i++] = (frame.body.length >> 24) & 0xff; // NALU的长度，占用4个字节
    body[i++] = (frame.body.length >> 16) & 0xff;
    body[i++] = (frame.body.length >>  8) & 0xff;
    body[i++] = (frame.body.length) & 0xff;
    memcpy(&body[i], frame.body.bytes, frame.body.length);
    
    self.header = [NSData dataWithBytes:header length:headerLength];
    self.body = [NSData dataWithBytes:body length:bodyLength];
    self.timestamp = frame.timestamp;
    free(header);
    free(body);
}

// 获取待发送的数据
- (NSData *)flvTagData {
    NSMutableData *data = [[NSMutableData alloc] init];
    [data appendData:self.header];
    [data appendData:self.body];
    return [data copy];
}

@end
