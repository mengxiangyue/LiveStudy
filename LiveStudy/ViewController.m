//
//  ViewController.m
//
//

#import "ViewController.h"
#import "VideoCapture.h"
@import AVFoundation;

@interface ViewController ()

@property (strong, nonatomic) VideoCapture *videoCapture;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.videoCapture = [[VideoCapture alloc] init];
    [self.videoCapture setPreview:self.view];
    [self.videoCapture start];
    
    
}


@end
