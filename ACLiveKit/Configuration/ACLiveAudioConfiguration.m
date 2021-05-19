//
//  ACLiveAudioConfiguration.m
//  ACLivePlayer
//
//  Created by beichen on 2021/5/18.
//

#import "ACLiveAudioConfiguration.h"
#import <sys/utsname.h>

@implementation ACLiveAudioConfiguration

#pragma mark -- LifyCycle

+ (instancetype)defaultConfiguration {
    ACLiveAudioConfiguration *audioConfig = [ACLiveAudioConfiguration new];
    audioConfig.audioBitrate = ACLiveAudioBitRateDefault;
    audioConfig.audioSampleRate = ACLiveAudioSampleRateDefault;
    audioConfig.numberOfChannels = 2;
    audioConfig.audioSampleSize = 16;
    return audioConfig;
}

- (instancetype)init {
    if (self = [super init]) {
        _asc = malloc(2);
    }
    return self;
}

- (void)dealloc {
    if (_asc) free(_asc);
}

#pragma mark - Setter

- (void)setAudioSampleRate:(ACLiveAudioSampleRate)audioSampleRate {
    _audioSampleRate = audioSampleRate;
    NSInteger sampleRateIndex = [self sampleRateIndex:audioSampleRate];
    self.asc[0] = 0x10 | ((sampleRateIndex>>1) & 0x7);
    self.asc[1] = ((sampleRateIndex & 0x1)<<7) | ((self.numberOfChannels & 0xF) << 3);
}

- (void)setNumberOfChannels:(NSUInteger)numberOfChannels {
    _numberOfChannels = numberOfChannels;
    NSInteger sampleRateIndex = [self sampleRateIndex:self.audioSampleRate];
    self.asc[0] = 0x10 | ((sampleRateIndex>>1) & 0x7);
    self.asc[1] = ((sampleRateIndex & 0x1)<<7) | ((numberOfChannels & 0xF) << 3);
}

- (NSUInteger)bufferLength {
    return 1024*2*self.numberOfChannels; // 4KB
}

- (NSInteger)sampleRateIndex:(ACLiveAudioSampleRate)sampleRate {
    NSInteger sampleRateIndex = 0;
    switch (sampleRate) {
        case ACLiveAudioSampleRate48:
            sampleRateIndex = 3;
            break;
        case ACLiveAudioSampleRate44:
            sampleRateIndex = 4;
            break;
        case ACLiveAudioSampleRate16:
            sampleRateIndex = 8;
            break;
    }
    return sampleRateIndex;
}

@end
