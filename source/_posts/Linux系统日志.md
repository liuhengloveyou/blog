---
title: Linux 系统日志
date: 2017-10-13 11:45:45
time: 1507866361
tags:
	- linux
	- log
categories: 性能调优
comments: true
---

一些最为重要的 Linux 系统日志包括：

- /var/log/syslog 或 /var/log/messages 存储所有的全局系统活动数据，包括开机信息。基于 Debian 的系统如 Ubuntu 在 /var/log/syslog 中存储它们，而基于 RedHat 的系统如 RHEL 或 CentOS 则在/var/log/messages 中存储它们。
- /var/log/auth.log 或 /var/log/secure 存储来自可插拔认证模块(PAM)的日志，包括成功的登录，失败的登录尝试和认证方式。Ubuntu 和 Debian 在 /var/log/auth.log 中存储认证信息，而 RedHat 和 CentOS 则在/var/log/secure 中存储该信息。
- /var/log/kern 存储内核的错误和警告数据，这对于排除与定制内核相关的故障尤为实用。
- /var/log/cron 存储有关 cron 作业的信息。使用这个数据来确保你的 cron 作业正成功地运行着。

Digital Ocean 有一个关于这些文件的完整教程，介绍了 rsyslog 如何在常见的发行版本如 RedHat 和 CentOS 中创建它们。

### 什么是 Syslog？

Linux 系统日志文件是如何创建的呢？答案是通过 syslog 守护程序，它在 syslog 套接字 /dev/log 上监听日志信息，然后将它们写入适当的日志文件中。

单词“syslog” 代表几个意思，并经常被用来简称如下的几个名称之一：

1. Syslog 守护进程；一个用来接收、处理和发送 syslog 信息的程序。它可以远程发送 syslog 到一个集中式的服务器或写入到一个本地文件。常见的例子包括 rsyslogd 和 syslog-ng。在这种使用方式中，人们常说“发送到 syslog”。
2. Syslog 协议；一个指定日志如何通过网络来传送的传输协议和一个针对 syslog 信息(具体见下文) 的数据格式的定义。它在 RFC-5424 中被正式定义。对于文本日志，标准的端口是 514，对于加密日志，端口是 6514。在这种使用方式中，人们常说“通过 syslog 传送”。
3. Syslog 信息；syslog 格式的日志信息或事件，它包括一个带有几个标准字段的消息头。在这种使用方式中，人们常说“发送 syslog”。

Syslog 信息或事件包括一个带有几个标准字段的消息头，可以使分析和路由更方便。它们包括时间戳、应用程序的名称、在系统中信息来源的分类或位置、以及事件的优先级。

下面展示的是一个包含 syslog 消息头的日志信息，它来自于控制着到该系统的远程登录的 sshd 守护进程，这个信息描述的是一次失败的登录尝试：

1. <34>1 2003-10-11T22:14:15.003Z server1.com sshd - - pam_unix(sshd:auth): authentication failure; logname= uid=0 euid=0 tty=ssh ruser= rhost=10.0.2.2

### Syslog 格式和字段

每条 syslog 信息包含一个带有字段的信息头，这些字段是结构化的数据，使得分析和路由事件更加容易。下面是我们使用的用来产生上面的 syslog 例子的格式，你可以将每个值匹配到一个特定的字段的名称上。

1. <%pri%>%protocol-version% %timestamp:::date-rfc3339% %HOSTNAME% %app-name% %procid% %msgid% %msg%n

下面，你将看到一些在查找或排错时最常使用的 syslog 字段：

#### 时间戳

时间戳 (上面的例子为 2003-10-11T22:14:15.003Z) 暗示了在系统中发送该信息的时间和日期。这个时间在另一系统上接收该信息时可能会有所不同。上面例子中的时间戳可以分解为：

- 2003-10-11 年，月，日。
- T 为时间戳的必需元素，它将日期和时间分隔开。
- 22:14:15.003 是 24 小时制的时间，包括进入下一秒的毫秒数(003)。
- Z 是一个可选元素，指的是 UTC 时间，除了 Z，这个例子还可以包括一个偏移量，例如 -08:00，这意味着时间从 UTC 偏移 8 小时，即 PST 时间。

#### 主机名

主机名 字段(在上面的例子中对应 server1.com) 指的是主机的名称或发送信息的系统.

#### 应用名

应用名 字段(在上面的例子中对应 sshd:auth) 指的是发送信息的程序的名称.

#### 优先级

优先级字段或缩写为 pri (在上面的例子中对应 ) 告诉我们这个事件有多紧急或多严峻。它由两个数字字段组成：设备字段和紧急性字段。紧急性字段从代表 debug 类事件的数字 7 一直到代表紧急事件的数字 0 。设备字段描述了哪个进程创建了该事件。它从代表内核信息的数字 0 到代表本地应用使用的 23 。

Pri 有两种输出方式。第一种是以一个单独的数字表示，可以这样计算：先用设备字段的值乘以 8，再加上紧急性字段的值：(设备字段)(8) + (紧急性字段)。第二种是 pri 文本，将以“设备字段.紧急性字段” 的字符串格式输出。后一种格式更方便阅读和搜索，但占据更多的存储空间。



Linux系统拥有非常灵活和强大的日志功能，可以保存几乎所有的操作记录，并可以从中检索出我们需要的信息。

大部分Linux发行版默认的日志守护进程为 syslog，位于 /etc/syslog 或 /etc/syslogd，默认配置文件为 /etc/syslog.conf，任何希望生成日志的程序都可以向 syslog 发送信息。 

Linux系统内核和许多程序会产生各种错误信息、警告信息和其他的提示信息，这些信息对管理员了解系统的运行状态是非常有用的，所以应该把它们写到日志文件中去。完成这个过程的程序就是syslog。syslog可以根据日志的类别和优先级将日志保存到不同的文件中。例如，为了方便查阅，可以把内核信息与其他信息分开，单独保存到一个独立的日志文件中。默认配置下，日志文件通常都保存在“/var/log”目录下。

### 日志类型

下面是常见的日志类型，但并不是所有的Linux发行版都包含这些类型：

| 类型            | 说明                                       |
| ------------- | ---------------------------------------- |
| auth          | 用户认证时产生的日志，如login命令、su命令。                |
| authpriv      | 与 auth 类似，但是只能被特定用户查看。                   |
| console       | 针对系统控制台的消息。                              |
| cron          | 系统定期执行计划任务时产生的日志。                        |
| daemon        | 某些守护进程产生的日志。                             |
| ftp           | FTP服务。                                   |
| kern          | 系统内核消息。                                  |
| local0.local7 | 由自定义程序使用。                                |
| lpr           | 与打印机活动有关。                                |
| mail          | 邮件日志。                                    |
| mark          | 产生时间戳。系统每隔一段时间向日志文件中输出当前时间，每行的格式类似于 May 26 11:17:09 rs2 -- MARK --，可以由此推断系统发生故障的大概时间。 |
| news          | 网络新闻传输协议(nntp)产生的消息。                     |
| ntp           | 网络时间协议(ntp)产生的消息。                        |
| user          | 用户进程。                                    |
| uucp          | UUCP子系统。                                 |

### 日志优先级

常见的日志优先级请见下标：

| 优先级     | 说明                            |
| ------- | ----------------------------- |
| emerg   | 紧急情况，系统不可用（例如系统崩溃），一般会通知所有用户。 |
| alert   | 需要立即修复，例如系统数据库损坏。             |
| crit    | 危险情况，例如硬盘错误，可能会阻碍程序的部分功能。     |
| err     | 一般错误消息。                       |
| warning | 警告。                           |
| notice  | 不是错误，但是可能需要处理。                |
| info    | 通用性消息，一般用来提供有用信息。             |
| debug   | 调试程序产生的信息。                    |
| none    | 没有优先级，不记录任何日志消息。              |

### 常见日志文件

所有的系统应用都会在 /var/log 目录下创建日志文件，或创建子目录再创建日志文件。例如：

| 文件/目录             | 说明                                      |
| ----------------- | --------------------------------------- |
| /var/log/boot.log | 开启或重启日志。                                |
| /var/log/cron     | 计划任务日志                                  |
| /var/log/maillog  | 邮件日志。                                   |
| /var/log/messages | 该日志文件是许多进程日志文件的汇总，从该文件可以看出任何入侵企图或成功的入侵。 |
| /var/log/httpd 目录 | Apache HTTP 服务日志。                       |
| /var/log/samba 目录 | samba 软件日志                              |

### /etc/syslog.conf 文件

/etc/syslog.conf 是 syslog 的配置文件，会根据日志类型和优先级来决定将日志保存到何处。典型的 syslog.conf 文件格式如下所示：

*.err;kern.debug;auth.notice /dev/console

daemon,auth.notice /var/log/messages

[lpr.info](http://lpr.info) /var/log/lpr.log

mail.* /var/log/mail.log

ftp.* /var/log/ftp.log

auth.* @see.[xidian.edu.cn](http://xidian.edu.cn)

auth.* root,amrood

netinfo.err /var/log/netinfo.log

install.* /var/log/install.log

*.emerg *

*.alert |program_name

mark.* /dev/console

第一列为日志类型和日志优先级的组合，每个类型和优先级的组合称为一个选择器；后面一列为保存日志的文件、服务器，或输出日志的终端。syslog 进程根据选择器决定如何操作日志。

对配置文件的几点说明：

- 日志类型和优先级由点号(.)分开，例如 kern.debug 表示由内核产生的调试信息。
- kern.debug 的优先级大于 debug。
- 星号(*)表示所有，例如 *.debug 表示所有类型的调试信息，kern.* 表示由内核产生的所有消息。
- 可以使用逗号(,)分隔多个日志类型，使用分号(;)分隔多个选择器。

对日志的操作包括：

- 将日志输出到文件，例如 /var/log/maillog 或 /dev/console。
- 将消息发送给用户，多个用户用逗号(,)分隔，例如 root, amrood。
- 通过管道将消息发送给用户程序，注意程序要放在管道符(|)后面。
- 将消息发送给其他主机上的 syslog 进程，这时 /etc/syslog.conf 文件后面一列为以@开头的主机名，例如@see.xidian.edu.cn。

### logger 命令

logger 是Shell命令，可以通过该命令使用 syslog 的系统日志模块，还可以从命令行直接向系统日志文件写入一行信息。

logger命令的语法为：

```
logger [-i] [-f filename] [-p priority] [-t tag] [message...]

```

每个选项的含义如下：

| 选项          | 说明                                       |
| ----------- | ---------------------------------------- |
| -f filename | 将 filename 文件的内容作为日志。                    |
| -i          | 每行都记录 logger 进程的ID。                      |
| -p priority | 指定优先级；优先级必须是形如 facility.priority 的完整的选择器，默认优先级为 user.notice。 |
| -t tag      | 使用指定的标签标记每一个记录行。                         |
| message     | 要写入的日志内容，多条日志以空格为分隔；如果没有指定日志内容，并且 -f filename 选项为空，那么会把标准输入作为日志内容。 |

例如，将ping命令的结果写入日志：

$ ping 192.168.0.1 | logger -it logger_test -p local3.notice&

$ tail -f /var/log/userlog

Oct 6 12:48:43 kevein logger_test[22484]: PING 192.168.0.1 (192.168.0.1) 56(84) bytes of data.

Oct 6 12:48:43 kevein logger_test[22484]: 64 bytes from 192.168.0.1: icmp_seq=1 ttl=253 time=49.7 ms

Oct 6 12:48:44 kevein logger_test[22484]: 64 bytes from 192.168.0.1: icmp_seq=2 ttl=253 time=68.4 ms

Oct 6 12:48:45 kevein logger_test[22484]: 64 bytes from 192.168.0.1: icmp_seq=3 ttl=253 time=315 ms

Oct 6 12:48:46 kevein logger_test[22484]: 64 bytes from 192.168.0.1: icmp_seq=4 ttl=253 time=279 ms

Oct 6 12:48:47 kevein logger_test[22484]: 64 bytes from 192.168.0.1: icmp_seq=5 ttl=253 time=347 ms

Oct 6 12:48:49 kevein logger_test[22484]: 64 bytes from 192.168.0.1: icmp_seq=6 ttl=253 time=701 ms

Oct 6 12:48:50 kevein logger_test[22484]: 64 bytes from 192.168.0.1: icmp_seq=7 ttl=253 time=591 ms

Oct 6 12:48:51 kevein logger_test[22484]: 64 bytes from 192.168.0.1: icmp_seq=8 ttl=253 time=592 ms

Oct 6 12:48:52 kevein logger_test[22484]: 64 bytes from 192.168.0.1: icmp_seq=9 ttl=253 time=611 ms

Oct 6 12:48:53 kevein logger_test[22484]: 64 bytes from 192.168.0.1: icmp_seq=10 ttl=253 time=931 ms

ping命令的结果成功输出到 /var/log/userlog 文件。

命令 logger -it logger_test -p local3.notice 各选项的含义：

- -i：在每行都记录进程ID；
- -t logger_test：每行记录都加上“logger_test”这个标签；
- -p local3.notice：设置日志类型和优先级。

### 日志转储

日志转储也叫日志回卷或日志轮转。Linux中的日志通常增长很快，会占用大量硬盘空间，需要在日志文件达到指定大小时分开存储。

syslog 只负责接收日志并保存到相应的文件，但不会对日志文件进行管理，因此经常会造成日志文件过大，尤其是WEB服务器，轻易就能超过1G，给检索带来困难。

大多数Linux发行版使用 logrotate 或 newsyslog 对日志进行管理。logrotate 程序不但可以压缩日志文件，减少存储空间，还可以将日志发送到指定 E-mail，方便管理员及时查看日志。

例如，规定邮件日志 /var/log/maillog 超过1G时转储，每周一次，那么每隔一周 logrotate 进程就会检查 /var/log/maillog 文件的大小：

- 如果没有超过1G，不进行任何操作。
- 如果在1G~2G之间，就会创建新文件 /var/log/maillog.1，并将多出的1G日志转移到该文件，以给 /var/log/maillog 文件瘦身。
- 如果在2G~3G之间，会继续创建新文件 /var/log/maillog.2，并将 /var/log/maillog.1 的内容转移到该文件，将 /var/log/maillog 的内容转移到 /var/log/maillog.1，以保持 /var/log/maillog 文件不超过1G。

可以看到，每次转存都会创建一个新文件（如果不存在），命名格式为日志文件名加一个数字（从1开始自动增长），以保持当前日志文件和转存后的日志文件不超过指定大小。

logrotate 的主要配置文件是 /etc/logrotate.conf，/etc/logrotate.d 目录是对 /etc/logrotate.conf 的补充，或者说为了不使 /etc/logrotate.conf 过大而设置。

可以通过 cat 命令查看它的内容：

$cat /etc/logrotate.conf

\# see "man logrotate" for details //可以查看帮助文档

\# rotate log files weekly

weekly //设置每周转储一次

\# keep 4 weeks worth of backlogs

rotate 4 //最多转储4次

\# create new (empty) log files after rotating old ones

create //当转储后文件不存储时创建它

\# uncomment this if you want your log files compressed

\#compress //以压缩方式转储

\# RPM packages drop log rotation information into this directory

include /etc/logrotate.d //其他日志文件的转储方式，包含在该目录下

\# no packages own wtmp -- we'll rotate them here

/var/log/wtmp { //设置/var/log/wtmp日志文件的转储参数

monthly //每月转储

create 0664 root utmp //转储后文件不存在时创建它，文件所有者为root，所属组为utmp，对应的权限为0664

rotate 1 //最多转储一次

}

注意：include 允许管理员把多个分散的文件集中到一个，类似于C语言的 #include，将其他文件的内容包含进当前文件。

include 非常有用，一些程序会把转储日志的配置文件放在 /etc/logrotate.d 目录，这些配置文件会覆盖或增加 /etc/logrotate.conf 的配置项，如果没有指定相关配置，那么采用 /etc/logrotate.conf 的默认配置。

所以，建议将 /etc/logrotate.conf 作为默认配置文件，第三方程序在 /etc/logrotate.d 目录下自定义配置文件。

logrotate 也可以作为命令直接运行来修改配置文件。
