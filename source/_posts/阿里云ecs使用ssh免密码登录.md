---
title: 阿里云ecs使用ssh免密码登录
comments: true
date: 2018-06-21 22:10:00
time: 1529590200
tags:
categories: 其它
---

## 1. 阿里云控制台生成密钥对并绑定服务器

登录阿里云控制台，找到云服务器ecs > 网络安全 > 密钥对。创建密钥对绑定对应服务器。然后在ecs控制台重启服务器实例。

## 2. 本地linux/mac机配置

创建密钥对时会自动下载一个pem文件到本地，将pem文件放入本地~/.ssh/ 目录下，给600权限: `chmod 600 ~/.ssh/x.pem`；
给服务器上的.ssh目录700权限，以及.ssh/authorized_keys  600权限

## 3. 本地ssh连接

```
ssh -i ~/.ssh/key0.pem root@47.91.238.107
```

## 4. windows 机配置

1. 如果使用的secureCRT不支持.pem 文件的话，需要把公钥转成.pub文件，找台linux 服务器，生成公密钥 .pub 文件：

```
ssh-keygen -e -f key.pem >> key.pem.pub
```
2. 把生成的.pub文件放在本地user/.ssh目录下
3. 使用secureCRT登录，登录时会弹框选择加载.pub文件即可

 

 

 

 

 