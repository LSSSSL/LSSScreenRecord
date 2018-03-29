//
//  ViewController.m
//  LSSVideoRecord
//
//  Created by lss on 2017/3/15.
//  Copyright © 2017年 liuss. All rights reserved.
//

#import "ViewController.h"
#import "LSSVideoRecord.h"
#import <AVFoundation/AVFoundation.h>
@interface ViewController ()<UITableViewDelegate,UITableViewDataSource>
{
    BOOL isRecing;//正在录制中
    BOOL isPauseing;//正在暂停中
    LSSVideoRecord *record;
    
    UIButton * beginBtn;
    UIButton * pauseBtn;
    //为了效果所显示的
    NSTimer * recordTimer;
    int timeCount;
    UILabel * timelable;
    UITableView *aTableView;
    NSArray *dataArr;
    
    
}
//@property (strong,nonatomic)AVAudioPlayer * player;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    dataArr = @[@"1",@"请使劲拖动屏幕", @"3",@"以确定录制的是真的视频",@"5",@"视频最终将保存到相册中", @"1",@"2",@"3",@"4"];
    self.view.backgroundColor = [UIColor whiteColor];
    [self setUpNavi];
    [self setUpFunctionBtn];
    //[self createMusic];
     record = [[LSSVideoRecord alloc] init];
    
}
-(void)viewWillAppear:(BOOL)animated
{
    isRecing=NO;
    isPauseing=NO;
}

#pragma mark - 开始录制视频
-(void)beginToRecVideo
{
    if (isRecing) {
        return ;
    }
    isRecing =YES;
    [record startRecording];
    
    //[_player play];
    recordTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(recordTimerWork) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop]addTimer:recordTimer forMode:NSRunLoopCommonModes];
    
    beginBtn.userInteractionEnabled=NO;
    [beginBtn setBackgroundColor:[UIColor lightGrayColor]];
}
#pragma mark - 继续或者暂停录制
-(void)pauseVideo
{
    if (isRecing) {
        // [_player stop];
        //暂停
        isRecing=NO;
        isPauseing=YES;
        [record PauseRecording];
        [pauseBtn setTitle:@"继续录制" forState:UIControlStateNormal];
        
        if (recordTimer) {
            [recordTimer invalidate];
            recordTimer=nil;
        }
    }else if(isPauseing)
    {
        //[_player play];
        isRecing=YES;
        isPauseing=NO;
         [record PauseRecording];
        [pauseBtn setTitle:@"暂停" forState:UIControlStateNormal];
        
        recordTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(recordTimerWork) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop]addTimer:recordTimer forMode:NSRunLoopCommonModes];
        
    }
    
}
#pragma mark - 结束录制视频
-(void)stopAndSaveVideo
{
    // [_player stop];
    beginBtn.userInteractionEnabled=YES;
    [beginBtn setBackgroundColor:[UIColor orangeColor]];
    isRecing =NO;
    isPauseing=NO;
    [record stopRecording];
    
    timeCount =0;
    timelable.text =@"00:00:00";
    if (recordTimer) {
        [recordTimer invalidate];
        recordTimer=nil;
    }
    
}
#pragma mark===============以下是UI============================
#pragma mark- 功能按钮====================
-(void)setUpFunctionBtn
{
    timelable = [[UILabel alloc]initWithFrame:CGRectMake(0, 80, self.view.frame.size.width, 20)];
    timelable.textAlignment =NSTextAlignmentCenter;
    timelable.text = @"00:00:00";
    timelable.textColor=[UIColor redColor];
    [self.view addSubview:timelable];
    
    //开始按钮
    beginBtn =[UIButton buttonWithType:UIButtonTypeCustom];
    beginBtn.frame = CGRectMake(10, 120, (self.view.frame.size.width-40)/3, 30);
    [beginBtn setTitle:@"开始" forState:UIControlStateNormal];
    [beginBtn setBackgroundColor:[UIColor orangeColor]];
    [beginBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [beginBtn addTarget:self action:@selector(beginToRecVideo) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:beginBtn];
    
    //暂停按钮
    pauseBtn =[UIButton buttonWithType:UIButtonTypeCustom];
    pauseBtn.frame = CGRectMake(CGRectGetMaxX(beginBtn.frame)+10,120, (self.view.frame.size.width-40)/3, 30);
    [pauseBtn setTitle:@"暂停" forState:UIControlStateNormal];
    [pauseBtn setBackgroundColor:[UIColor orangeColor]];
    [pauseBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [pauseBtn addTarget:self action:@selector(pauseVideo) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:pauseBtn];
    
    //结束按钮
    UIButton * stopAndSaveBtn =[UIButton buttonWithType:UIButtonTypeCustom];
    stopAndSaveBtn.frame = CGRectMake(CGRectGetMaxX(pauseBtn.frame)+10, 120, (self.view.frame.size.width-40)/3, 30);
    [stopAndSaveBtn setTitle:@"结束并保存" forState:UIControlStateNormal];
    [stopAndSaveBtn setBackgroundColor:[UIColor orangeColor]];
    [stopAndSaveBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [stopAndSaveBtn addTarget:self action:@selector(stopAndSaveVideo) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:stopAndSaveBtn];
    
    aTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(stopAndSaveBtn.frame)+15, self.view.bounds.size.width, self.view.bounds.size.height-CGRectGetMaxY(stopAndSaveBtn.frame)-15) style:UITableViewStylePlain];
    aTableView.delegate = self;
    aTableView.dataSource = self;
    [self.view  addSubview:aTableView];

}

#pragma mark -音乐播放====================
-(void)createMusic{
    NSURL * url = [NSURL fileURLWithPath:[[NSBundle mainBundle]pathForResource:@"a" ofType:@"mp3"]];
    AVAudioPlayer * player = [[AVAudioPlayer alloc]initWithContentsOfURL:url error:nil];
    player.volume = 1.0;
    //self.player = player;
    [player prepareToPlay];
    
}

#pragma mark- 效果设置--------------------------------------------
-(void)setUpNavi
{
    self.navigationController.navigationBar.tintColor = [UIColor clearColor];
    self.navigationController.navigationBar.barTintColor=[UIColor orangeColor];
    self.navigationController.navigationBar.titleTextAttributes=@{NSForegroundColorAttributeName:[UIColor whiteColor],NSFontAttributeName:[UIFont boldSystemFontOfSize:18]};
    self.navigationItem.title=@"录制视频";
}
#pragma mark -视频录制时字体跟着变化
-(void)recordTimerWork
{
    timeCount++;
    NSString * timeStr =[self timeFormatted:timeCount];
    timelable.text =timeStr;
}

- (NSString *)timeFormatted:(int)totalSeconds
{
    
    int seconds = totalSeconds % 60;
    int minutes = (totalSeconds / 60) % 60;
    int hours = totalSeconds / 3600;
    
    return [NSString stringWithFormat:@"%02d:%02d:%02d",hours, minutes, seconds];
}
#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return dataArr.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    cell.backgroundColor =[UIColor colorWithRed:arc4random_uniform(255)/255.0 green:arc4random_uniform(255)/255.0 blue:arc4random_uniform(255)/255.0 alpha:1];
    cell.textLabel.text = dataArr[indexPath.row];
    
    return cell;
}


@end
