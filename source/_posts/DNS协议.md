---
title: DNS协议详解
comments: true
date: 2018-08-09 16:56:31
time: 1533805131
tags:
categories: 网络
---



[TOC]

## 一. DNS是啥

关于DNS是啥，它是Domain Name System的简写，中文翻译过来就是域名系统，是用来将主机名转换为ip的。事实上，除了进行主机名到IP地址的转换外，DNS通常还提供主机名到以下几项的转换服务：

**主机命名（host aloasing）**有着复杂规范主机名（canonical hostname）的主机可能有一个或多个别名，通常规范主机名较复杂，而别名让人更容易记忆。应用程序可以调用DNS来获得主机别名对应的规范主机名，以及主机的ip地址。

**邮件服务器别名（mail server aliasing）**DNS也能完成邮件服务器别名到其规范主机名以及ip地址的转换。

**负载均衡（load distribution）**DNS可用于冗余的服务器之间进行负载均衡。一个繁忙的站点，如abc.com，可能被冗余部署在多台具有不同ip的服务器上。在该情况下，在DNS数据库中，该主机名可能对应着一个ip集合，但应用程序调用DNS来获取该主机名对应的ip时，DNS通过某种算法从该主机名对应的ip集合中，挑选出某一ip进行响应。

## 二. DNS的分布式架构

先来了解DNS的分布式架构。

DNS服务器根据域名命名空间（domian name space）组织成如下图所示的树形结构（当然，只给出部分DNS服务器，只为显示出DNS服务器的层次结构）：

![dns 架构](http://ojapxw8c8.bkt.clouddn.com/%E9%80%89%E5%8C%BA_010.jpg)

在图中，根节点代表的是根DNS服务器，因特网上共有13台，编号从A到M；根DNS服务器之下的一层被称为顶级DNS服务器；再往下一层被称为权威DNS服务器。

当一个应用要通过DNS来查询某个主机名，比如 www.0x7c00.net 的ip时，粗略地说，查询过程是这样的：
1. 它先与根服务器之一联系，根服务器根据顶级域名net，会响应命名空间为net的顶级域服务器的ip
2. 于是该应用接着向net顶级域服务器发出请求，net顶级域服务器会响应命名空间为0x7c00.net的权威DNS服务器的ip地址
3. 最后该应用将请求命名空间为0x7c00.net的权威DNS服务器，该权威DNS服务器会响应主机名为www.0x7c00.net 的ip。

实际上除了上图层次结构中所展示的DNS外，还有一类与我们接触更为密切的DNS服务器，它们是Local DNS服务器。我们经常在电脑上配置的DNS服务器通常就是此类。它们一般由某公司，某大学，或电信运营商提供，比如Google提供的DNS服务器8.8.8.8；比如常被人诟病的114.114.114.114等。

加入了本地DNS的查询过程跟之前的查询过程基本上是一致的，查询流程如下图所示：

![local dns](http://ojapxw8c8.bkt.clouddn.com/%E9%80%89%E5%8C%BA_011.jpg)



在实际工作中，DNS服务器是带缓存的。即DNS服务器在每次收到DNS请求时，都会先查询自身数据库包括缓存中有无要查询的主机名的ip，若有且没有过期(TTL)，则直接响应该ip，否则才会按上图流程进行查询；而服务器在每次收到响应信息后，都会将响应信息缓存起来；



## 三. 用dig命令理解DNS解析过程

每一台正常上网的电脑都需要配置当前网络的DNS服务器地址(/etc/resolv.conf)，这里配置的DNS叫本地DNS，实际的域名解析流程，大半工作是由它代理我们的电脑做的。上面有简单描述解析过程，

我们也可以用dig命令直观的看到这个过程：

```
$ dig +trace www.10zan.net

; <<>> DiG 9.10.6 <<>> +trace www.10zan.net
;; global options: +cmd
.			36249	IN	NS	k.root-servers.net.
.			36249	IN	NS	d.root-servers.net.
.			36249	IN	NS	h.root-servers.net.
.			36249	IN	NS	e.root-servers.net.
.			36249	IN	NS	f.root-servers.net.
.			36249	IN	NS	l.root-servers.net.
.			36249	IN	NS	c.root-servers.net.
.			36249	IN	NS	j.root-servers.net.
.			36249	IN	NS	g.root-servers.net.
.			36249	IN	NS	m.root-servers.net.
.			36249	IN	NS	b.root-servers.net.
.			36249	IN	NS	a.root-servers.net.
.			36249	IN	NS	i.root-servers.net.
;; Received 407 bytes from 172.26.9.10#53(172.26.9.10) in 2 ms

net.			172800	IN	NS	a.gtld-servers.net.
net.			172800	IN	NS	b.gtld-servers.net.
net.			172800	IN	NS	c.gtld-servers.net.
net.			172800	IN	NS	d.gtld-servers.net.
net.			172800	IN	NS	e.gtld-servers.net.
net.			172800	IN	NS	f.gtld-servers.net.
net.			172800	IN	NS	g.gtld-servers.net.
net.			172800	IN	NS	h.gtld-servers.net.
net.			172800	IN	NS	i.gtld-servers.net.
net.			172800	IN	NS	j.gtld-servers.net.
net.			172800	IN	NS	k.gtld-servers.net.
net.			172800	IN	NS	l.gtld-servers.net.
net.			172800	IN	NS	m.gtld-servers.net.
net.			86400	IN	DS	35886 8 2 7862B27F5F516EBE19680444D4CE5E762981931842C465F00236401D 8BD973EE
net.			86400	IN	RRSIG	DS 8 1 86400 20180822050000 20180809040000 41656 . BjEcl81akeespTpeBbAzXHRt650nPhdfNwUSDGtcoigd+kLm3xx6spQ8 7ok1ZvRloYZ06yb7B4j9V9zau4egbNkYvyZbjwmdZdoUj25PQZUbfdBN ALIOSKeLS+Nm9YY9LzUaTaDT/H1KhCjPIINEusNAbChxJSA3sPspwpVR SWyazHEv6zMpZDJ6+PV2dl/1Byeb3s6Wj7cgkxx2G8T3AmpujZbBCeMK nDlKQTH2tJIXrUdJfz+ejjRg2gJdt7NJ0PuNA3t2p3V/WCEhuDCULBBt DfSiSUOHmvzVVvLY78A9MvrMIUZlaFIm9TRQWHOIMtXKHPM32tXto7ZV zLvugA==
;; Received 1170 bytes from 199.7.91.13#53(d.root-servers.net) in 46 ms

10zan.net.		172800	IN	NS	f1g1ns1.dnspod.net.
10zan.net.		172800	IN	NS	f1g1ns2.dnspod.net.
;; Received 738 bytes from 192.26.92.30#53(c.gtld-servers.net) in 12 ms

www.10zan.net.		600	IN	A	47.91.238.107
10zan.net.		86400	IN	NS	f1g1ns2.dnspod.net.
10zan.net.		86400	IN	NS	f1g1ns1.dnspod.net.
;; Received 124 bytes from 180.163.19.15#53(f1g1ns1.dnspod.net) in 31 ms


```

从dig +trace我们可以很清晰的看到一个域名解析的过程：

1. 第一部分最左边的`.`就代表是root DNS服务器的记录，下面的`;; Received...`显示为本机服务的DNS，说明这些root服务器的信息是由直接为本机服务的DNS提供的。
2. 第二部分是由199.7.91.13--其中一个root DNS的IP地址回应的消息，`net.`表示是`net.`域的DNS服务器，也就是root DNS告诉我们要到`net.`域去找。
3. 第三部分是由192.26.92.30--其中一个net. DNS的IP地址回应的消息，`10zan.net.`表示已经查到我们要查的域名了，这里告诉下一步去dnspod去查，因为10zan.net是在dnspod解析的。
4. 到了最后一部分，由f1g1ns1.dnspod.net告诉我们，这个10zan.net网址的IP地址是47.91.238.107(A记录)，权威DNSf1g1ns2.dnspod.net(NS)，到此一次域名解析就结束了。

其实dig命令更简单的用法是

```
$ dig www.10zan.net

; <<>> DiG 9.10.6 <<>> www.10zan.net
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 1222
;; flags: qr rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 13, ADDITIONAL: 27

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;www.10zan.net.			IN	A

;; ANSWER SECTION:
www.10zan.net.		600	IN	A	47.91.238.107

;; AUTHORITY SECTION:
net.			24897	IN	NS	i.gtld-servers.net.
net.			24897	IN	NS	j.gtld-servers.net.

;; ADDITIONAL SECTION:
a.gtld-servers.net.	14668	IN	A	192.5.6.30
a.gtld-servers.net.	52110	IN	AAAA	2001:503:a83e::2:30

;; Query time: 194 msec
;; SERVER: 172.26.9.10#53(172.26.9.10)
;; WHEN: Thu Aug 09 17:55:22 CST 2018
;; MSG SIZE  rcvd: 851
```

开头是一些统计信息，可以不用管，我们看一看后面的段：

- QUESTION SECTION		这部分是提问，显示你要查询的域名 
- ANSWER SECTION 		即答案，显示查询到的域名对应的IP 
-  AUTHORITY SECTION		这部分显示的是直接提供这个域名解析的DNS服务器，不包括更高级DNS服务器 
-  ADDITIONAL SECTION	这部分显示的是这些直接提供解析的服务器的IP地址 
- 最后面的是一些统计信息，其中SERVER指的是直接为你服务的本地DNS服务器的IP。

在上面的dig命令我们可以看到，在解析一个域名的时候，往往会发现有多个DNS服务器提供解析服务，这是因为DNS服务器要求一般至少有两个，以防发生服务器宕机无法提供域名解析的情况。那么多个服务器，谁来响应这个DNS请求呢？这就要看服务器管理者怎么设置各个服务器的主从关系（Master-Slave）了，通过dig命令也可以查看DNS服务器的主从关系。

```
$ dig -t soa www.10zan.net

; <<>> DiG 9.10.6 <<>> -t soa www.10zan.net
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 16645
;; flags: qr rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;www.10zan.net.			IN	SOA

;; AUTHORITY SECTION:
10zan.net.		600	IN	SOA	f1g1ns1.dnspod.net. freednsadmin.dnspod.com. 1533644244 3600 180 1209600 180

;; Query time: 356 msec
;; SERVER: 172.26.9.10#53(172.26.9.10)
;; WHEN: Thu Aug 09 17:58:59 CST 2018
;; MSG SIZE  rcvd: 116

```

SOA是start of authority的简称，提供了DNS主服务器的相关信息，在AUTHORITY SECTION 下面的SOA之后我们可以看到7个参数，依次是： 

1. DNS主服务器名 
2. 管理员的E-mail，这里是 freednsadmin.dnspod.com ，由于@在数据库文件里有特殊作用，所以这里是用.代替
3. 更新序号。表示数据库文件的新旧，一般是用时间戳来表示
4. 更新频率。 表示每3600秒，slave服务器就要向master服务器索取更新信息。 
5. 失败重试时间，当某些原因导致Slave服务器无法向master服务器索取信息时，会隔180秒就重试一次。 
6. 失效时间。如果一直重试失败，当重试时间累积达到1209600秒时，不再向主服务器索取信息。 
7. 缓存时间。默认的TTL缓存时间。



## 四. 协议细节

### 1 DNS资源记录

在介绍DNS层协议之前，先了解一下DNS服务器存储的资源记录（Resource Records，RRs），一条资源记录(RR)记载着一个映射关系。每条RR通常包含如下表所示的一些信息：

| 字段     | 含义              |
| -------- | ----------------- |
| NAME     | 名字              |
| TYPE     | 类型              |
| CLASS    | 类                |
| TTL      | 生存时间          |
| RDLENGTH | RDATA所占的字节数 |
| RDATA    | 数据              |

NAME和RDATA表示的含义根据TYPE的取值不同而不同，常见的：

- 若TYPE=A，则name是主机名，value是其对应的ip
- 若TYPE=NS，则name是一个域，value是一个权威DNS服务器的主机名。该记录表示name域的域名解析将由value主机名对应的DNS服务器来做
- 若TYPE=CNAME，则value是别名为name的主机对应的规范主机名
- 若TYPE=MX，则value是别名为name的邮件服务器的规范主机名
- … …

TYPE实际上还有其他类型，所有可能的type及其约定的数值表示如下：

### 2. 记录类型

| 代码                                                         | 号码  | 定义的 RFC                                                   | 描述                                                         | 功能                                                         |
| ------------------------------------------------------------ | ----- | ------------------------------------------------------------ | ------------------------------------------------------------ | ------------------------------------------------------------ |
| A                                                            | 1     | [RFC 1035](https://tools.ietf.org/html/rfc1035)              | IP 地址记录                                                  | 传回一个 32 比特的 [IPv4](https://zh.wikipedia.org/wiki/IPv4) 地址，最常用于映射[主机名称](https://zh.wikipedia.org/wiki/%E4%B8%BB%E6%A9%9F%E5%90%8D%E7%A8%B1)到 [IP地址](https://zh.wikipedia.org/wiki/IP%E5%9C%B0%E5%9D%80)，但也用于[DNSBL](https://zh.wikipedia.org/w/index.php?title=DNSBL&action=edit&redlink=1)（[RFC 1101](https://tools.ietf.org/html/rfc1101)）等。 |
| AAAA                                                         | 28    | [RFC 3596](https://tools.ietf.org/html/rfc3596)              | [IPv6](https://zh.wikipedia.org/wiki/IPv6) IP 地址记录       | 传回一个 128 比特的 IPv6 地址，最常用于映射主机名称到 IP 地址。 |
| AFSDB                                                        | 18    | [RFC 1183](https://tools.ietf.org/html/rfc1183)              | [AFS文件系统](https://zh.wikipedia.org/w/index.php?title=AFS%E6%AA%94%E6%A1%88%E7%B3%BB%E7%B5%B1&action=edit&redlink=1) | （Andrew File System）数据库核心的位置，于域名以外的 AFS 客户端常用来联系 AFS 核心。这个记录的子类型是被过时的的 [DCE/DFS](https://zh.wikipedia.org/wiki/DCE/DFS)（DCE Distributed File System）所使用。 |
| APL                                                          | 42    | [RFC 3123](https://tools.ietf.org/html/rfc3123)              | 地址前缀列表                                                 | 指定地址列表的范围，例如：CIDR 格式为各个类型的地址（试验性）。 |
| CERT                                                         | 37    | [RFC 4398](https://tools.ietf.org/html/rfc4398)              | 证书记录                                                     | 存储 [PKIX](https://zh.wikipedia.org/wiki/PKIX)、[SPKI](https://zh.wikipedia.org/w/index.php?title=SPKI&action=edit&redlink=1)、[PGP](https://zh.wikipedia.org/wiki/Pretty_Good_Privacy)等。 |
| [CNAME](https://zh.wikipedia.org/w/index.php?title=CNAME_%E8%A8%98%E9%8C%84&action=edit&redlink=1) | 5     | [RFC 1035](https://tools.ietf.org/html/rfc1035)              | 规范名称记录                                                 | 一个主机名字的别名：[域名系统](https://zh.wikipedia.org/wiki/DNS)将会继续尝试查找新的名字。 |
| DHCID                                                        | 49    | [RFC 4701](https://tools.ietf.org/html/rfc4701)              | [DHCP](https://zh.wikipedia.org/wiki/DHCP)（动态主机设置协议）识别码 | 用于将 FQDN 选项结合至 [DHCP](https://zh.wikipedia.org/wiki/DHCP)。 |
| DLV                                                          | 32769 | [RFC 4431](https://tools.ietf.org/html/rfc4431)              | [DNSSEC](https://zh.wikipedia.org/wiki/DNSSEC)（域名系统安全扩展）来源验证记录 | 为不在DNS委托者内发布DNSSEC的信任锚点，与 DS 记录使用相同的格式，[RFC 5074](https://tools.ietf.org/html/rfc5074)介绍了如何使用这些记录。 |
| [DNAME](https://zh.wikipedia.org/w/index.php?title=DNAME_%E8%A8%98%E9%8C%84&action=edit&redlink=1) | 39    | [RFC 2672](https://tools.ietf.org/html/rfc2672)              | 代表名称                                                     | DNAME 会为名称和其子名称产生别名，与 CNAME 不同，在其标签别名不会重复。但与 CNAME 记录相同的是，DNS将会继续尝试查找新的名字。 |
| DNSKEY                                                       | 48    | [RFC 4034](https://tools.ietf.org/html/rfc4034)              | DNS 关键记录                                                 | 于DNSSEC内使用的关键记录，与 KEY 使用相同格式。              |
| DS                                                           | 43    | [RFC 4034](https://tools.ietf.org/html/rfc4034)              | 委托签发者                                                   | 此记录用于鉴定DNSSEC已授权区域的签名密钥。                   |
| HIP                                                          | 55    | [RFC 5205](https://tools.ietf.org/html/rfc5205)              | 主机鉴定协议                                                 | 将端点标识符及IP 地址定位的分开的方法。                      |
| IPSECKEY                                                     | 45    | [RFC 4025](https://tools.ietf.org/html/rfc4025)              | IPSEC 密钥                                                   | 与 [IPSEC](https://zh.wikipedia.org/wiki/IPSEC) 同时使用的密钥记录。 |
| KEY                                                          | 25    | [RFC 2535](https://tools.ietf.org/html/rfc2535)[[1\]](https://zh.wikipedia.org/wiki/%E5%9F%9F%E5%90%8D%E4%BC%BA%E6%9C%8D%E5%99%A8%E8%A8%98%E9%8C%84%E9%A1%9E%E5%9E%8B%E5%88%97%E8%A1%A8#cite_note-1)[RFC 2930](https://tools.ietf.org/html/rfc2930)[[2\]](https://zh.wikipedia.org/wiki/%E5%9F%9F%E5%90%8D%E4%BC%BA%E6%9C%8D%E5%99%A8%E8%A8%98%E9%8C%84%E9%A1%9E%E5%9E%8B%E5%88%97%E8%A1%A8#cite_note-rfc3445_sec1_def-2) | 关键记录                                                     | 只用于 SIG(0)（[RFC 2931](https://tools.ietf.org/html/rfc2931)）及 TKEY（[RFC 2930](https://tools.ietf.org/html/rfc2930)）。[[3\]](https://zh.wikipedia.org/wiki/%E5%9F%9F%E5%90%8D%E4%BC%BA%E6%9C%8D%E5%99%A8%E8%A8%98%E9%8C%84%E9%A1%9E%E5%9E%8B%E5%88%97%E8%A1%A8#cite_note-3)[RFC 3455](https://tools.ietf.org/html/rfc3455) 否定其作为应用程序键及限制DNSSEC的使用。[[4\]](https://zh.wikipedia.org/wiki/%E5%9F%9F%E5%90%8D%E4%BC%BA%E6%9C%8D%E5%99%A8%E8%A8%98%E9%8C%84%E9%A1%9E%E5%9E%8B%E5%88%97%E8%A1%A8#cite_note-rfc3445_sec1_subtype-4)[RFC 3755](https://tools.ietf.org/html/rfc3755) 指定了 DNSKEY 作为DNSSEC的代替。[[5\]](https://zh.wikipedia.org/wiki/%E5%9F%9F%E5%90%8D%E4%BC%BA%E6%9C%8D%E5%99%A8%E8%A8%98%E9%8C%84%E9%A1%9E%E5%9E%8B%E5%88%97%E8%A1%A8#cite_note-rfc3755_sec3-5) |
| [LOC记录](https://zh.wikipedia.org/w/index.php?title=LOC%E8%A8%98%E9%8C%84&action=edit&redlink=1)（LOC record） | 29    | [RFC 1876](https://tools.ietf.org/html/rfc1876)              | 位置记录                                                     | 将一个域名指定地理位置。                                     |
| [MX记录](https://zh.wikipedia.org/w/index.php?title=MX%E8%A8%98%E9%8C%84&action=edit&redlink=1)（MX record） | 15    | [RFC 1035](https://tools.ietf.org/html/rfc1035)              | 电邮交互记录                                                 | 引导域名到该域名的[邮件传输代理](https://zh.wikipedia.org/w/index.php?title=%E9%83%B5%E4%BB%B6%E5%82%B3%E8%BC%B8%E4%BB%A3%E7%90%86&action=edit&redlink=1)（MTA, Message Transfer Agents）列表。 |
| [NAPTR记录](https://zh.wikipedia.org/w/index.php?title=NAPTR%E8%A8%98%E9%8C%84&action=edit&redlink=1)（NAPTR record） | 35    | [RFC 3403](https://tools.ietf.org/html/rfc3403)              | 命名管理指针                                                 | 允许基于正则表达式的域名重写使其能够作为 [URI](https://zh.wikipedia.org/wiki/URI)、进一步域名查找等。 |
| NS                                                           | 2     | [RFC 1035](https://tools.ietf.org/html/rfc1035)              | 名称服务器记录                                               | 委托[DNS区域](https://zh.wikipedia.org/w/index.php?title=DNS%E5%8D%80%E5%9F%9F&action=edit&redlink=1)（DNS zone）使用已提供的权威域名服务器。 |
| NSEC                                                         | 47    | [RFC 4034](https://tools.ietf.org/html/rfc4034)              | 下一代安全记录                                               | DNSSEC 的一部分 — 用来验证一个未存在的服务器，使用与 NXT（已过时）记录的格式。 |
| NSEC3                                                        | 50    | [RFC 5155](https://tools.ietf.org/html/rfc5155)              | NSEC 记录第三版                                              | 用作允许未经允许的区域行走以证明名称不存在性的 DNSSEC 扩展。 |
| NSEC3PARAM                                                   | 51    | [RFC 5155](https://tools.ietf.org/html/rfc5155)              | NSEC3 参数                                                   | 与 NSEC3 同时使用的参数记录。                                |
| PTR                                                          | 12    | [RFC 1035](https://tools.ietf.org/html/rfc1035)              | 指针记录                                                     | 引导至一个[规范名称](https://zh.wikipedia.org/w/index.php?title=%E8%A6%8F%E7%AF%84%E5%90%8D%E7%A8%B1&action=edit&redlink=1)（Canonical Name）。与 CNAME 记录不同，DNS“不会”进行进程，只会传回名称。最常用来运行[反向 DNS 查找](https://zh.wikipedia.org/w/index.php?title=%E5%8F%8D%E5%90%91_DNS_%E6%9F%A5%E6%89%BE&action=edit&redlink=1)，其他用途包括引作 [DNS-SD](https://zh.wikipedia.org/w/index.php?title=DNS-SD&action=edit&redlink=1)。 |
| RRSIG                                                        | 46    | [RFC 4034](https://tools.ietf.org/html/rfc4034)              | DNSSEC 证书                                                  | DNSSEC 安全记录集证书，与 SIG 记录使用相同的格式。           |
| RP                                                           | 17    | [RFC 1183](https://tools.ietf.org/html/rfc1183)              | 负责人                                                       | 有关域名负责人的信息，电邮地址的 **@** 通常写为 **a**。      |
| SIG                                                          | 24    | [RFC 2535](https://tools.ietf.org/html/rfc2535)              | 证书                                                         | SIG(0)（[RFC 2931](https://tools.ietf.org/html/rfc2931)）及 TKEY（[RFC 2930](https://tools.ietf.org/html/rfc2930)）使用的证书。[[5\]](https://zh.wikipedia.org/wiki/%E5%9F%9F%E5%90%8D%E4%BC%BA%E6%9C%8D%E5%99%A8%E8%A8%98%E9%8C%84%E9%A1%9E%E5%9E%8B%E5%88%97%E8%A1%A8#cite_note-rfc3755_sec3-5)[RFC 3755](https://tools.ietf.org/html/rfc3755) designated RRSIG as the replacement for SIG for use within DNSSEC.[[5\]](https://zh.wikipedia.org/wiki/%E5%9F%9F%E5%90%8D%E4%BC%BA%E6%9C%8D%E5%99%A8%E8%A8%98%E9%8C%84%E9%A1%9E%E5%9E%8B%E5%88%97%E8%A1%A8#cite_note-rfc3755_sec3-5) |
| SOA                                                          | 6     | [RFC 1035](https://tools.ietf.org/html/rfc1035)              | 权威记录的起始                                               | 指定有关DNS区域的权威性信息，包含主要名称服务器、域名管理员的电邮地址、域名的流水式编号、和几个有关刷新区域的定时器。 |
| [SPF](https://zh.wikipedia.org/wiki/Sender_Policy_Framework) | 99    | [RFC 4408](https://tools.ietf.org/html/rfc4408)              | SPF 记录                                                     | 作为 SPF 协议的一部分，优先作为先前在 TXT 存储 SPF 数据的临时做法，使用与先前在 TXT 存储的格式。 |
| [SRV记录](https://zh.wikipedia.org/w/index.php?title=SRV%E8%A8%98%E9%8C%84&action=edit&redlink=1)（SRV record） | 33    | [RFC 2782](https://tools.ietf.org/html/rfc2782)              | 服务定位器                                                   | 广义为服务定位记录，被新式协议使用而避免产生特定协议的记录，例如：MX 记录。 |
| SSHFP                                                        | 44    | [RFC 4255](https://tools.ietf.org/html/rfc4255)              | SSH 公共密钥指纹                                             | DNS 系统用来发布 [SSH](https://zh.wikipedia.org/wiki/SSH) 公共密钥指纹的资源记录，以用作辅助验证服务器的真实性。 |
| TA                                                           | 32768 | 无                                                           | DNSSEC 信任当局                                              | DNSSEC 一部分无签订 DNS 根目录的部署提案，，使用与 DS 记录相同的格式[[6\]](https://zh.wikipedia.org/wiki/%E5%9F%9F%E5%90%8D%E4%BC%BA%E6%9C%8D%E5%99%A8%E8%A8%98%E9%8C%84%E9%A1%9E%E5%9E%8B%E5%88%97%E8%A1%A8#cite_note-6)[[7\]](https://zh.wikipedia.org/wiki/%E5%9F%9F%E5%90%8D%E4%BC%BA%E6%9C%8D%E5%99%A8%E8%A8%98%E9%8C%84%E9%A1%9E%E5%9E%8B%E5%88%97%E8%A1%A8#cite_note-7)。 |
| [TKEY记录](https://zh.wikipedia.org/w/index.php?title=TKEY%E8%A8%98%E9%8C%84&action=edit&redlink=1)（TKEY record） | 249   | [RFC 2930](https://tools.ietf.org/html/rfc2930)              | 秘密密钥记录                                                 | 为[TSIG](https://zh.wikipedia.org/w/index.php?title=TSIG&action=edit&redlink=1)提供密钥材料的其中一类方法，that is 在公共密钥下加密的 accompanying KEY RR。[[8\]](https://zh.wikipedia.org/wiki/%E5%9F%9F%E5%90%8D%E4%BC%BA%E6%9C%8D%E5%99%A8%E8%A8%98%E9%8C%84%E9%A1%9E%E5%9E%8B%E5%88%97%E8%A1%A8#cite_note-8) |
| TSIG                                                         | 250   | [RFC 2845](https://tools.ietf.org/html/rfc2845)              | 交易证书                                                     | 用以认证动态更新（Dynamic DNS）是来自合法的客户端，或与 DNSSEC 一样是验证回应是否来自合法的递归名称服务器。[[9\]](https://zh.wikipedia.org/wiki/%E5%9F%9F%E5%90%8D%E4%BC%BA%E6%9C%8D%E5%99%A8%E8%A8%98%E9%8C%84%E9%A1%9E%E5%9E%8B%E5%88%97%E8%A1%A8#cite_note-9) |
| TXT                                                          | 16    | [RFC 1035](https://tools.ietf.org/html/rfc1035)              | 文本记录                                                     | 最初是为任意可读的文本 DNS 记录。自1990年起，些记录更经常地带有机读数据，以 [RFC 1464](https://tools.ietf.org/html/rfc1464) 指定：opportunistic encryption、[Sender Policy Framework](https://zh.wikipedia.org/wiki/Sender_Policy_Framework)（虽然这个临时使用的 TXT 记录在 SPF 记录推出后不被推荐）、DomainKeys、DNS-SD等。 |


### 3. DNS协议格式。

DNS请求与响应的格式是一致的，其整体分为Header、Question、Answer、Authority、Additional5部分，如下图所示：

![dns message](http://ojapxw8c8.bkt.clouddn.com/2017-04-15%2003-02-39%E5%B1%8F%E5%B9%95%E6%88%AA%E5%9B%BE.png)



> Header部分是一定有的，长度固定为12个字节；其余4部分可能有也可能没有，并且长度也不一定，这个在Header部分中有指明。

Header的结构如下：

![dns header](http://ojapxw8c8.bkt.clouddn.com/2017-04-15%2003-06-31%E5%B1%8F%E5%B9%95%E6%88%AA%E5%9B%BE.png)

下面说明一下各个字段的含义:

- ID：占16位。该值由发出DNS请求的程序生成，DNS服务器在响应时会使用该ID，这样便于请求程序区分不同的DNS响应。

- QR：占1位。指示该消息是请求还是响应。0表示请求；1表示响应。

- OPCODE：占4位。指示请求的类型，有请求发起者设定，响应消息中复用该值。0表示标准查询；1表示反转查询；2表示服务器状态查询。3~15目前保留，以备将来使用。

- AA（Authoritative Answer，权威应答）：占1位。表示响应的服务器是否是权威DNS服务器。只在响应消息中有效。

- TC（TrunCation，截断）：占1位。指示消息是否因为传输大小限制而被截断。

- RD（Recursion Desired，期望递归）：占1位。该值在请求消息中被设置，响应消息复用该值。如果被设置，表示希望服务器递归查询。但服务器不一定支持递归查询。

- RA（Recursion Available，递归可用性）：占1位。该值在响应消息中被设置或被清除，以表明服务器是否支持递归查询。

- Z：占3位。保留备用。

- RCODE（Response code）：占4位。该值在响应消息中被设置。取值及含义如下：

  0：No error condition，没有错误条件；
  1：Format error，请求格式有误，服务器无法解析请求；
  2：Server failure，服务器出错。
  3：Name Error，只在权威DNS服务器的响应中有意义，表示请求中的域名不存在。
  4：Not Implemented，服务器不支持该请求类型。
  5：Refused，服务器拒绝执行请求操作。
  6~15：保留备用。

- QDCOUNT：占16位（无符号）。指明Question部分的包含的实体数量。
- ANCOUNT：占16位（无符号）。指明Answer部分的包含的RR（Resource Record）数量。
- NSCOUNT：占16位（无符号）。指明Authority部分的包含的RR（Resource Record）数量。
- ARCOUNT：占16位（无符号）。指明Additional部分的包含的RR（Resource Record）数量。

#### 3 Question部分

Question部分的每一个实体的格式如下图所示：

![dns question](http://ojapxw8c8.bkt.clouddn.com/2017-04-15%2003-08-09%E5%B1%8F%E5%B9%95%E6%88%AA%E5%9B%BE.png)

- QNAME：字节数不定，以0x00作为结束符。表示查询的主机名。注意：众所周知，主机名被"."号分割成了多段标签。在QNAME中，每段标签前面加一个数字，表示接下来标签的长度。比如：api.sina.com.cn表示成QNAME时，会在"api"前面加上一个字节0x03，"sina"前面加上一个字节0x04，"com"前面加上一个字节0x03，而"cn"前面加上一个字节0x02；
- QTYPE：占2个字节。表示RR类型，见以上RR介绍；
- QCLASS：占2个字节。表示RR分类，见以上RR介绍。

#### 4 Answer、Authority、Additional部分

Answer、Authority、Additional部分格式一致，每部分都由若干实体组成，每个实体即为一条RR，之前有过介绍，格式如下图所示：

![dns answer](http://ojapxw8c8.bkt.clouddn.com/2017-04-15%2003-11-32%E5%B1%8F%E5%B9%95%E6%88%AA%E5%9B%BE.png)

- NAME：长度不定，可能是真正的数据，也有可能是指针（其值表示的是真正的数据在整个数据中的字节索引数），还有可能是二者的混合（以指针结尾）。若是真正的数据，会以0x00结尾；若是指针，指针占2个字节，第一个字节的高2位为11。
- TYPE：占2个字节。表示RR的类型，如A、CNAME、NS等，见以上RR介绍；
- CLASS：占2个字节。表示RR的分类，见以上RR介绍；
- TTL：占4个字节。表示RR生命周期，即RR缓存时长，单位是秒；
- RDLENGTH：占2个字节。指定RDATA字段的字节数；
- RDATA：即之前介绍的value，含义与TYPE有关，见以上RR介绍。

DNS协议是工作在应用层的，运输层依赖的是UDP协议。

## 参考资料

RFC 1034
RFC 1035
[GSLB by go](https://github.com/liuhengloveyou/GSLB)
