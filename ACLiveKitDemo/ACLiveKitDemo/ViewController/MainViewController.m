//
//  ViewController.m
//  ACLiveKitDemo
//
//  Created by beichen on 2021/1/27.
//

#import "MainViewController.h"
#import "RecordViewController.h"
#import "PlayerViewController.h"

@interface MainViewController ()

@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    UIButton *recordBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 60, 40)];
    recordBtn.center = CGPointMake(self.view.center.x, self.view.center.y - 40);
    [recordBtn setTitle:@"录制" forState:UIControlStateNormal];
    [recordBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [recordBtn addTarget:self action:@selector(recordAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:recordBtn];
    
    UIButton *playBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 60, 40)];
    playBtn.center = CGPointMake(self.view.center.x, self.view.center.y + 40);
    [playBtn setTitle:@"播放" forState:UIControlStateNormal];
    [playBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [playBtn addTarget:self action:@selector(playAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:playBtn];
}

- (void)recordAction:(id)sender {
    RecordViewController *destVC = [RecordViewController new];
    destVC.modalPresentationStyle = UIModalPresentationFullScreen;
    destVC.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    [self presentViewController:destVC animated:YES completion:nil];
}

- (void)playAction:(id)sender {
    PlayerViewController *destVC = [PlayerViewController new];
    destVC.modalPresentationStyle = UIModalPresentationFullScreen;
    destVC.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    [self presentViewController:destVC animated:YES completion:nil];
}

@end
