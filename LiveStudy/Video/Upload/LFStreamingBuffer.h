//
//  LFStreamingBuffer.h
//  LFLiveKit
//
//  Created by 倾慕 on 16/5/2.
//  Copyright © 2016年 倾慕. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VideoFrame.h"


#define LFVideoFrame VideoFrame
#define LFFrame VideoFrame
/** current buffer status */
typedef NS_ENUM(NSUInteger, LFLiveBuffferState) {
    LFLiveBuffferUnknown = 0,      //< 未知
    LFLiveBuffferIncrease = 1,    //< 缓冲区状态好可以增加码率
    LFLiveBuffferDecline = 2      //< 缓冲区状态差应该降低码率
};

@interface LFStreamingBuffer : NSObject

/** current frame buffer */
@property (nonatomic, strong, readonly) NSMutableArray <LFFrame*>* _Nonnull list;

/** buffer count max size default 1000 */
@property (nonatomic, assign) NSUInteger maxCount;

/** add frame to buffer */
- (void)appendObject:(nullable LFFrame*)frame;

/** pop the first frome buffer */
- (nullable LFFrame*)popFirstObject;

/** remove all objects from Buffer */
- (void)removeAllObject;

@end
