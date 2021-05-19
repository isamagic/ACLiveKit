//
//  PlayerViewController.m
//  ACLiveKitDemo
//
//  Created by beichen on 2021/1/29.
//

#import "PlayerViewController.h"
#import "UIView+YYAdd.h"
#import "ACPlaySession.h"

@interface PlayerViewController ()

@property (nonatomic, strong) UIButton *playBtn;
@property (nonatomic, strong) ACPlaySession *playSession;

@end

@implementation PlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor lightGrayColor];
    
    // 播放
    UIButton *playBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 60, 40)];
    [playBtn setTitle:@"开始" forState:UIControlStateNormal];
    [playBtn setTitle:@"结束" forState:UIControlStateSelected];
    playBtn.backgroundColor = [UIColor colorWithWhite:1 alpha:0.5];
    [playBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [playBtn setTitleColor:[UIColor redColor] forState:UIControlStateSelected];
    [playBtn addTarget:self action:@selector(playAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:playBtn];
    self.playBtn = playBtn;
}

- (void)viewDidLayoutSubviews {
    self.playBtn.left = (self.view.width - self.playBtn.width) * 0.5;
    self.playBtn.top = self.view.height - self.view.safeAreaInsets.bottom - self.playBtn.height;
}

- (void)playAction:(UIButton*)sender {
    sender.selected = !sender.selected;
    if (sender.isSelected) {
        // 开始直播
        NSString *url = @"rtmp://1.15.224.237:1935/live/livestream";
        self.playSession = [[ACPlaySession alloc] initWithUrl:url playView:self.view];
        [self.playSession startPlay];
    } else {
        // 结束直播
        [self.playSession stopPlay];
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

@end
