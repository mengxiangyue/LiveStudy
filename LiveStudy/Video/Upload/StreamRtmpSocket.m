//
//  StreamRtmpSocket.m
//  LiveStudy
//
//  Created by wenba201600164 on 16/7/14.
//  Copyright © 2016年 wenba. All rights reserved.
//

#import "StreamRtmpSocket.h"

@interface StreamRtmpSocket ()

// 这个需要进行一定的优化 这里只是最简单的保存所有的Frame
@property (strong, nonatomic) NSMutableArray *buffer;
@property (assign, nonatomic) BOOL isSending;  // 用于保证同时只有一帧在发送
@property (assign, nonatomic) BOOL sendVideoHeader; // 是否已经发送过视频同步包

@end

@implementation StreamRtmpSocket

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.buffer = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)sendVideoFrame:(nullable VideoFrame *)frame {
    // todo 这里需要放到异步线程里面 以免影响主线程
    if (!frame) {
        return;
    }
    [self.buffer addObject:frame];
    [self sendFrame];
}

- (void)sendFrame {
    if (!self.isSending && [self.buffer count] > 0) {
        self.isSending = YES;
        id frame = [self.buffer objectAtIndex:0];
        [self.buffer removeObjectAtIndex:0];
        if ([frame isKindOfClass:[VideoFrame class]]) {
            VideoFrame *videoFrame = (VideoFrame *)frame;
            if (!self.sendVideoHeader) {
                self.sendVideoHeader = YES;
                [self sendVideoHeader:videoFrame];
            } else {
                [self sendVideo:videoFrame];
            }
        }
    }
}

// 视频同步包
- (void)sendVideoHeader:(VideoFrame*)videoFrame {
    if(!videoFrame || !videoFrame.sps || !videoFrame.pps) return;
    
    unsigned char * body=NULL;
    NSInteger iIndex = 0;
    NSInteger rtmpLength = 1024;
    const char *sps = videoFrame.sps.bytes;
    const char *pps = videoFrame.pps.bytes;
    NSInteger sps_len = videoFrame.sps.length;
    NSInteger pps_len = videoFrame.pps.length;
    
    body = (unsigned char*)malloc(rtmpLength);
    memset(body,0,rtmpLength);
    
    // http://billhoo.blog.51cto.com/2337751/1557646
    body[iIndex++] = 0x17; // Frame Type 1: key frame | 7: AVC
    
    // AVCVIDEOPACKET
    body[iIndex++] = 0x00; // AVPacketType: AVC squence header
    
    // Compositon Time 0x000000
    body[iIndex++] = 0x00;
    body[iIndex++] = 0x00;
    body[iIndex++] = 0x00;
    
    // AVDecoderConfigurationRecord
    body[iIndex++] = 0x01; // configurationVersion
    body[iIndex++] = sps[1];  // AVCProfileIndication
    body[iIndex++] = sps[2];  // profile_compatibility
    body[iIndex++] = sps[3];  // AVCLevelIndication
    body[iIndex++] = 0xff;  // lengthSizeMinusOne, always 0xFF
    
    /*sps*/
    body[iIndex++]   = 0xe1; // Numbers of Sps 1110 0001
    // Sps data length
    body[iIndex++] = (sps_len >> 8) & 0xff;
    body[iIndex++] = sps_len & 0xff;
    // Sps data
    memcpy(&body[iIndex],sps,sps_len);
    iIndex +=  sps_len;
    
    /*pps*/
    body[iIndex++]   = 0x01;  // Numbers of Pps
    // Pps data length
    body[iIndex++] = (pps_len >> 8) & 0xff;
    body[iIndex++] = (pps_len) & 0xff;
    // Pps data
    memcpy(&body[iIndex], pps, pps_len);
    iIndex +=  pps_len;
    
//    [self sendPacket:RTMP_PACKET_TYPE_VIDEO data:body size:iIndex nTimestamp:0];
    [self sendPacket:0 data:nil size:0 nTimestamp:0]; // todo 
    free(body);
}

// 普通数据包
- (void)sendVideo:(VideoFrame*)frame{
    if(!frame || !frame.data || frame.data.length < 11) return;
    
    NSInteger i = 0;
    NSInteger rtmpLength = frame.data.length+9;
    unsigned char *body = (unsigned char*)malloc(rtmpLength);
    memset(body,0,rtmpLength);
    
    // http://billhoo.blog.51cto.com/2337751/1557646
    if(frame.isKeyFrame){
        body[i++] = 0x17;// 1:Iframe  7:AVC
    } else{
        body[i++] = 0x27;// 2:Pframe  7:AVC
    }
    body[i++] = 0x01;// AVPacketType: AVC NALU
    // Compositon Time 0x000000
    body[i++] = 0x00;
    body[i++] = 0x00;
    body[i++] = 0x00;
    // NALU size 24bit
    body[i++] = (frame.data.length >> 24) & 0xff;
    body[i++] = (frame.data.length >> 16) & 0xff;
    body[i++] = (frame.data.length >>  8) & 0xff;
    body[i++] = (frame.data.length ) & 0xff;
    // NALU data
    memcpy(&body[i],frame.data.bytes,frame.data.length);
    
//    [self sendPacket:RTMP_PACKET_TYPE_VIDEO data:body size:(rtmpLength) nTimestamp:frame.timestamp];
    [self sendPacket:0 data:nil size:0 nTimestamp:frame.timestamp]; // todo
    free(body);
}

-(NSInteger)sendPacket:(unsigned int)nPacketType data:(unsigned char *)data size:(NSInteger) size nTimestamp:(uint64_t) nTimestamp {
    NSLog(@"send frame %llu", nTimestamp);
    self.isSending = NO;
    [self sendFrame];
    return 0;
}

@end
