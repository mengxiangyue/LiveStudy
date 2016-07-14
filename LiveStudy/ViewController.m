//
//  ViewController.m
//
//

#import "ViewController.h"
#import "VideoCapture.h"
#import "VideoEncoder.h"
@import AVFoundation;

#define NOW (CACurrentMediaTime()*1000)
@interface ViewController () <VideoCaptureDelegate>

@property (strong, nonatomic) VideoCapture *videoCapture;

@property (strong, nonatomic) VideoEncoder *videoEncoder;

@property (nonatomic, assign) uint64_t timestamp;
@property (nonatomic, assign) BOOL isFirstFrame;
@property (nonatomic, assign) uint64_t currentTimestamp;

@end

@implementation ViewController {
    dispatch_semaphore_t _lock;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.videoCapture = [[VideoCapture alloc] init];
    self.videoCapture.delegate = self;
    [self.videoCapture setPreview:self.view];
    [self.videoCapture start];
    
    _lock = dispatch_semaphore_create(1);
    self.videoEncoder = [[VideoEncoder alloc] init];
    
}

#pragma mark - VideoCaptureDelegate
- (void)captureOutput:(nullable VideoCapture *)capture pixelBuffer:(nullable CVImageBufferRef)pixelBuffer {
    [self.videoEncoder encodeVideoData:pixelBuffer timeStamp:[self currentTimestamp]];
}

- (uint64_t)currentTimestamp{
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    uint64_t currentts = 0;
    if(_isFirstFrame == true) {
        _timestamp = NOW;
        _isFirstFrame = false;
        currentts = 0;
    }
    else {
        currentts = NOW - _timestamp;
    }
    dispatch_semaphore_signal(_lock);
    return currentts;
}


@end
