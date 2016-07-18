//
//  LFStreamSocket.h
//  LFLiveKit
//
//  Created by admin on 16/5/3.
//  Copyright © 2016年 倾慕. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LFStreamingBuffer.h"


@protocol LFStreamSocket <NSObject>
- (void) start;
- (void) stop;
- (void) sendFrame:(nullable LFFrame*)frame;
@end
