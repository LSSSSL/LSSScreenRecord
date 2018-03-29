//
//  LSSVideoRecord.h
//  LSSVideoRecord
//
//  Created by lss on 2017/3/15.
//  Copyright © 2017年 liuss. All rights reserved.
//

#import <Foundation/Foundation.h>
@interface LSSVideoRecord : NSObject
#pragma mark- 开始录制
- (void)startRecording;
#pragma mark-结束录制
- (void)stopRecording;
#pragma mark-暂停录制/继续录制
-(void)PauseRecording;
@end



