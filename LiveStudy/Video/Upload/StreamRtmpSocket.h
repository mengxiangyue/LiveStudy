//
//  StreamRtmpSocket.h
//  LiveStudy
//
//  Created by wenba201600164 on 16/7/14.
//  Copyright © 2016年 wenba. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VideoFrame.h"

@interface StreamRtmpSocket : NSObject

- (void)start;
- (void)start;

#pragma mark - Video
- (void)sendVideoFrame:(nullable VideoFrame *)frame;

@end
