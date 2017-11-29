---
title: nginx proxy 支持flv流式播放
date: 2017-10-11T12:15:52.000Z
time: 1507866368
tags:
	- nginx
	- flv
categories: nginx
comments: true
---

nginx 本身的flv模块实现得很简单：
1. 只支持start不支持end，这样的话前端就不能分段播放。
2. start的行为跟http标准的range请求一样，只是做了文件的seek，没有考虑flv文件的tag对齐，这样就需要播放器做容错处理，不能直接播放。我测试的过程中， 除了迅雷看看能播放， FLC和一些在线flv播放器都播放不了。
3. 不能和proxy-cache一起使用，也就是说不能用nginx做代理， 只有文件在本机存储的情况下才能用。

简单来说，这种简单的实现基本没法用在实际产品中。我们需要支持**start**/**end**，**miss 拖拽**，需要**和proxy-cache一起工作** 。所以我自己写了个nginx 模块: [ngx_http_flv_filter_module](https://github.com/liuhengloveyou/ngx_http_flv_filter_module)



要处理flv文件，首先要了解一下FLV的文件结构：

# FLV文件结构

FLV文件以大端对齐方式存放多字节整型，分为头和体两部分：

| 类型   | 长度（byte） | 说明   |
| ---- | -------- | ---- |
| 文件头  | 9        | 固定长度 |
| 文件体  | n        | 可变   |

## 文件头结构

文件头的长度是固定的，格式如下：

| 字段     | 长度（bit） | 说明                       |
| ------ | ------- | ------------------------ |
| 签名     | 8       | 'F'(0x46)                |
| 签名     | 8       | 'L'(0x4C)                |
| 签名     | 8       | 'V'(0x56)                |
| 版本     | 8       | 一般为0x01，1表示FLV 版本是1      |
| 保留字段   | 5       | 保留位，均为0                  |
| 是否有音频流 | 1       | 否包括音频数据，1是有，0是没有         |
| 保留字段   | 1       | 保留位                      |
| 是否有视频流 | 1       | 是否包括视频数据，1是有，0是没有        |
| 文件头大   | 32      | Header的长度，为固定值0x00000009 |

## 文件体结构

FLV的文件内容为多个连续的TAG和TAG的长度组成：

| 字段                | 长度(byte) | 说明            |
| ----------------- | -------- | ------------- |
| PreviousTagSize 0 | 4        | 永远为0x00000000 |
| Tag 1             | n        | 第一个Tag        |
| PreviousTagSize 1 | 4        | 第一个Tag的长度     |
| Tag 2             | n        | 第二个Tag        |
| ...               | ...      |               |
| PreviousTagSize n | 4        | 最后一个Tag的长度    |

## TAG结构

TAG是FLV文件的内容封装格式，目前包括音频、视频、脚本三种TAG类型。同样是由头和体组成。

## TAG头结构：

| 字段    | 长度(byte) | 说明                                       |
| ----- | -------- | ---------------------------------------- |
| TAG类型 | 1        | 0x08表示Tag Data为AudioData；</br>0x09表示Tag Data为VideoData；</br>0x12表示Tag Data为ScriptDataObject |
| 数据大小  | 3        | 本Tag所封装Tag Data的长度                       |
| 时间戳   | 3        | 相对第一个Tag的时间戳，因此第一个Tag的时间戳为0。</br>也可以将所有Tag的时间戳全配置为0，解码器会自动处理。 |
| 扩展时间戳 | 1        | 如果时戳大于0xFFFFFF，将会使用这个字节。</br>这个字节是时戳的高8位，上面的三个字节是低24位。 |
| 流ID   | 3        | 没有用；默认的全为0                               |
| 数据区   | DataSize | 由TagType的值表示存储内容的类型                      |

## 视频数据

当一个Tag为视频的内容时，同样包括视频数据头部和体组成：

| 字段   | 长度（bit） | 说明                                       |
| ---- | ------- | ---------------------------------------- |
| 帧类型  | 4       | 1为关键帧 </br>2为非关键帧 </br>3为h263的非关键帧 </br>4为服务器生成关键帧 </br>5为视频信息或命令帧。 |
| 编码ID | 4       | 1为JPEG </br>2为H263 </br>3为Screen video </br>4为On2 VP6 </br>5为On2 VP6 </br>6为Screen videoversion 2 </br>7为AVC |
| 视频数据 | n       | CodecID=2，为H263VideoPacket </br>CodecID=3，为ScreenVideopacket <br>CodecID=4，为VP6FLVVideoPacket <br>CodecID=5，为VP6FLVAlphaVideoPacket <br>CodecID=6，为ScreenV2VideoPacket <br>CodecID=7，为AVCVideoPacket |

## 音频数据

| 字段   | 长度(bit) | 说明                                       |
| ---- | ------- | ---------------------------------------- |
| 音频格式 | 4       | 0 = Linear PCM, platform endian<br> 1 = ADPCM<br>2 = MP3<br>3 = Linear PCM, little endian<br>4 = Nellymoser 16-kHz mono<br>5 = Nellymoser 8-kHz mono<br>6 = Nellymoser<br>7= G.711 A-law logarithmic PCM<br>8 = G.711 mu-law logarithmic PCM<br>9 = reserved<br>10 = AAC<br>11 = Speex<br>14 = MP3 8-Khz<br>15 = Device-specific sound<br>7, 8, 14, and 15：内部保留使用。<br>flv是不支持g711a的，如果要用，可能要用线性音频 |
| 采样率  | 2       | For AAC: always 3<br>0 = 5.5-kHz<br>1 = 11-kHz<br>2 = 22-kHz<br>3 = 44-kHz |
| 采样大小 | 1       | 0 = snd8Bit<br>1 = snd16Bit</br>压缩过的音频都是16bit |
| 声道   | 1       | 0=单声道<br>1=立体声,双声道。<br>AAC永远是1           |
| 声音数据 | n       | 如果是PCM线性数据，存储的时候每个16bit小端存储，有符号。如果音频格式是AAC，则存储的数据是AAC AUDIO DATA，否则为线性数组。 |

## AVCVideoPacket结构

AVCVideoPacket同样包括Packet Header和Packet Body两部分：

| 字段           | 长度（byte） | 说明                                       |
| ------------ | -------- | ---------------------------------------- |
| AVC packet类型 | 1        | 0：AVC序列头<br>1：AVC NALU单元<br>2：AVC序列结束。低级别avc不需要。 |
| CTS          | 3        | 相对时间戳； 如果AVC packet类型是1，则为cts偏移(见下面的解释)，为0则为0 |
| Data         | n        | 负载数据 <br>如果AVC packet类型是0，则是解码器配置，sps，pps。<br>如果是1，则是nalu单元，可以是多个 |

> 关于CTS：

是一个比较难以理解的概念，需要和pts，dts配合一起理解。

> 首先，pts（presentation time stamps），dts(decoder timestamps)，cts(CompositionTime)的概念：

- pts：显示时间，也就是接收方在显示器显示这帧的时间。单位为1/90000 秒。
- dts：解码时间，也就是rtp包中传输的时间戳，表明解码的顺序。单位单位为1/90000 秒。----根据后面的理解，pts就是标准中的CompositionTime
- cts偏移：cts = (pts - dts) / 90 。cts的单位是毫秒。

pts和dts的时间不一样，应该只出现在含有B帧的情况下，也就是profile main以上。baseline是没有这个问题的，baseline的pts和dts一直想吐，所以cts一直为0。

在上图中，cp就是pts，显示时间。DT是解码时间，rtp的时戳。 I1是第一个帧，B2是第二个，后面的序号就是摄像头输出的顺序。决定了显示的顺序。 DT，是编码的顺序，特别是在有B帧的情况，P4要在第二个解，因为B2和B3依赖于P4，但是P4的显示要在B3之后，因为他的顺序靠后。这样就存在显示时间CT(PTS)和解码时间DT的差，就有了CT偏移。 P4解码时间是10，但是显示时间是40，

## AVCDecorderConfigurationRecord格式

AVCDecorderConfigurationRecord包括文件的信息，具体格式如下：

| 字段                   | 长度（bit） |
| -------------------- | ------- |
| cfgVersion           | 8       |
| avcProfile           | 8       |
| profileCompatibility | 8       |
| avcLevel             | 8       |
| reserved             | 6       |
| lengthSizeMinusOne   | 2       |
| reserved             | 3       |
| numOfSPS             | 5       |
| spsLength            | 16      |
| sps                  | n       |
| numOfPPS             | 8       |
| ppsLength            | 16      |
| pps                  | n       |

OK。对FLV文件结构的了解到这里，已经足够实现我们的需求了。

# nginx 模块的实现

我来讲一个每个需求的实现原理，实现细节有兴趣可以看一下[代码](https://github.com/liuhengloveyou/ngx_http_flv_filter_module/blob/master/ngx_http_flv_filter_module.c)。

1. 支持**start**/**end**

MP4文件的start/end一般是说的按时间偏移；但是在flv格式的视频文件上，各家厂商并没有一个标准，大多还是按文件内容偏移。在服务端要做的就是要按TAG的开头对齐，保证应答的数据还是格式正确，数据完整的FLV文件。

这就要求我们要找到start附近的那个tag，从那里开始吐应答数据。找到end附近的那个tag，在它之前结束吐应答数据。

2. **miss 拖拽**


就是说就算文件不在本机，也要能支持拖拽播放。放在nginx上，就是在upstream取数据的同时要解析flv文件格式，正确的处理start/end，并应答一个正确的重新打包过的FLV文件。

做法就是要在body_filter阶段过滤应答体，用chunk的方式吐数据。

3. **和proxy-cache一起工作** 

nginx的proxy-cache接管了content阶段，要在这里加自己的处理逻辑是很不方便的。所以我们只能在body_filter阶段介入处理。

这个地方， 我个人感觉nginx实现得好像并不那么高效。比如我们请求了一个1G的文件，start定到900M的地方。其实在conten/upstream时已经产生了1G的IO消耗，只是我们在body_filter阶段把前900M全丢了， 只向客户端应答了后面100M。原生的range模块也是这样的实现。

不知道是不是还有别的深层原因我还没有理解，我确实也没有那么多时间研究得那么细致。

哪位大神有空可以交流一下。:)