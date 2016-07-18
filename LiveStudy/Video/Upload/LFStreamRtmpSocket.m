//
//  LFStreamRtmpSocket.m
//  LFLiveKit
//
//  Created by admin on 16/5/18.
//  Copyright © 2016年 live Interactive. All rights reserved.
//

#import "LFStreamRtmpSocket.h"
#import "rtmp.h"

#define DATA_ITEMS_MAX_COUNT 100
#define RTMP_DATA_RESERVE_SIZE 400
#define RTMP_HEAD_SIZE (sizeof(RTMPPacket)+RTMP_MAX_HEADER_SIZE)

#define SAVC(x)    static const AVal av_##x = AVC(#x)

static const AVal av_setDataFrame = AVC("@setDataFrame");
static const AVal av_SDKVersion = AVC("LFLiveKit 1.5.2");
SAVC(onMetaData);
SAVC(duration);
SAVC(width);
SAVC(height);
SAVC(videocodecid);
SAVC(videodatarate);
SAVC(framerate);
SAVC(audiocodecid);
SAVC(audiodatarate);
SAVC(audiosamplerate);
SAVC(audiosamplesize);
SAVC(audiochannels);
SAVC(stereo);
SAVC(encoder);
SAVC(av_stereo);
SAVC(fileSize);
SAVC(avc1);
SAVC(mp4a);

@interface LFStreamRtmpSocket ()
{
    PILI_RTMP* _rtmp;
}
@property (nonatomic, strong) LFStreamingBuffer *buffer;
@property (nonatomic, strong) dispatch_queue_t socketQueue;
//错误信息
@property (nonatomic, assign) RTMPError error;
@property (nonatomic, assign) NSInteger retryTimes4netWorkBreaken;

@property (nonatomic, assign) BOOL isSending;
@property (nonatomic, assign) BOOL isConnected;
@property (nonatomic, assign) BOOL isConnecting;
@property (nonatomic, assign) BOOL isReconnecting;

@property (nonatomic, assign) BOOL sendVideoHead;
@property (nonatomic, assign) BOOL sendAudioHead;

@end

@implementation LFStreamRtmpSocket

- (void) start{
    dispatch_async(self.socketQueue, ^{
        if(_isConnecting) return;
        if(_rtmp != NULL) return;
        
        [self RTMP264_Connect:(char*)[@"rtmp://192.168.72.49:5920/rtmplive/room" cStringUsingEncoding:NSASCIIStringEncoding]];
    });
}

- (void) stop{
    dispatch_async(self.socketQueue, ^{
        if(_rtmp != NULL){
            PILI_RTMP_Close(_rtmp, &_error);
            PILI_RTMP_Free(_rtmp);
            _rtmp = NULL;
        }
        [self clean];
    });
}

- (void) sendFrame:(LFFrame*)frame{
    __weak typeof(self) _self = self;
    dispatch_async(self.socketQueue, ^{
        __strong typeof(_self) self = _self;
        if(!frame) return;
        [self.buffer appendObject:frame];
        [self sendFrame];
    });
}

#pragma mark -- CustomMethod
- (void)sendFrame{
    if(!self.isSending && self.buffer.list.count > 0){
        self.isSending = YES;
    
        if(!_isConnected ||  _isReconnecting || _isConnecting || !_rtmp) return;
    
        // 调用发送接口
        LFFrame *frame = [self.buffer popFirstObject];
        if([frame isKindOfClass:[LFVideoFrame class]]){
            if(!self.sendVideoHead){
                self.sendVideoHead = YES;
                [self sendVideoHeader:(LFVideoFrame*)frame];
            }else{
                [self sendVideo:(LFVideoFrame*)frame];
            }
        }
    }
}

- (void)clean{
    _isConnecting = NO;
    _isReconnecting = NO;
    _isSending = NO;
    _isConnected = NO;
    _sendAudioHead = NO;
    _sendVideoHead = NO;
    [self.buffer removeAllObject];
    self.retryTimes4netWorkBreaken = 0;
}

-(NSInteger) RTMP264_Connect:(char *)push_url{
    //由于摄像头的timestamp是一直在累加，需要每次得到相对时间戳
    //分配与初始化
    if(_isConnecting) return -1;
    
    _isConnecting = YES;
    if(_rtmp != NULL){
        PILI_RTMP_Close(_rtmp, &_error);
        PILI_RTMP_Free(_rtmp);
    }
    
    _rtmp = PILI_RTMP_Alloc();
    PILI_RTMP_Init(_rtmp);
    
    //设置URL
    if (PILI_RTMP_SetupURL(_rtmp, push_url, &_error) < 0){
        //log(LOG_ERR, "RTMP_SetupURL() failed!");
        goto Failed;
    }
    
    //设置可写，即发布流，这个函数必须在连接前使用，否则无效
    PILI_RTMP_EnableWrite(_rtmp);
    
    //连接服务器
    if (PILI_RTMP_Connect(_rtmp, NULL, &_error) < 0){
        goto Failed;
    }
    
    //连接流
    if (PILI_RTMP_ConnectStream(_rtmp, 0, &_error) < 0) {
        goto Failed;
    }
    
//    [self sendMetaData];
    
    _isConnected = YES;
    _isConnecting = NO;
    _isReconnecting = NO;
    _isSending = NO;
    _retryTimes4netWorkBreaken = 0;
    return 0;
    
Failed:
    PILI_RTMP_Close(_rtmp, &_error);
    PILI_RTMP_Free(_rtmp);
    [self clean];
    return -1;
}



// 视频同步包
- (void)sendVideoHeader:(LFVideoFrame*)videoFrame {
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
    
    [self sendPacket:RTMP_PACKET_TYPE_VIDEO data:body size:iIndex nTimestamp:0];
    free(body);
}

// 普通数据包
- (void)sendVideo:(LFVideoFrame*)frame{
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
    // NALU size
    body[i++] = (frame.data.length >> 24) & 0xff;
    body[i++] = (frame.data.length >> 16) & 0xff;
    body[i++] = (frame.data.length >>  8) & 0xff;
    body[i++] = (frame.data.length ) & 0xff;
    // NALU data
    memcpy(&body[i],frame.data.bytes,frame.data.length);
    
    [self sendPacket:RTMP_PACKET_TYPE_VIDEO data:body size:(rtmpLength) nTimestamp:frame.timestamp];
    free(body);
}

-(NSInteger) sendPacket:(unsigned int)nPacketType data:(unsigned char *)data size:(NSInteger) size nTimestamp:(uint64_t) nTimestamp{
    NSInteger rtmpLength = size;
    PILI_RTMPPacket rtmp_pack;
    PILI_RTMPPacket_Reset(&rtmp_pack);
    PILI_RTMPPacket_Alloc(&rtmp_pack,(uint32_t)rtmpLength);
    
    rtmp_pack.m_nBodySize = (uint32_t)size;
    memcpy(rtmp_pack.m_body,data,size);
    rtmp_pack.m_hasAbsTimestamp = 0;
    rtmp_pack.m_packetType = nPacketType;
    if(_rtmp) rtmp_pack.m_nInfoField2 = _rtmp->m_stream_id;
    rtmp_pack.m_nChannel = 0x04;
    rtmp_pack.m_headerType = RTMP_PACKET_SIZE_LARGE;
    if (RTMP_PACKET_TYPE_AUDIO == nPacketType && size !=4){
        rtmp_pack.m_headerType = RTMP_PACKET_SIZE_MEDIUM;
    }
    rtmp_pack.m_nTimeStamp = (uint32_t)nTimestamp;
    
    NSInteger nRet = [self RtmpPacketSend:&rtmp_pack];
    
    PILI_RTMPPacket_Free(&rtmp_pack);
    return nRet;
}

- (NSInteger)RtmpPacketSend:(PILI_RTMPPacket*)packet{
    if (PILI_RTMP_IsConnected(_rtmp)){
        int success = PILI_RTMP_SendPacket(_rtmp,packet,0,&_error);
        if(success){
            self.isSending = NO;
            [self sendFrame];
        }
        return success;
    }
    
    return -1;
}




#pragma mark -- Getter Setter
- (dispatch_queue_t)socketQueue{
    if(!_socketQueue){
        _socketQueue = dispatch_queue_create("com.youku.LaiFeng.live.socketQueue", NULL);
    }
    return _socketQueue;
}

- (LFStreamingBuffer*)buffer{
    if(!_buffer){
        _buffer = [[LFStreamingBuffer alloc] init];
    }
    return _buffer;
}

@end
