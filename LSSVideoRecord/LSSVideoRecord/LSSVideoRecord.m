//
//  LSSVideoRecord.m
//  LSSVideoRecord
//
//  Created by lss on 2017/3/15.
//  Copyright © 2017年 liuss. All rights reserved.
//

#import "LSSVideoRecord.h"
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark-视频的录制
@protocol LSSCaptureVideoDelegate <NSObject>
- (void)recordingFinished:(NSString*)outputPath;
- (void)recordingFaild:(NSError *)error;
@end

@interface LSSCaptureVideo : NSObject

@property(assign) NSUInteger frameRate;
@property(nonatomic, strong) id<LSSCaptureVideoDelegate> delegate;

//创建实例
+ (LSSCaptureVideo *)sharedRecorder;
//开始录制
- (bool)startRecording1;
//结束录制
- (void)stopRecording;
//暂停录制
-(void)pauseRecording;
//重新开始录制
-(void)resumeRecording;

@end

@interface  LSSCaptureVideo(){
    float spaceDate;//秒
    CALayer *captureLayer;
    BOOL recording;
    BOOL isPause;
    NSString *opPath;
    AVAssetWriter *videoWriter;
    AVAssetWriterInput *videoWriterInput;
    AVAssetWriterInputPixelBufferAdaptor *avAdaptor;
    BOOL writing;
    NSDate *startedAt;
    CGContextRef  context;
    NSTimer  *timer;
}
@end

@implementation LSSCaptureVideo
static LSSCaptureVideo *_screenRecorder;
+ (LSSCaptureVideo *)sharedRecorder{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _screenRecorder = [[self alloc] init];
        _screenRecorder.frameRate = 10;
        
    });
    return _screenRecorder;
}

- (id)init{
    self = [super init];
    if (self) {
        
        recording = NO;
        isPause = NO;
    }
    return self;
}

- (void)dealloc {
    [self cleanupWriter];
}

//开始录制
- (bool)startRecording1
{
    bool result = NO;
    if (! recording )
    {
        result = [self setUpWriter];
        if (result)
        {
            startedAt = [NSDate date];
            spaceDate=0;
            recording = true;
            writing = false;
            timer = [NSTimer scheduledTimerWithTimeInterval:1.0/self.frameRate target:self selector:@selector(drawFrame) userInfo:nil repeats:YES];
            [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
        }
    }
    return result;
}

//暂停录制
-(void)pauseRecording
{
    @synchronized(self) {
        if (recording) {
            isPause = YES;
            recording = NO;
        }
    }
}

//继续录制
-(void)resumeRecording
{
    @synchronized(self) {
        if (isPause) {
            recording = YES;
            isPause = NO;
        }
    }
}

//停止录制
- (void)stopRecording
{
    isPause = NO;
    recording = false;
    [timer invalidate];
    timer = nil;
    [self completeRecordingSession];
    [self cleanupWriter];
}

#pragma mark-buffer写入成视频的方法
-(void)writeVideoFrameAtTime:(CMTime)time addImage:(CGImageRef )newImage
{
    //视频输入是否准备接受更多的媒体数据
    if (![videoWriterInput isReadyForMoreMediaData]) {
       
    } else {
        
        @synchronized (self) {//创建一个互斥锁，保证此时没有其它线程对self对象进行修改
            
            CVPixelBufferRef pixelBuffer = NULL;
            CGImageRef cgImage = CGImageCreateCopy(newImage);
            CFDataRef image = CGDataProviderCopyData(CGImageGetDataProvider(cgImage));
            
            int status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, avAdaptor.pixelBufferPool, &pixelBuffer);
            if(status != 0){
                
            }
            // set image data into pixel buffer
            CVPixelBufferLockBaseAddress( pixelBuffer, 0 );
            uint8_t* destPixels = CVPixelBufferGetBaseAddress(pixelBuffer);
            CFDataGetBytes(image, CFRangeMake(0, CFDataGetLength(image)), destPixels);
            
            if(status == 0) {
                
                BOOL success = [avAdaptor appendPixelBuffer:pixelBuffer withPresentationTime:time];
                if (!success)
                    NSLog(@"Warning:  Unable to write buffer to video");
            }
            
            //clean up
            CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );
            CVPixelBufferRelease( pixelBuffer );
            CFRelease(image);
            CGImageRelease(cgImage);
        }
        
    }
}


- (void)drawFrame
{
    if (isPause) {
        //计算暂停的时间 并且在暂停的时候停止视频的写入
        spaceDate=spaceDate+1.0/self.frameRate;
        return;
    }
    if (!writing) {
        [self performSelectorInBackground:@selector(getFrame) withObject:nil];
    }
}
- (void)getFrame
{
    if (!writing) {
        writing = true;
        size_t width  = CGBitmapContextGetWidth(context);
        size_t height = CGBitmapContextGetHeight(context);
        @try {
            CGContextClearRect(context, CGRectMake(0, 0,width , height));
            [[[UIApplication sharedApplication].delegate window].layer renderInContext:context];
            [[UIApplication sharedApplication].delegate window].layer.contents = nil;
            CGImageRef cgImage = CGBitmapContextCreateImage(context);
            
            if (recording) {
                float millisElapsed = [[NSDate date] timeIntervalSinceDate:startedAt] * 1000.0-spaceDate*1000.0;
                [self writeVideoFrameAtTime:CMTimeMake((int)millisElapsed, 1000) addImage:cgImage];
            }
            CGImageRelease(cgImage);
        }
        @catch (NSException *exception) {
            
        }
        writing = false;
    }
}

#pragma mark- 视频的存放地址（最好是放在caches里面，我这是项目需要才写的）
- (NSString*)tempFilePath {
    
    NSFileManager * fileManager =[NSFileManager defaultManager];
    NSString *finalPath = [NSHomeDirectory() stringByAppendingPathComponent:@"/Documents/myVideo"];
    if (![fileManager fileExistsAtPath:finalPath]) {
        BOOL res=[fileManager createDirectoryAtPath:finalPath withIntermediateDirectories:YES attributes:nil error:nil];
        if (res) {
        }
    }
    
    NSTimeInterval time = [[NSDate date] timeIntervalSince1970];
    long long int date = (long long int)time;
    NSString *outputPath = [finalPath stringByAppendingPathComponent:
                            [NSString stringWithFormat:@"%lld.mp4",date]];
    [self removeTempFilePath:outputPath];
    return outputPath;
    
}

- (void)removeTempFilePath:(NSString*)filePath
{
    NSFileManager* fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:filePath]) {
        NSError* error;
        if ([fileManager removeItemAtPath:filePath error:&error] == NO) {
            NSLog(@"Could not delete old recording:%@", [error localizedDescription]);
        }
    }
}

#pragma mark- 初始化视频写入的类
-(BOOL) setUpWriter {
    [self is64bit];
    CGSize tmpsize = [UIScreen mainScreen].bounds.size;
    float scaleFactor = [[UIScreen mainScreen] scale];
    CGSize size = CGSizeMake(tmpsize.width*scaleFactor, tmpsize.height*scaleFactor);
    NSError *error = nil;
    NSString *filePath=[self tempFilePath];
    opPath = filePath;
    NSFileManager* fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:filePath]) {
        if ([fileManager removeItemAtPath:filePath error:&error] == NO) {
            return NO;
        }
    }
    //configure videoWriter
    NSURL *fileUrl = [NSURL fileURLWithPath:filePath];
    videoWriter = [[AVAssetWriter alloc] initWithURL:fileUrl fileType:AVFileTypeQuickTimeMovie error:&error];
    NSParameterAssert(videoWriter);
    
    //Configure videoWriterInput
    NSDictionary* videoCompressionProps = [NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithDouble:size.width*size.height], AVVideoAverageBitRateKey,//视频尺寸*比率，10.1相当于AVCaptureSessionPresetHigh，数值越大，显示越精细
                                           nil ];
    NSDictionary* videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   AVVideoCodecH264, AVVideoCodecKey,
                                   [NSNumber numberWithInt:size.width], AVVideoWidthKey,
                                   [NSNumber numberWithInt:size.height], AVVideoHeightKey,
                                   videoCompressionProps, AVVideoCompressionPropertiesKey,
                                   nil];
    videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    
    NSParameterAssert(videoWriterInput);
    videoWriterInput.expectsMediaDataInRealTime = YES;
    
    
    
    NSMutableDictionary* bufferAttributes = [[NSMutableDictionary alloc] init];
    
    [bufferAttributes setObject:[NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA] forKey:(NSString*)kCVPixelBufferPixelFormatTypeKey];//之前配置的下边注释掉的context使用的是kCVPixelFormatType_32ARGB，用起来颜色没有问题。但是用UIGraphicsBeginImageContextWithOptions([[UIApplication sharedApplication].delegate window].bounds.size, YES, 0);配置的context使用kCVPixelFormatType_32ARGB的话颜色会变成粉色，替换成kCVPixelFormatType_32BGRA之后，颜色正常。。。
    
    [bufferAttributes setObject:[NSNumber numberWithUnsignedInt:size.width/16*16] forKey:(NSString*)kCVPixelBufferWidthKey];//这个位置包括下面的两个，必须写成(int)size.width/16*16,因为这个的大小必须是16的倍数，否则图像会发生拉扯、挤压、旋转。。。。不知道为啥
    [bufferAttributes setObject:[NSNumber numberWithUnsignedInt:size.height/16*16] forKey:(NSString*)kCVPixelBufferHeightKey];
    [bufferAttributes setObject:@YES forKey:(NSString*)kCVPixelBufferCGBitmapContextCompatibilityKey];
    
    avAdaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:videoWriterInput sourcePixelBufferAttributes:bufferAttributes];
    
    //add input
    [videoWriter addInput:videoWriterInput];
    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime:CMTimeMake(0, 1000)];
    
    //create context
    if (context== NULL)
    {
        
        UIGraphicsBeginImageContextWithOptions([[UIApplication sharedApplication].delegate window].bounds.size, YES, 0);
        context = UIGraphicsGetCurrentContext();
        
    }
    if (context== NULL)
    {
        fprintf (stderr, "Context not created!");
        return NO;
    }
    
    return YES;
}

//结束清除
- (void) cleanupWriter {
    
    avAdaptor = nil;
    
    videoWriterInput = nil;
    
    videoWriter = nil;
    
    startedAt = nil;
}

//视频录制完毕调用
- (void) completeRecordingSession {
    
    [videoWriterInput markAsFinished];
    
    BOOL success = [videoWriter finishWriting];
    if (!success)
    {
        if ([_delegate respondsToSelector:@selector(recordingFaild:)]) {
            [_delegate recordingFaild:nil];
        }
        return ;
    }
    if ([_delegate respondsToSelector:@selector(recordingFinished:)]) {
        [_delegate recordingFinished:opPath];
    }
    
}

- (BOOL)is64bit{
#if defined(__LP64__) && __LP64__
    return YES;
#else
    return NO;
#endif
}
@end


#pragma mark- 音频与视频的合并
@interface LSSCaptureUtilities : NSObject
// 音频与视频的合并. action的形式如下:
+ (void)mergeVideo:(NSString *)videoPath andTarget:(id)target andAction:(SEL)action;
@end

@implementation LSSCaptureUtilities
+ (void)mergeVideo:(NSString *)videoPath andTarget:(id)target andAction:(SEL)action
{
    NSURL *videoUrl=[NSURL fileURLWithPath:videoPath];
    
    AVURLAsset* videoAsset = [[AVURLAsset alloc]initWithURL:videoUrl options:nil];
    
    AVMutableComposition* mixComposition = [AVMutableComposition composition];
  
    //混合视频
    AVMutableCompositionTrack *compositionVideoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                                                   preferredTrackID:kCMPersistentTrackID_Invalid];
    [compositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, videoAsset.duration)
                                   ofTrack:[[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0]
                                    atTime:kCMTimeZero error:nil];
    AVAssetExportSession* _assetExport = [[AVAssetExportSession alloc] initWithAsset:mixComposition
                                                                          presetName:AVAssetExportPresetPassthrough];
    

    //保存混合后的文件的过程
    NSString* videoName = @"export2.mov";
    NSString *exportPath = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:videoName];
    NSURL    *exportUrl = [NSURL fileURLWithPath:exportPath];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:exportPath])
    {
        [[NSFileManager defaultManager] removeItemAtPath:exportPath error:nil];
    }
    
    _assetExport.outputFileType = @"com.apple.quicktime-movie";
    NSLog(@"file type %@",_assetExport.outputFileType);
    _assetExport.outputURL = exportUrl;
    _assetExport.shouldOptimizeForNetworkUse = YES;
    
    [_assetExport exportAsynchronouslyWithCompletionHandler:
     ^(void )
     {
         if ([target respondsToSelector:action])
         {
             [target performSelector:action withObject:exportPath withObject:nil];
         }
     }];
    

}
@end


#pragma mark - 屏幕的录制-------------------------

@interface LSSVideoRecord()<LSSCaptureVideoDelegate>{
    LSSCaptureVideo *capture;
    NSString* opPath;
    BOOL isPauseing;
    BOOL isRecing;
}
@end

@implementation LSSVideoRecord
- (instancetype)init
{
    self = [super init];
    if (self) {
        isRecing=NO;
        isPauseing=NO;
    }
    return self;
}

#pragma mark- 开始录制
- (void)startRecording{
    if (isRecing) {
        return ;
    }
    isRecing =YES;
    if (!capture) {
        capture = [LSSCaptureVideo sharedRecorder];
        capture.frameRate = 35;
        capture.delegate = self;
    }

    [capture performSelector:@selector(startRecording1)];
}
#pragma mark-结束录制
- (void)stopRecording{
    
    isRecing =NO;
    isPauseing=NO;
    [[LSSCaptureVideo sharedRecorder]stopRecording];
    
    
}
#pragma mark-暂停/继续录制
-(void)PauseRecording{
    if (isRecing) {
        //暂停
        isRecing=NO;
        isPauseing=YES;
        [[LSSCaptureVideo sharedRecorder] pauseRecording];
        
    }else if(isPauseing)
    {
        isRecing=YES;
        isPauseing=NO;
        [[LSSCaptureVideo sharedRecorder] resumeRecording];
        
    }
    
}

#pragma mark -视频录制结束的代理
#pragma mark WFCaptureDelegate
- (void)recordingFinished:(NSString*)outputPath
{
    opPath=outputPath;
    [LSSCaptureUtilities mergeVideo:opPath andTarget:self andAction:@selector(mergedidFinish:WithError:)];
}
- (void)recordingFaild:(NSError *)error
{
    
}
#pragma mark CustomMethod

- (void)video: (NSString *)videoPath didFinishSavingWithError:(NSError *) error contextInfo: (void *)contextInfo{
    if (error) {
        NSLog(@"---%@",[error localizedDescription]);
    }
}
#pragma mark -音频与视频合并结束，存入相册中
- (void)mergedidFinish:(NSString *)videoPath WithError:(NSError *)error
{
    //音频与视频合并结束，存入相册中
    if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(videoPath)) {
        UISaveVideoAtPathToSavedPhotosAlbum(videoPath, self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
    }
    
}
@end


