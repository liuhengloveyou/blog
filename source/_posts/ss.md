---
title: shell SS命令
comments: true
date: 2017-11-14 18:16:22
time: 1510654582
categories: shell
---

SS(Socket State)命令用于显示socket状态。可以代替netstat，速度会快很多。

## 常用ss命令

- **ss -l** 显示本地打开的所有端口
- **ss -pl** 显示每个进程具体打开的socket
- **ss -t -a** 显示所有tcp socket
- **ss -u -a** 显示所有的UDP Socekt
- **ss -o state established '( dport = :smtp or sport = :smtp )'** 显示所有已建立的SMTP连接
- **ss -o state established '( dport = :http or sport = :http )'** 显示所有已建立的HTTP连接
- **ss -x src /tmp/.X11-unix/* **找出所有连接X服务器的进程
- **ss -s** 列出当前socket详细信息


## 列出当前已经连接，关闭，等待的tcp连接

```shell
[admin@v035114 ~]$ ss -s 
Total: 89 (kernel 114)
TCP:   44 (estab 9, closed 23, orphaned 0, synrecv 0, timewait 22/0), ports 80

Transport Total     IP        IPv6
*         114       -         -        
RAW       0         0         0        
UDP       16        13        3        
TCP       21        17        4        
INET      37        30        7        
FRAG      0         0         0       
```

## 列出当前监听端口

```shell
$ ss -l  
Recv-Q Send-Q		Local Address:Port		Peer Address:Port     
0      0			127.0.0.1:15777			*:*         
```

## ss列出每个进程名及其监听的端口

```
# ss -pl
```

## ss列所有的tcp sockets

```
# ss -t -a
```

## ss列出所有udp sockets

```
# ss -u -a
```

## ss列出所有http连接中的连接

```
# ss -o state established '( dport = :http or sport = :http )' 
```
> 以上包含对外提供的80，以及访问外部的80
> 用以上命令完美的替代netstat获取http并发连接数，监控中常用到

## ss列出本地哪个进程连接到x server

```
# ss -x src /tmp/.X11-unix/*
```

## ss列出处在FIN-WAIT-1状态的http、https连接

```
# ss -o state fin-wait-1 '( sport = :http or sport = :https )'
```

## ss使用IP地址筛选

```shell
#ss src ADDRESS_PATTERN
// src：表示来源
// ADDRESS_PATTERN：表示地址规则 

如下：

// 列出来之20.33.31.1的连接
# ss src 120.33.31.1  

//列出来至120.33.31.1,80端口的连接
#ss src 120.33.31.1:http
#ss src 120.33.31.1:80
```

## ss使用端口筛选

```
# ss dport OP PORTOP
```

OP运算符如下：

- <= or le : 小于等于
- >= or ge : 大于等于
- == or eq : 等于
- != or ne : 不等于端口
- < or lt : 小于这个端口 
- > or gt : 大于端口

** OP实例 **

```
# ss sport = :http 
# ss sport = :80
# ss dport = :http
# ss dport > :1024
# ss sport > :1024
# ss sport < :32000
# ss sport eq :22
# ss dport != :22
# ss state connected sport = :http
# ss ( sport = :http or sport = :https )
# ss -o state fin-wait-1 ( sport = :http or sport = :https ) dst 192.168.1/24 
```

## 为什么ss比netstat快
netstat是遍历/proc下面每个PID目录，ss直接读/proc/net下面的统计信息。所以ss执行的时候消耗资源以及消耗的时间都比netstat少很多。