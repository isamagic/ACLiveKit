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
	# To integrate LFLiveKit into your Xcode project using CocoaPods, specify it in your Podfile:

	source 'https://github.com/CocoaPods/Specs.git'
	platform :ios, '7.0'
	pod 'LFLiveKit'
	
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
- (LFLiveSession*)session {
	if (!_session) {
	    _session = [[LFLiveSession alloc] initWithAudioConfiguration:[LFLiveAudioConfiguration defaultConfiguration] videoConfiguration:[LFLiveVideoConfiguration defaultConfiguration]];
	    _session.preView = self;
	    _session.delegate = self;
	}
	return _session;
}

- (void)startLive {	
	LFLiveStreamInfo *streamInfo = [LFLiveStreamInfo new];
	streamInfo.url = @"your server rtmp url";
	[self.session startLive:streamInfo];
}

- (void)stopLive {
	[self.session stopLive];
}

//MARK: - CallBack:
- (void)liveSession:(nullable LFLiveSession *)session liveStateDidChange: (LFLiveState)state;
- (void)liveSession:(nullable LFLiveSession *)session debugInfo:(nullable LFLiveDebug*)debugInfo;
- (void)liveSession:(nullable LFLiveSession*)session errorCode:(LFLiveSocketErrorCode)errorCode;
```
#### Swift
```swift
// import LFLiveKit in [ProjectName]-Bridging-Header.h
#import <LFLiveKit.h> 

//MARK: - Getters and Setters
lazy var session: LFLiveSession = {
	let audioConfiguration = LFLiveAudioConfiguration.defaultConfiguration()
	let videoConfiguration = LFLiveVideoConfiguration.defaultConfigurationForQuality(LFLiveVideoQuality.Low3, landscape: false)
	let session = LFLiveSession(audioConfiguration: audioConfiguration, videoConfiguration: videoConfiguration)
	    
	session?.delegate = self
	session?.preView = self.view
	return session!
}()

//MARK: - Event
func startLive() -> Void { 
	let stream = LFLiveStreamInfo()
	stream.url = "your server rtmp url";
	session.startLive(stream)
}

func stopLive() -> Void {
	session.stopLive()
}

//MARK: - Callback
func liveSession(session: LFLiveSession?, debugInfo: LFLiveDebug?) 
func liveSession(session: LFLiveSession?, errorCode: LFLiveSocketErrorCode)
func liveSession(session: LFLiveSession?, liveStateDidChange state: LFLiveState)
```

## Release History
    * 2.0.0
        * CHANGE: modify bugs,support ios7 live.
    * 2.2.4.3
        * CHANGE: modify bugs,support swift import.
    * 2.5 
        * CHANGE: modify bugs,support bitcode.


## License
 **LFLiveKit is released under the MIT license. See LICENSE for details.**
