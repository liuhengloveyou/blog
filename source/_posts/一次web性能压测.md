---
title: 一次HTTPS性能压测
comments: true
date: 2018-01-18 15:50:28
time: 1516261828
tags:
categories:
---

压测一下https的性能表现，同时跟同一服务器上的http服务作对比。

试验了多次后， 我选择[hey](https://github.com/rakyll/hey)作为压测工具，这是一个用golang实现的压测工具。与ab， siege这些比较，结果显示看起来更友好， 性能好像也更强一些。现在碰到的问题是不支持https的会话复用。

## 安装hey

```
go get -u github.com/liuhengloveyou/hey
```

## hey使用

```
Usage: hey [options...] <url>

Options:
  -n  Number of requests to run. Default is 200.
  -c  Number of requests to run concurrently. Total number of requests cannot
      be smaller than the concurrency level. Default is 50.
  -q  Rate limit, in queries per second (QPS). Default is no rate limit.
  -z  Duration of application to send requests. When duration is reached,
      application stops and exits. If duration is specified, n is ignored.
      Examples: -z 10s -z 3m.
  -o  Output type. If none provided, a summary is printed.
      "csv" is the only supported alternative. Dumps the response
      metrics in comma-separated values format.

  -m  HTTP method, one of GET, POST, PUT, DELETE, HEAD, OPTIONS.
  -H  Custom HTTP header. You can specify as many as needed by repeating the flag.
      For example, -H "Accept: text/html" -H "Content-Type: application/xml" .
  -t  Timeout for each request in seconds. Default is 20, use 0 for infinite.
  -A  HTTP Accept header.
  -d  HTTP request body.
  -D  HTTP request body from file. For example, /home/user/file.txt or ./file.txt.
  -T  Content-type, defaults to "text/html".
  -a  Basic authentication, username:password.
  -x  HTTP Proxy address as host:port.
  -h2 Enable HTTP/2.

  -host	HTTP Host header.

  -disable-compression  Disable compression.
  -disable-keepalive    Disable keep-alive, prevents re-use of TCP
                        connections between different HTTP requests.
  -disable-redirects    Disable following of HTTP redirects
  -cpus                 Number of used cpu cores.
                        (default for current machine is 8 cores)

```

## hey示例

```
$ hey -c 100 -n 1000 http://www.test.com
Summary:
  Total:	0.5574 secs
  Slowest:	0.1128 secs
  Fastest:	0.0410 secs
  Average:	0.0535 secs
  Requests/sec:	1793.9866

Response time histogram:
  0.041 [1]	|
  0.048 [445]	|∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎
  0.055 [432]	|∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎∎
  0.063 [22]	|∎∎
  0.070 [0]	|
  0.077 [0]	|
  0.084 [0]	|
  0.091 [4]	|
  0.098 [11]	|∎
  0.106 [53]	|∎∎∎∎∎
  0.113 [32]	|∎∎∎

Latency distribution:
  10% in 0.0440 secs
  25% in 0.0455 secs
  50% in 0.0485 secs
  75% in 0.0509 secs
  90% in 0.0883 secs
  95% in 0.1028 secs
  99% in 0.1117 secs

Details (average, fastest, slowest):
  DNS+dialup:	 0.0052 secs, 0.0000 secs, 0.0611 secs
  DNS-lookup:	 0.0003 secs, 0.0000 secs, 0.0060 secs
  req write:	 0.0001 secs, 0.0000 secs, 0.0016 secs
  resp wait:	 0.0480 secs, 0.0407 secs, 0.0604 secs
  resp read:	 0.0001 secs, 0.0000 secs, 0.0032 secs

Status code distribution:
  [200]	1000 responses

```

比较简单， 各免费的web压测工具都差不多。

然后， 我们还要收集服务器的性能指标。我选择[nmon](http://nmon.sourceforge.net/pmwiki.php?n=Main.HomePage)。

## 安装nmon

nmon发布的是一个已编译的可执行程序。到[下载页](http://nmon.sourceforge.net/pmwiki.php?n=Site.Download)下载自己系统对应的版本就行了。可以把它放到 /usr/local/bin/下方便使用。

## nmon使用

直接运行是一个交互界面， 可以看到实时的性能指标：

**启动界面如下：**

![nmon](http://nmon.sourceforge.net/docs/nmon16a_flash_631.gif)

**帮助界面如下：**

![nmon](http://nmon.sourceforge.net/docs/nmon16a_Help_600.gif)

然后想看什么， 按相应的键就可以了。 比如 c 显示CPU信息， m 显示内存信息。可以同时显示多种指标在同一个界面上。



## 生成性能报告

1. 采集数据：

```
$ nmon -f -t -U -s 3 -c 700
```
-  -f 生成的数据文件名中包含文件创建的时间。
-  -t 包含最忙进程的状态。
-  -s 10 每 10 秒采集一次数据。
-  -c 60 采集 60 次，即为采集35分钟的数据。
-  -m 生成的数据文件的存放目录。

这样就会生成一个 nmon 报告文件，每3秒更新一次，总共采集30分钟数据。每一组数据类似这样：

```
ZZZZ,T0016,16:55:47,18-JAN-2018
CPU001,T0016,16.2,17.3,0.0,66.5,0.0
CPU002,T0016,20.5,26.2,0.0,53.3,0.0
CPU003,T0016,15.2,15.2,0.0,69.5,0.0
CPU004,T0016,3.0,1.5,0.0,95.5,0.0
CPU005,T0016,14.7,15.2,0.0,70.1,0.0
CPU006,T0016,16.6,17.6,0.0,65.8,0.0
CPU007,T0016,13.3,14.8,0.0,71.9,0.0
CPU008,T0016,12.6,13.1,0.0,74.2,0.0
CPU_ALL,T0016,14.1,15.1,0.0,70.9,0.0,,8
MEM,T0016,7842.2,-0.0,-0.0,8192.0,1123.7,-0.0,-0.0,8192.0,-0.0,5543.7,1731.4,-1.0,301.1,0.0,4549.3
VM,T0016,38372,0,0,1208,3246,-1,0,0,0,0,5436,195,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
PROC,T0016,5,0,88200.0,-1.0,-1.0,-1.0,0.0,-1.0,-1.0,-1.0
NET,T0016,0.0,14553.5,1.9,0.0,14897.9,1.2
NETPACKET,T0016,0.0,119344.5,27.5,0.0,63307.6,6.5
JFSFILE,T0016,21.4,6.0,0.2
DISKBUSY,T0016,0.0,0.0,0.0,0.0,0.0
DISKREAD,T0016,0.0,0.0,0.0,0.0,0.0
DISKWRITE,T0016,0.0,0.0,0.0,0.0,0.0
DISKXFER,T0016,0.0,0.0,0.0,0.0,0.0
DISKBSIZE,T0016,0.0,0.0,0.0,0.0,0.0
```

2. 生成图表

nmon项目提供了[nmonchart](http://nmon.sourceforge.net/pmwiki.php?n=Site.Nmonchart)，可以把nmon的报告生成为html图表。它是一个ksh脚本， centos默认可能需要安装ksh：

```
 yum install ksh
```

用法如下：

```
$ nmonchart nmon_file html_file
	nmon_file       1st parameter is the nmon capatured data file like
	html_file       2nd parameter is the output file on your website directory like

例如:
	nmonchart mynmonfile.nmon /webpages/docs/mycharts.html
```



## 测试结果

由于HTTPS是CPU消耗型，我们可以在CPU占满的情况下对比各项指标：

CPU:

```
服务器：Intel(R) Xeon(R) CPU E3-1230 V2 @ 3.30GHz 8核
客户机：Intel(R) Xeon(R) CPU E3-1231 v3 @ 3.40GHz 8核
```

TLS相关配置：

```nginx
ssl_protocols TLSv1.2;
ssl_ciphers ECDHE-RSA-AES256-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4;
```

```
hey 
```



关闭keepalive, 在硬件资源允许的情况下压到最大并发，并保证没有请求失败的情况发生连续压测10分钟。数据如下：

|                       | 并发    | 平均延时   | qps   | cpu%  User/Sys |
| --------------------- | ----- | ------ | ----- | -------------- |
| http                  | 20000 | ~ 0.35 | 34464 | ~ 10/40        |
| https                 | 400   | ~ 0.75 | 2683  | ~ 96/4         |
| https session tickets | 10000 | ~ 0.78 | 21188 | ~ 50/25        |

> **单台客户机并不能通过http给服务器CPU压力**，压到20000并发时服务器CPU占用不到50%。无可比性， 作为参考。
>
> **单台客户机也不能通过开启session tickets的httpss给服务器CPU太大压力**，压到10000并发时客户机CPU占用75/20
