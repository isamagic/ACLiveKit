//
//  RecordViewController.m
//  ACLiveKitDemo
//
//  Created by beichen on 2021/1/29.
//

#import "RecordViewController.h"
#import "UIView+YYAdd.h"
#import "ACLiveSession.h"

@interface RecordViewController ()

@property (nonatomic, strong) UIButton *recordBtn;

@property (nonatomic, strong) ACLiveSession *session;

@end

@implementation RecordViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    // 预览
    self.view.backgroundColor = [UIColor whiteColor];
    
    // 录制
    UIButton *recordBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 60, 40)];
    [recordBtn setTitle:@"开始" forState:UIControlStateNormal];
    [recordBtn setTitle:@"结束" forState:UIControlStateSelected];
    recordBtn.backgroundColor = [UIColor colorWithWhite:1 alpha:0.5];
    [recordBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [recordBtn setTitleColor:[UIColor redColor] forState:UIControlStateSelected];
    [recordBtn addTarget:self action:@selector(recordAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:recordBtn];
    self.recordBtn = recordBtn;
    
    NSString *url = @"rtmp://1.15.224.237:1935/live/livestream";
    ACLiveAudioConfiguration *audioConfig = [ACLiveAudioConfiguration defaultConfiguration];
    ACLiveVideoConfiguration *videoConfig = [ACLiveVideoConfiguration defaultConfiguration];
    self.session = [[ACLiveSession alloc] initWithAudioConfiguration:audioConfig
                                                  videoConfiguration:videoConfig
                                                                 url:url];
    [self.session setLivePreview:self.view];
}

- (void)viewDidLayoutSubviews {
    self.recordBtn.left = (self.view.width - self.recordBtn.width) * 0.5;
    self.recordBtn.top = self.view.height - self.view.safeAreaInsets.bottom - self.recordBtn.height;
}

- (void)recordAction:(UIButton*)sender {
    sender.selected = !sender.selected;
    if (sender.isSelected) {
        // 开始直播
        [self.session startLive];
    } else {
        // 结束直播
        [self.session stopLive];
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

@end
