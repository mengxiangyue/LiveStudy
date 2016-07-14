//
//  VideoFrame.h
//  LiveStudy
//
//  Created by wenba201600164 on 16/7/14.
//  Copyright © 2016年 wenba. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VideoFrame : NSObject

@property (nonatomic, assign) uint64_t timestamp;
@property (nonatomic, strong) NSData *data;
///< flv或者rtmp包头
@property (nonatomic, strong) NSData *header;

@property (nonatomic, assign) BOOL isKeyFrame;
@property (nonatomic, strong) NSData *sps;
@property (nonatomic, strong) NSData *pps;

@end
