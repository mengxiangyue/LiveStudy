# LiveStudy
该学习工程参考 [LFLiveKit](https://github.com/LaiFengiOS/LFLiveKit) 编写。

## 步骤
### 视频
 1. 视频捕获
 2. 视频编码H264
 3. 视频编码FLV
 4. RTMP推流
 
### 音频
 1. 音频捕获
 2. 音频编码AAC
 3. 音频编码FLV
 4. RTMP推流   

##Tag（表示关键节点功能）
* 0.1 完成图像的捕获，通过摄像头获取图像数据   
* 0.2 使用硬件进行H264编码，并保存H264裸流为文件，文件名称IOSCamDemo.h264，使用VLC能够正常播放   
* 0.3 将视频数据封装成FLV数据格式，因为RTMP推流需要使用FLV格式（但是FLV去掉了头部，只有数据部分）