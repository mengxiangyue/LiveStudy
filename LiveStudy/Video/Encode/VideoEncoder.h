//
//  VideoEncoder.h
//  LiveStudy
//
//  Created by wenba201600164 on 16/7/14.
//  Copyright © 2016年 wenba. All rights reserved.
//

#import <Foundation/Foundation.h>
@import AVFoundation;

@interface VideoEncoder : NSObject

- (void)encodeVideoData:(nullable CVImageBufferRef)pixelBuffer timeStamp:(uint64_t)timeStamp;

@end
