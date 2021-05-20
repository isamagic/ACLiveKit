# ACLiveKit
ACLiveKit is a opensource RTMP streaming SDK for iOS.

## Architecture
![arch](https://user-images.githubusercontent.com/3898299/118857064-35e5db80-b90a-11eb-9834-d4d2c46197cc.png)

## Features

- [x] Support recording and playback
- [x] Support H264+AAC Hardware Encoding and Decoding
- [x] Audio configuration
- [x] Video configuration
- [x] RTMP Transport
- [x] Support Send Buffer
- [x] Support both push and pull streaming 

## Requirements
    - iOS 10.0+
    - Xcode 12.4
  
## Installation

#### CocoaPods
	# To integrate ACLiveKit into your Xcode project using CocoaPods, specify it in your Podfile:

	source 'https://github.com/CocoaPods/Specs.git'
	platform :ios, '10.0'
	pod 'ACLiveKit'
	
	# Then, run the following command:
	$ pod install

#### Manually

    1. Download all the files in the `LFLiveKit` subdirectory.
    2. Add the source files to your Xcode project.
    3. Link with required frameworks:
        * UIKit
        * Foundation
        * AVFoundation
        * VideoToolbox
        * AudioToolbox
        * libz
        * libstdc++
	
## Usage example 

#### Objective-C
```objc
- (ACLiveSession *)session {
    if (!_session) {
        NSString *url = @"your server rtmp url";
        ACLiveAudioConfiguration *audioConfig = [ACLiveAudioConfiguration defaultConfiguration];
        ACLiveVideoConfiguration *videoConfig = [ACLiveVideoConfiguration defaultConfiguration];
        _session = [[ACLiveSession alloc] initWithAudioConfiguration:audioConfig
                                                  videoConfiguration:videoConfig
                                                                 url:url];
        [_session setLivePreview:self.view];
    }
    return _session;
}

- (void)startLive {	
	[self.session startLive];
}

- (void)stopLive {
	[self.session stopLive];
}

```


## Release History
    * 1.0
        * CHANGE: init project

## License
 **LFLiveKit is released under the MIT license. See LICENSE for details.**
