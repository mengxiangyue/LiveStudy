//
//  VideoEncoder.h
//  LiveStudy
//
//  Created by wenba201600164 on 16/7/14.
//  Copyright © 2016年 wenba. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VideoFrame.h"
@import AVFoundation;

@class VideoEncoder;
/// 编码器编码后回调
@protocol VideoEncodingDelegate <NSObject>
@required
- (void)videoEncoder:(nonnull VideoEncoder *)encoder videoFrame:(nullable VideoFrame *)frame;
@end

@interface VideoEncoder : NSObject
@property (weak, nonatomic, nullable) id<VideoEncodingDelegate> delegate;

- (void)encodeVideoData:(nullable CVImageBufferRef)pixelBuffer timeStamp:(uint64_t)timeStamp;

@end
