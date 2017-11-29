---
title: linux下用nc进行大文件跨网传输
comments: true
date: 2017-11-23 15:56:34
time: 1511423794
categories: shell
---

很多工作环境的机器是通过跳板机登录的，如果我们需要将一些大文件考到服务器上， 是比较麻烦的。

这种情况用nc传输文件就很方便。

## 1. 安装nc

多数linux发行版都默认安装了

```
 apt-get install netcat
```



## 2. 传输文件

目标机上打开监听：

```shell
# nc -l 23456 | tar xvzf -
```

 客户机上传输文件：

```shell
$ tar cvzf - /tmp/a | nc 1.1.1.1 23456
```

OK.