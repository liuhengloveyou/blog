---
title: https性能优化
comments: true
date: 2017-12-21 14:32:17
time: 1513837937
tags: 
	- tls
	- https
categories: web
---



> 我们讲的是TLS 1.2版本的情况，TLS1.3变化还是比较大的。

## 为什么必须升级为HTTPS

1. HTTP 协议通信过程是明文的，而TCP/IP协议本质上是基于存储转发机制而工作，从服务器端口到浏览器之间数据链路中，各种中间环节（比如代理，网关，路由器，WIFI热点，恶意驱动程序，恶意浏览器插件等等）可以轻易的监听和修改途经的数据报，导致信息的泄露和恶意篡改。
2. HTTP协议没有用户和网站的身份验证机制，用户在浏览器上敲入的网址， 有可能被DNS劫持，从而导致用户浏览器被导向了伪造的网站，用户和伪造的服务器通信，重要信息如账号密码被骗取。
3. HTTP通信过程被恶意劫持和篡改，但是普通用户无法分辨，会把所有问题归咎于网站或者APP开发者， 对网站和APP的正常经营和品牌造成不利影响。
4. 黑客在HTTP通信过程中，插入恶意代码或病毒，进行双向入侵和攻击。

为应对HTTP劫持，全站HTTPS是一条必经路线。

## HTTPS带来的问题

HTTPS是应用层协议， 相校于HTTP，HTTPS在TCP层之上加入了TLS层用于数据加密传输。HTTPS带来的问题， 其实就是引入TLS协议带来的问题。

### 性能下降

在忽略DNS解析过程的情况下，HTTP协议只要完成TCP 3次交互就可以开始发送请求，返回结果。HTTPS由于加入TLS协议握手(证书校验，密钥协商等)复杂环节，根据缓存命中状态，交互次数会增加3-7倍不等。

在不做优化的情况下，会带来250-500ms的延迟，对于比较差的页面可能会恶化500-1200ms。

同时，各种对称、非对称和散列算法耗费计算时间，又会加入几十毫秒的延迟。 由于非对称加解密非常耗费计算资源，还会带来服务器并发性能的下降。假设在使用HTTP时， CPS可以达到2万多 的网站，使用HTTPS后，CPS会下降为2-3千左右。

### 成本增加

HTTPS要额外计算，就产生了服务器成本：

1. 非对称密钥交换，对称的密钥协商。
2. 对证书的签名进行校验，确认网站的身份。
3. 完整性校验，不仅要加密还要防止内容被篡改，所以要进行自身的完整性校验。
4. 对称加解密所有应用层数据。

### 兼容性

从1995年Netscape公司发布SSL协议至今，历经SSL v2.0, SSL v3.0, TLS 1.0, TLS 1.1, TLS 1.2, TLS1.3，SSL v2.0, SSL v3.0 和 TLS 1.0 已经发现存在安全漏洞，逐渐在新版的操作系统和新版浏览器中停止支持。但中国市场上仍有少量（大约 2 % 左右）古老的浏览器在使用这些带有缺陷的加密传输协议。

### HTTPS攻击

1. 协议降级攻击。降级攻击一般包括两种：加密套件降级攻击 (cipher suite rollback) 和协议降级攻击（version roll back）。
2. 重新协商攻击。重新协商（tls renegotiation）分为两种：加密套件重协商 (cipher suite renegotiation) 和协议重协商（protocol renegotiation）。重新协商会有两个隐患：
   - 重协商后使用弱的安全算法。这样的后果就是传输内容很容易泄露。
   - 重协商过程中不断发起完全握手请求，触发服务端进行高强度计算并引发服务拒绝。

   ​


## HTTPS/TLS协议优化

### [HSTS](https://baike.baidu.com/item/HSTS/8665782)

HSTS(HTTP Strict Transport Security)的作用是强制客户端（如浏览器）使用HTTPS与服务器创建连接。 

服务器开启HSTS的方法是，当客户端通过HTTPS发出请求时，在服务器返回的超文本传输协议响应头中包含Strict-Transport-Security字段。非加密传输时设置的HSTS字段无效。

比如，https://www.sixianed.com/ 的响应头含有Strict-Transport-Security: max-age=31536000; includeSubDomains。这意味着两点：

在接下来的一年（即31536000秒）中，浏览器只要向xxx或其子域名发送HTTP请求时，必须采用HTTPS来发起连接。比如，用户点击超链接或在地址栏输入 http://www.sixianed.com/ ，浏览器应当自动将 http 转写成 https，然后直接向 https://www.sixianed.com/ 发送请求。

在接下来的一年中，如果服务器发送的TLS证书无效，用户不能忽略浏览器警告继续访问网站。

在使用HSTS的过程中仍有一些值得注意的问题： 

1. HSTS将全部的证书错误视为致命的。因此，一旦主域使用HSTS，浏览器将放弃对域名所有无效证书站点的连接。 
2. 首次访问仍然使用HTTP，然后才能激活HSTS。无法保障首次访问的安全性如何解决？可以通过`preloading`预加载的方式，与浏览器厂商约定好一份支持HSTS的网站清单来缓解。目前Google已经提供了在线注册服务<https://hstspreload.appspot.com/> 
3. 通过`Strict-Transport-Security: max-age=0`将缓存设置为0可以撤销HSTS。但是只有当浏览器再次访问网站并且得到响应更新配置时才能生效。


### [Ocsp stapling](https://en.wikipedia.org/wiki/OCSP_stapling)

OCSP(Online Certificate Status Protocol) stapling是一个TLS/SSL扩展，旨在提高SSL握手的性能，同时保护用户隐私。

OCSP是用于查询证书是否被吊销的协议。它被创建为CRL的替代方案，用以减少TLS握手时间。使用CRL(Certificate Revocation List)时浏览器下载一个被撤销证书序列号的列表，并验证当前证书，这将增加TLS握手时间。在OCSP中，浏览器向OCSP URL发送请求，并接收包含证书有效性状态的响应。

OCSP有两个主要问题:隐私和对CA服务器的压力。OCSP实时查询也会增加客户端的性能开销，减慢TLS握手速度。由于OCSP要求浏览器与CA联系以确认证书的有效性，CA知道是**谁**正在访问**什么网站**，会损害隐私。而且如果HTTPS网站有很多访问者，那么CA的OCSP服务器就必须处理访问者提出的所有OCSP请求。

OCSP stapling是一种允许在TLS握手中包含吊销信息的协议扩展，启用OCSP stapling后，服务端可以代替客户端完成证书吊销状态的检测，并将全部信息在握手过程中返回给客户端(**Certificate Status Request** 扩展.)。增加的握手信息大小在1KB以内，CA的服务器不再有负担，浏览器不再需要向任何第三方公开用户的浏览习惯。

#### 配置Nginx (>=1.3.7)支持OCSP stapling:

在 `server {}` 段添加如下内容：

```nginx
ssl_stapling on;
ssl_stapling_verify on;
ssl_trusted_certificate /etc/ssl/private/ca-certs.pem;

```

#### 测试OSCP stapling:

该命令的输出显示了您的web服务器是否响应了OCSP数据。

```
openssl s_client -connect sixianed.com:443 -status -tlsextdebug < /dev/null 2>&1 | grep -A 17 'OCSP response:' | grep -B 17 'Next Update'
```

 如果OCSP stapling 正常工作显示如下：

```
OCSP response:
======================================
OCSP Response Data:
    OCSP Response Status: successful (0x0)
    Response Type: Basic OCSP Response
    Version: 1 (0x0)
    Responder Id: 4C58CB25F0414F52F428C881439BA6A8A0E692E5
    Produced At: May  9 08:45:00 2014 GMT
    Responses:
    Certificate ID:
      Hash Algorithm: sha1
      Issuer Name Hash: B8A299F09D061DD5C1588F76CC89FF57092B94DD
      Issuer Key Hash: 4C58CB25F0414F52F428C881439BA6A8A0E692E5
      Serial Number: 0161FF00CCBFF6C07D2D3BB4D8340A23
    Cert Status: good
    This Update: May  9 08:45:00 2014 GMT
    Next Update: May 16 09:00:00 2014 GMT

```

如果 OCSP stapling 没有在工作， 什么也不显示。


### TLS会话复用

会话复用是指在一次完整协商的连接断开时，客户端和服务端会将会话的安全参数保存一段时间。后续的重新连接时，双方使用简化握手流程恢复之前协商的会话，可以大大减少了TLS握手的开销。 

会话恢复的方案可以分为两种，不同的TLS库实现细节不尽相同：
- Session ID

  客户端在每次握手的ClientHello消息中， 会带上sessionId字段。服务端保存会话信息并返回相同的sessionId, 告诉客户端复用该会话。客户端也需要保存相应的会话信息，以便复用。

- [Session Ticket](https://tools.ietf.org/html/rfc5077)

  相当于http 的cookie。客户端的clientHello消息中，如果表明支持sessionticket。 服务端会把会话信息序列化发给客户端。后续建立新日连接时， 客户端的clientHello消息中带上sessionTicket， 服务端解密，恢复会话。
### [TLS协议参数](https://wiki.mozilla.org/Security/Server_Side_TLS)

1. 协议版本。尽量用新版本协议，不安全的SSL2和SSL3要废弃掉。启用ssl_prefer_server_ciphers，Nginx在TLS握手时启用服务器算法优先，由服务器选择适配算法而不是客户端：

```
ssl_protocols TLSv1.2 TLSv1.1 TLSv1;
ssl_prefer_server_ciphers on;
```

2. 加密套件。优先选择支持前向加密的算法，且按照性能的优先顺序排列：

```
ssl_ciphers "ECDHE-ECDSA-CHACHA20-POLY1305 
ECDHE-RSA-CHACHA20-POLY1305 
ECDHE-ECDSA-AES128-GCM-SHA256
ECDHE-RSA-AES128-GCM-SHA256 
ECDHE-ECDSA-AES256-GCM-SHA384 
ECDHE-RSA-AES256-GCM-SHA384 
DHE-RSA-AES128-GCM-SHA256 
DHE-RSA-AES256-GCM-SHA384 
ECDHE-ECDSA-AES128-SHA256 
ECDHE-RSA-AES128-SHA256 
ECDHE-ECDSA-AES128-SHA 
ECDHE-RSA-AES256-SHA384 
ECDHE-RSA-AES128-SHA
ECDHE-ECDSA-AES256-SHA384
ECDHE-ECDSA-AES256-SHA
ECDHE-RSA-AES256-SHA 
DHE-RSA-AES128-SHA256
DHE-RSA-AES128-SHA
DHE-RSA-AES256-SHA256
DHE-RSA-AES256-SHA 
ECDHE-ECDSA-DES-CBC3-SHA 
ECDHE-RSA-DES-CBC3-SHA
EDH-RSA-DES-CBC3-SHA AES128-GCM-SHA256 AES256-GCM-SHA384 AES128-SHA256 AES256-SHA256 AES128-SHA AES256-SHA DES-CBC3-SHA !DSS";
```

### False start

TLS False Start是指客户端在发送ChangeCipherSpec Finished 同时发送应用数据，服务端在 TLS 握手完成时直接返回应用数据。这样应用数据的发送实际上并未等到握手全部完成。 
![TLS False start](http://img.blog.csdn.net/20170512184827918?watermark/2/text/aHR0cDovL2Jsb2cuY3Nkbi5uZXQvemh1eWlxdWFu/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70/gravity/SouthEast)
要实现False Start，服务端必须满足两个条件： 
1. 服务端必须支持NPN（Next protocol negotiation, ALPN的前身）或者ALPN（Application layer protocol negotiation, 应用层协议协商）； 
2. 服务端必须采用支持前向加密的算法。 

### 域名收敛

TLS的会话是分域名的， 每个域名都会新建连接。域名越多，页面加载肯定越慢。

### 硬件加速卡

可以通过SSL硬件加速卡设备来代替CPU进行TLS握手过程中的运算。比如Cavium的加速卡，Cavium引擎可以集成到Nginx模块中，支持物理机和虚拟机环境。建议开启Nginx异步请求Cavium引擎模式，更有效提高使用率。 

下面是我们压测的CPU到20%情况下，使用TLS 1.2协议、加密套件采用ECDHE-RSA-AES128-SHA256 、HTTPS **短连接**的各种环境性能数据，可见使用Cavium，物理机性能提升比：325%，虚拟机性能提升比：588%。

| 环境              | 流量类型  | TPS  | 延迟(s) |
| --------------- | ----- | ---- | ----- |
| 虚拟机             | HTTPS | 172  | 0.066 |
| 虚拟机 + Cavium加速卡 | HTTPS | 1012 | 0.066 |
| 物理机             | HTTPS | 832  | 0.066 |
| 物理机 + Cavium加速卡 | HTTPS | 2708 | 0.059 |

借用Facebook关于硬件加速的说法： 
“我们发现当前基于软件的TLS实现在普通CPU上已经运行的足够快，无需借助专门的加密硬件就能够处理大量的HTTPS请求。我们使用运行于普通硬件上的软件提供全部HTTPS服务。”

最后总结下服务端Nginx的配置，供参考：

```nginx
server {
    listen 443 ssl http2 default_server;
    server_name  site1.suning.com;
    add_header Strict-Transport-Security "max-age=63072000; includeSubdomains; preload";

	ssl_certificate /usr/local/nginx/cert/sixianed.pem;  
    ssl_certificate_key /usr/local/nginx/cert/sixianed.key;  

    # 分配10MB的共享内存缓存，不同工作进程共享TLS会话信息
	ssl_session_cache shared:SSL:10m;
    # 设置会话缓存过期时间24h
    ssl_session_timeout 1440m;

	ssl_protocols SSLv3 TLSv1.2 TLSv1.1 TLSv1;   
	ssl_prefer_server_ciphers on;  
    ssl_ciphers ssl_ciphers "ECDHE-ECDSA-CHACHA20-POLY1305 ECDHE-RSA-CHACHA20-POLY1305 ECDHE-ECDSA-AES128-GCM-SHA256 AES256-GCM-SHA384 AES128-SHA256 AES256-SHA256 AES128-SHA AES256-SHA DES-CBC3-SHA !DSS";

	ssl_session_tickets on;
    ssl_session_ticket_key /usr/local/nginx/ssl_cert/session_ticket.key;

    ssl_stapling on;
	ssl_stapling_file /usr/local/nginx/oscp/stapling_file.ocsp;            
    ssl_stapling_verify on;  
    ssl_trusted_certificate /usr/local/nginx/ssl_cert/trustchain.crt;      

    root   html;
    index  index.html index.htm;

    location / {
        default_type text/HTML;

        content_by_lua_block {
            ngx.say('HTTPS Hello,world!')
        }
    }    
}
```