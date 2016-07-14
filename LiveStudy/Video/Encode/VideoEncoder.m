//
//  VideoEncoder.m
//  LiveStudy
//
//  Created by wenba201600164 on 16/7/14.
//  Copyright © 2016年 wenba. All rights reserved.
//

#import "VideoEncoder.h"
@import VideoToolbox;

@interface VideoEncoder ()

@property (assign, nonatomic) VTCompressionSessionRef compressionSession;
@property (assign, nonatomic) NSInteger frameCount;
@property (strong, nonatomic) NSData *sps;
@property (strong, nonatomic) NSData *pps;

@property (assign ,nonatomic) BOOL enabledWriteVideoFile;
@property (assign, nonatomic) FILE *fp;

@end

@implementation VideoEncoder

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.enabledWriteVideoFile = YES;
        [self initForFilePath];
        
        // 创建压缩Session  VideoCompressonOutputCallback 回调函数  (__bridge void *)self 回调函数中获取
        OSStatus status = VTCompressionSessionCreate(NULL, 368, 640, kCMVideoCodecType_H264, NULL, NULL, NULL, VideoCompressonOutputCallback, (__bridge void *)self, &_compressionSession); // 这里不能使用&self.compressionSession
        if(status == noErr){
            // GOP 画面组
            VTSessionSetProperty(self.compressionSession, kVTCompressionPropertyKey_MaxKeyFrameInterval,(__bridge CFTypeRef)@(15));
            VTSessionSetProperty(self.compressionSession, kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration,(__bridge CFTypeRef)@(15));
            // 帧率，即 fps
            VTSessionSetProperty(self.compressionSession, kVTCompressionPropertyKey_ExpectedFrameRate, (__bridge CFTypeRef)@(15));
            // 帧率，即 fps
            VTSessionSetProperty(self.compressionSession, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef)@(800 * 1024));
            NSArray *limit = @[@(800 * 1024 * 1.5/8),@(1)]; // todo 不清楚为啥 *1.5/8
            VTSessionSetProperty(self.compressionSession, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFArrayRef)limit);
            // 是否实时渲染
            VTSessionSetProperty(self.compressionSession, kVTCompressionPropertyKey_RealTime, kCFBooleanFalse);
            VTSessionSetProperty(self.compressionSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Main_AutoLevel);
            VTSessionSetProperty(self.compressionSession, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse);
            // http://blog.csdn.net/jubincn/article/details/6948334
            VTSessionSetProperty(self.compressionSession, kVTCompressionPropertyKey_H264EntropyMode, kVTH264EntropyMode_CABAC);
            VTCompressionSessionPrepareToEncodeFrames(self.compressionSession);
        }
        
    }
    return self;
}

- (void)encodeVideoData:(nullable CVImageBufferRef)pixelBuffer timeStamp:(uint64_t)timeStamp {
    self.frameCount++;
    CMTime presentationTimeStamp = CMTimeMake(self.frameCount, 1000);  // CMTimeMake(a,b)    a当前第几帧, b每秒钟多少帧.当前播放时间a/b
    VTEncodeInfoFlags flags;
    CMTime duration = CMTimeMake(1, (int32_t)15);
    
    NSDictionary *properties = nil;
    if(self.frameCount % (int32_t)15 == 0){ // videoMaxKeyframeInterval 最大frame间隔插入一个关键帧
        properties = @{(__bridge NSString *)kVTEncodeFrameOptionKey_ForceKeyFrame: @YES};
    }
    NSNumber *timeNumber = @(timeStamp);
    
    VTCompressionSessionEncodeFrame(self.compressionSession, pixelBuffer, presentationTimeStamp, duration, (__bridge CFDictionaryRef)properties, (__bridge_retained void *)timeNumber, &flags);
    
}

- (void)stopEncoder{
    VTCompressionSessionCompleteFrames(self.compressionSession, kCMTimeIndefinite);
}

// 销毁Session
- (void)destroySession {
    if (self.compressionSession != NULL) {
        VTCompressionSessionCompleteFrames(self.compressionSession, kCMTimeInvalid);
        VTCompressionSessionInvalidate(self.compressionSession);
        CFRelease(self.compressionSession);
        self.compressionSession = NULL;
    }
    
}

- (void)dealloc {
    [self destroySession];
}

#pragma mark -- VideoCallBack
static void VideoCompressonOutputCallback(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer) {
    NSLog(@"didCompressH264 called with status %d infoFlags %d", (int)status, (int)infoFlags);
    if (status != 0) return;
    if (!sampleBuffer) {
        return;
    }
    CFArrayRef array = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true);
    if (!array) {
        return;
    }
    CFDictionaryRef dict = (CFDictionaryRef)CFArrayGetValueAtIndex(array, 0);
    if (!dict) {
        return;
    }
    BOOL isKeyframe = !CFDictionaryContainsKey(dict, kCMSampleAttachmentKey_NotSync); // Not Sync Sample
    uint64_t timeStamp = [((__bridge_transfer NSNumber *)sourceFrameRefCon) longLongValue];
    
    
    VideoEncoder *videoEncoder = (__bridge VideoEncoder*)outputCallbackRefCon;
    
    // 获取sps pps
    if (isKeyframe && !videoEncoder.sps) {
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        size_t sparameterSetSize, sparameterSetCount;
        const uint8_t *sparameterSet;
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0 );
        if (statusCode == noErr)
        {
            size_t pparameterSetSize, pparameterSetCount;
            const uint8_t *pparameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0 );
            if (statusCode == noErr)
            {
                videoEncoder.sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
                videoEncoder.pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
                
                if(videoEncoder.enabledWriteVideoFile){
                    NSMutableData *data = [[NSMutableData alloc] init];
                    uint8_t header[] = {0x00,0x00,0x00,0x01};
                    [data appendBytes:header length:4];
                    [data appendData:videoEncoder.sps];
                    [data appendBytes:header length:4];
                    [data appendData:videoEncoder.pps];
                    fwrite(data.bytes, 1,data.length,videoEncoder.fp);
                }
                
            }
        }
    }
    
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer; // 注意这里是指针，所以后面才能够根据这个指针拷贝对应的数据
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if (statusCodeRet == noErr) {
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4;
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            // Read the NAL unit length
            uint32_t NALUnitLength = 0;
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            
            // http://blog.csdn.net/sunshine1314/article/details/2309655 参考一下 Big Endian 字节序
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            
            if(videoEncoder.enabledWriteVideoFile){
                NSMutableData *data = [[NSMutableData alloc] init];
                if(isKeyframe){
                    uint8_t header[] = {0x00,0x00,0x00,0x01};
                    [data appendBytes:header length:4];
                }else{
                    uint8_t header[] = {0x00,0x00,0x01};
                    [data appendBytes:header length:3];
                }
                [data appendData:[[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength]];
                
                fwrite(data.bytes, 1,data.length,videoEncoder.fp);
            }
            bufferOffset += AVCCHeaderLength + NALUnitLength;
            
        }
        
    }
    
    
}

- (void)initForFilePath
{
    char *path = [self GetFilePathByfileName:"IOSCamDemo.h264"];
    NSLog(@"%s",path);
    self.fp = fopen(path,"wb");
}


- (char*)GetFilePathByfileName:(char*)filename
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask,YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *strName = [NSString stringWithFormat:@"%s",filename];
    
    NSString *writablePath = [documentsDirectory stringByAppendingPathComponent:strName];
    
    NSUInteger len = [writablePath length];
    
    char *filepath = (char*)malloc(sizeof(char) * (len + 1));
    
    [writablePath getCString:filepath maxLength:len + 1 encoding:[NSString defaultCStringEncoding]];
    
    return filepath;
}

@end
