//
//  VideoCapture.m
//  LiveStudy
//
//  Created by wenba201600164 on 16/7/13.
//  Copyright © 2016年 wenba. All rights reserved.
//

/*
 * todo
 * 前后摄像头切换
 */

#import "VideoCapture.h"

@interface VideoCapture () <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (strong, nonatomic) AVCaptureSession *captureSession; // 连接 input output
@property (strong, nonatomic) AVCaptureVideoPreviewLayer *previewLayer; // 显示实时预览图像
@property (strong, nonatomic) AVCaptureConnection *captureConnection; // 配置一些输出视频参数

@property (strong, nonatomic) AVCaptureDevice *cameraDevice;
@property (strong, nonatomic) AVCaptureDeviceInput *inputDevice;
@property (strong, nonatomic) AVCaptureVideoDataOutput *videoOutput;

@end

@implementation VideoCapture

- (instancetype)init
{
    self = [super init];
    if (self) {
        NSError *deviceError;
        self.cameraDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        self.inputDevice = [AVCaptureDeviceInput deviceInputWithDevice:self.cameraDevice error:&deviceError];
        if (deviceError) {
            NSLog(@"错误");
        }
        self.videoOutput = [[AVCaptureVideoDataOutput alloc] init];
        NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey;
        NSNumber* val = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange];
        NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:val forKey:key];
        self.videoOutput.videoSettings = videoSettings;
        
        [self.videoOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()]; // 这个输出需要自定义的queue 不要放到主线程
        
        // 初始化session
        self.captureSession = [[AVCaptureSession alloc] init];
        if ([self.captureSession canAddInput:self.inputDevice]) {
            [self.captureSession addInput:self.inputDevice];
        }
        if ([self.captureSession canAddOutput:self.videoOutput]) {
            [self.captureSession addOutput:self.videoOutput];
        }
        
        [self.captureSession beginConfiguration]; // 把多个配置作为一个原子更新
        [self.captureSession setSessionPreset:AVCaptureSessionPreset1280x720];
        self.captureConnection = [self.videoOutput connectionWithMediaType:AVMediaTypeVideo]; // todo 研究作用
        [self setRelativeVideoOrientation];
        
        NSNotificationCenter* notify = [NSNotificationCenter defaultCenter];
        
        [notify addObserver:self
                   selector:@selector(statusBarOrientationDidChange:)
                       name:@"StatusBarOrientationDidChange"
                     object:nil];
        [self.captureSession commitConfiguration];
        
        self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
        [self.previewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
        
        
    }
    return self;
}


- (void)setPreview:(UIView *)preview {
    if (self.previewLayer.superlayer) {
        [self.previewLayer removeFromSuperlayer];
    }
    self.previewLayer.frame = preview.bounds;
    [preview.layer insertSublayer:self.previewLayer atIndex:0];
    
}

- (void)start {
    [self.captureSession startRunning];
}

- (void)stop {
    [self.captureSession stopRunning];
}

- (void)statusBarOrientationDidChange:(NSNotification*)notification {
    [self setRelativeVideoOrientation];
}

- (void)setRelativeVideoOrientation {
    switch ([[UIDevice currentDevice] orientation]) {
        case UIInterfaceOrientationPortrait:
#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
        case UIInterfaceOrientationUnknown:
#endif
            self.captureConnection.videoOrientation = AVCaptureVideoOrientationPortrait;
            
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            self.captureConnection.videoOrientation =
            AVCaptureVideoOrientationPortraitUpsideDown;
            break;
        case UIInterfaceOrientationLandscapeLeft:
            self.captureConnection.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
        case UIInterfaceOrientationLandscapeRight:
            self.captureConnection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
            break;
        default:
            break;
    }
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer); // 这个是获取对应的图像信息
//    NSLog(@"开始输出图像捕获了");
    if ([self.delegate respondsToSelector:@selector(captureOutput:pixelBuffer:)]) {
        [self.delegate captureOutput:self pixelBuffer:imageBuffer];
    }
}

@end
