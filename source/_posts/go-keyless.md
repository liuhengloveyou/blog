---
title: 用golang实现keyless及https性能优化
comments: true
date: 2017-10-28 00:59:27
time: 1507866347
tags: 
- https
- keyless
categories: golang
---

## 密码使用学简介

大家常讲的密码家,可理解密码分析学或密码使用学. **密码使用学**指的是一种为了达到隐藏消息含义目的而使用的密文书写的科学。
作为程序员我们只需要关心密码使用学的问题.

 ![密码使用学](https://www.sixianed.com/images/WX20170616-144049@2x.png)

我们要做的是使用密码学现有的成果来保证通信的安全, 部署正确的密码能解决安全的三个核心需求:保持秘密(机密性),验证身份(真实性),以及保证传输安全(完整性).

密码使用学本身可以分为以下三个主要分支：

- **对称密码算法(Symmetric Algorithm):**

 用户双方共享一个密钥，并使用相同的加密方法和解密方法。

- **非对称密码算法(Asymmetric Algorithm)或公钥算法(Public-Key Algorithm):**

  Whitfield Diffie, Martin Hellman, Ralph Merkle在1976年提出了非对称加密算法。用户有自己的密钥和公钥。

- **密码协议(Cryptographic Protocol):**

  粗略的讲，密码协议主要针对是密码算法的应用规则，一个典型代表就是TLS。

![密码学的主要领域](https://www.sixianed.com/images/440ADAD4-2FDA-4BE6-BC07-5BF89E0EA49D.png)

### 对称密码

对称加密算法的特点是双方共享一个密钥,并使用相同的加解密方法. 密钥是保密的算法是公开的.

假设一个应用场景：有两个用户－－Alice和Bob－－想通过一个不安全的信道进行通信.而有一个名叫Oscar的坏蛋试图窃听. 而Alice和Bob更愿意避开Oscar的窃听.

![不安全信道上的通信](https://www.sixianed.com/images/CF6E6710-6FE7-4247-B2CC-665410FDE39E.png)

对称密码可以解决这种情况: Alice使用对称算法加密她的消息x, 得到密文y; Bob接收到密文y, 解密得到消息x.

![安全信道上的通信](https://www.sixianed.com/images/6A57E560-0100-4FA7-839B-90910DB7E2F1.png)


PS: x称为明文; y称为密文; k称为密钥


对称密码学分成分组密码和序列密码两部分，两者差异较大，易于区分。

![分组密码和序列密码](https://www.sixianed.com/images/QQ20170620-101232@2x.png)

#### 序列密码

序列密码单独加密每个位，它是通过将密钥序列中的每个位与每个明文位相加实现的。同步序列密码的密码序列公取决于密钥,而异步序列密码的密钥序列则取决于密钥和密文.

目前公开的序列密码算法主要有RC4、SEAL等。

#### 分组密码

分组密码每次使用相同的密钥加密整个明文位分组.这意味着对给定分组内任何明文的加密都依赖于与它在一个分组内的其它所有明文位.

DES(Data Encytption Standard, 数据加密标准)是上一代主流分组密码算法, 已经不再安全. 现在大家会选择AES(Advanced Encryption Standard,高级加密标准).

AES有128位/192位/256位三种不同的密钥长度抵抗蛮力攻击, 目前还没有出现成功破译AES的攻击.

#### 分组密码加密操作模式

分组密码每次只能加密长度等于分组长度的单块数据,通常实际应用中人们需要加密不只是8字节或16字节的单个明文分组,使用分组密码算法加密长明文的方式有很多种, 简单介绍常见的几种. 

其中ECB和CFB要求明文长度必须是密码算法分组大小的整数倍,比如在AES中应该是16字节的整数倍.不满足要求的明文必须对其进行填充.填充方式有多种, 其中一种是: 在明文后附加单个"1"位,然后跟据需要附加足够多的"0"位,直到明文长度达到分组长度的整数倍.如果明文长度刚好是分组的整数倍, 则填充的所有位刚好形成了一个单独的额外分组.

其中CFB,OFB,CTR三种模式可将分组密码用作序列加密的基本模块.

* 电子密码本模式 (electronic code book mode, ECB)

 把需要加密的消息按照分组密码的分组长度分为数个块，并对每个块进行独立加密。
 如果消息长度不是分组长度的整数倍, 则在加密前必须将其填充为分组长度的整数倍.

 ![Ecb_encryption](https://www.sixianed.com/images/Ecb_encryption.png)
 ![Ecb_decryption](https://www.sixianed.com/images/Ecb_decryption.png)

 ECB的优点是分组同步不是必须的; 最大的问题是加密是高度确定的.

* 密码分组链接模式 (cipher block chaining mode, CBC)

 每个明文块先与前一个密文块进行异或后再进行加密. 在这种方法中每个密文块都依赖于它前面的所有明文块。

 同时,为了保证每条消息的唯一性，在第一个块中需要使用初始化向量.

 ![Cbc_encryption](https://www.sixianed.com/images/Cbc_encryption.png)
 ![Cbc_decryption](https://www.sixianed.com/images/Cbc_decryption.png)

* 输出反馈模式 (Output feedback, OFB)

 可以将分组密码变成同步的序列密码的加密方案.在OFB模式中密钥序列以分组产生, 然后与一组明文进行异或操作就实现了对明文的加密.

 OFB模式的思路是, 首先使用分组密码加密IV,得到的密钥输出为b位的密钥序列的第一个集合;将前一个密钥输出反馈给分组密码进行加密,即可计算出密钥序列位的下一个分组;不断重复这个过程.

 ![Ofb_encryption](https://www.sixianed.com/images/Ofb_encryption.png)
 ![Ofb_decryption](https://www.sixianed.com/images/Ofb_decryption.png)


 OFB模式形成了一个同步序列密码,因为此密钥序列即不依赖明文,也不依赖密文.所以加密操作与解密操作完全相同,与标准序列密码(RC4)非常相似.

* 密码反馈模式 (Cipher feedback, CFB)

 类似于CBC,可以将块密码变为自同步的流密码;工作过程亦非常相似，CFB的解密过程几乎就是颠倒的CBC的加密过程：

 ![Cfb_encryption](https://www.sixianed.com/images/Cfb_encryption.png)
 ![Cfb_decryption](https://www.sixianed.com/images/Cfb_decryption.png)

* 计数器模式 (Counter CTR)
   CTR模式也被称为整数计数模式模式(Integer Counter Mode, ICM)和SIC模式(Segmented Integer Counter).

 使用分组密码作为序列密码的另一种模式;与OFB和CFB模式一样密钥序列也是以分组方式计算的.在CTR模式中有一个自增的算子，这个算子用密钥加密之后的输出和明文异或的结果得到密文，相当于一次一密。

 ![Ctr_encryption](https://www.sixianed.com/images/Ctr_encryption.png)
 ![Ctr_decryption](https://www.sixianed.com/images/Ctr_decryption.png)

### 非对称密码
一个对称密码系统必须满足两个属性: 1. 加密与解密使用相同的密钥; 2. 加密和解密函数非常类似(DES完全相同); 

那么就会存在一些问题, 1. Alice和Bob必须使用安全的信道建立密钥; 2. 在拥有n个用户的网络中, 如果每每对用户之间都需要一个密钥对, 那将是非常多的密钥; 3. 对Alice或Bob的欺骗没有防御机制;

非对称加密可以克服这些缺点. 与对称加密一样, 非对称加密也有一个密钥; 但不同的是, 它同时还有一个公钥. 主要用于对称密码的密钥传输和数字签名;
重要的非对称加密算法家族有:

* 整数分解方案  因式分解大整数是非常困难的. 突出代表是RSA.
* 离散对数方案  有不少算法都是基于有限域内离散对数问题. 典型代表包括Diffie-Hellman密钥交换, Elgamal加密或数字签名算法DSA.
* 椭圆曲线(EC)方案 离散对数算法的一个推广就是椭圆曲线方案. 典型例子包括椭圆曲线Diffie-Hellman密钥交换(ECDH)和椭圆曲线数字签名算法(ECDSA).

以上三种算法家族都是基于数论函数, 它们的一个突出特征就是要求算术运算的操作数和密钥都非常长. 显而易见, 操作数和密钥长度越长, 算法就越安全, 计算性能也就越差.

#### RSA
Whitfield Diffie 和Martin Hellman 于1976年在他们的论文中提出公钥密码后, 一个崭新的密码学分枝涌现出来. 1977年, Ronald Rivest, Adi Shamir 和 Leonard Adleman提出了一种实现方案, 即RSA;

提出RSA算法的本意并不是为了取代对称密码, 而且它比诸如AES的密码要慢很多, 主要用途是为了安全地交换对称密码的密钥. 实际上RSA通常与类似AES的对称密码一起使用, 其中真正用来加密大量数据的是对称密码.

#### Diffie-Hellman
Diffie-Hellman密钥交换(DHKE)是由Whitfield Diffie 和Martin Hellman在1976年提出的, 也是在公开文献中发布的第一个非对称方案. 

它提供了实际中密钥分配问题的解决方案, 即它允许双方通过不安全的信道进行交流, 得到一个共同密钥. 许多密码协议中都实现了这种基本的密钥协议技术, 比如SSH, TLS, IPSec.

####  ECC
椭圆曲线密码学(ECC)是已确定具有实用性的三种公钥算法家族中最新的一个成员.

ECC使用较短的操作数, 可提供与RSA或离散对数系统同等的安全等级, 所需要的操作数长度之长大概为 160 ~ 256 位比 1024 ~ 3072 位. ECC基于推广的离散对数问题, DL协议(比如Diffie-Hellman密钥交换)也可以使用椭圆曲线实现.

在很多情况中, ECC在性能和带宽上都比RSA和离散对数(DL)方案更具有优势.

## TLS简介
加密基元本身用处不大, 诸如加密和散列算法. 只有将这些元素组合成解决方案和协议才能满足复杂的安全需求. 

TLS就是一种密码协议,介于HTTP与TCP之间的一个可选层. 用于保证通信双方的会话安全.它使客户/服务器应用之间的通信不被攻击窃听，并且始终对服务器进行认证，还可以选择对客户进行认证.

SSL协议应用层来说是透明的,我们在编写基于SSL的HTTPS应用时,无论客户端还是服务端都不需要考虑SSL的存在.

### TLS记录协议
记录协议定义了要传输数据的格式,它位于TCP可靠的的传输协议之上,用于封装上层协议的: 1. 握手协议; 2. 警告协议; 3. 改变密码格式协议; 4. 应用数据协议;

 ![TLS记录协议](https://www.sixianed.com/images/tls_record2.png)

```
1. 内容类型(uint8):
	1. 改变密码格式协议(ChangeCipherSpec): 20
	2. 警告协议(Alert): 21
	3. 握手协议(Handshake): 22
	4. 应用数据协议(ApplicationData): 23
2. 主要版本(uint8):
	使用的SSL/TLS主要版本号
3. 次要版本(uint8):
	使用的SSL/TLS次要版本号
4. 数据包长度(16位):
    1) 明文数据包: 
    这个字段表示的是明文数据以字节为单位的长度
    2) 压缩数据包
    这个字段表示的是压缩数据以字节为单位的长度 
    3) 加密数据包
    这个字段表示的是加密数据以字节为单位的长度 
5. 记录数据 
这个区块封装了上层协议的数据
    1) 明文数据包: 
    opaque fragment[SSLPlaintext.length];
    2) 压缩数据包
    opaque fragment[SSLCompressed.length];
    3) 加密数据包
        3.1) 流式(stream)加密: GenericStreamCipher
            3.1.1) opaque content[SSLCompressed.length];
            3.1.2) opaque MAC[CipherSpec.hash_size];
        3.2) 分组(block)加密: GenericBlockCipher
            3.2.1) opaque content[SSLCompressed.length];
            3.2.2) opaque MAC[CipherSpec.hash_size];
            3.2.3) uint8 padding[GenericBlockCipher.padding_length];
            3.2.4) uint8 padding_length;
6. MAC(0、16、20位) 
```

除了这些可见字段, 通信的两端还会给每个一TLS记录指定唯一的64位序列号, 但不会在线路上传输.

### TLS握手协议
TLS握手协议报文格式如下:

![TLS记录协议](https://www.sixianed.com/images/tls_record.png)

```
1. 类型(Type):
const (
	typeHelloRequest       uint8 = 0
	typeClientHello        uint8 = 1
	typeServerHello        uint8 = 2
	typeNewSessionTicket   uint8 = 4
	typeCertificate        uint8 = 11
	typeServerKeyExchange  uint8 = 12
	typeCertificateRequest uint8 = 13
	typeServerHelloDone    uint8 = 14
	typeCertificateVerify  uint8 = 15
	typeClientKeyExchange  uint8 = 16
	typeFinished           uint8 = 20
	typeCertificateStatus  uint8 = 22
	typeNextProtocol       uint8 = 67 // Not IANA assigned
)
 
2. 长度(Length)(3字节):
	以字节为单位的报文长度。
3. 内容(Content)(≥1字节):
对应报文类型的的实际内容、参数
    　　1) hello_request: 空
        2) client_hello:  
        　　2.1) 版本(ProtocolVersion)
        　　代表客户端可以支持的SSL最高版本号
            　　2.1.1) 主版本: 3
            　　2.1.2) 次版本: 0
        　　2.2) 随机数(Random)
        　　客户端产生的一个用于生成主密钥(master key)的32字节的随机数(主密钥由客户端和服务端的随机数共同生成)
            　　2.2.1) uint32 gmt_unix_time;
            　　2.2.2) opaque random_bytes[28];
        　　4+28=32字节
        　　2.3) 会话ID: opaque SessionID<0..32>;
        　　2.4) 密文族(加密套件): 
        　　一个客户端可以支持的密码套件列表。这个列表会根据使用优先顺序排列，每个密码套件都指定了"密钥交换算法(Deffie-Hellman密钥交换算法、基于RSA的密钥交换和另一种实
现在Fortezza chip上的密钥交换)"、"加密算法(DES、RC4、RC2、3DES等)"、"认证算法(MD5或SHA-1)"、"加密方式(流、分组)"
            　　2.4.1) CipherSuite SSL_RSA_WITH_NULL_MD5                  
            　　2.4.2) CipherSuite SSL_RSA_WITH_NULL_SHA                   
            　　2.4.3) CipherSuite SSL_RSA_EXPORT_WITH_RC4_40_MD5          
            　　2.4.4) CipherSuite SSL_RSA_WITH_RC4_128_MD5                
            　　2.4.5) CipherSuite SSL_RSA_WITH_RC4_128_SHA                
            　　2.4.6) CipherSuite SSL_RSA_EXPORT_WITH_RC2_CBC_40_MD5     
            　　2.4.7) CipherSuite SSL_RSA_WITH_IDEA_CBC_SHA              
            　　2.4.8) CipherSuite SSL_RSA_EXPORT_WITH_DES40_CBC_SHA     
            　　2.4.9) CipherSuite SSL_RSA_WITH_DES_CBC_SHA               
            　　2.4.10) CipherSuite SSL_RSA_WITH_3DES_EDE_CBC_SHA       
            　　2.4.11) CipherSuite SSL_DH_DSS_EXPORT_WITH_DES40_CBC_SHA    
            　　2.4.12) CipherSuite SSL_DH_DSS_WITH_DES_CBC_SHA             
            　　2.4.13) CipherSuite SSL_DH_DSS_WITH_3DES_EDE_CBC_SHA        
            　　2.4.14) CipherSuite SSL_DH_RSA_EXPORT_WITH_DES40_CBC_SHA    
            　　2.4.15) CipherSuite SSL_DH_RSA_WITH_DES_CBC_SHA             
            　　2.4.16) CipherSuite SSL_DH_RSA_WITH_3DES_EDE_CBC_SHA       
            　　2.4.17) CipherSuite SSL_DHE_DSS_EXPORT_WITH_DES40_CBC_SHA   
            　　2.4.18) CipherSuite SSL_DHE_DSS_WITH_DES_CBC_SHA            
            　　2.4.19) CipherSuite SSL_DHE_DSS_WITH_3DES_EDE_CBC_SHA       
            　　2.4.20) CipherSuite SSL_DHE_RSA_EXPORT_WITH_DES40_CBC_SHA   
            　　2.4.21) CipherSuite SSL_DHE_RSA_WITH_DES_CBC_SHA           
            　　2.4.22) CipherSuite SSL_DHE_RSA_WITH_3DES_EDE_CBC_SHA  
            　　2.4.23) CipherSuite SSL_DH_anon_EXPORT_WITH_RC4_40_MD5     
            　　2.4.24) CipherSuite SSL_DH_anon_WITH_RC4_128_MD5            
            　　2.4.25) CipherSuite SSL_DH_anon_EXPORT_WITH_DES40_CBC_SHA  
            　　2.4.26) CipherSuite SSL_DH_anon_WITH_DES_CBC_SHA           
            　　2.4.27) CipherSuite SSL_DH_anon_WITH_3DES_EDE_CBC_SHA    
            　　2.4.28) CipherSuite SSL_FORTEZZA_KEA_WITH_NULL_SHA          
            　　2.4.29) CipherSuite SSL_FORTEZZA_KEA_WITH_FORTEZZA_CBC_SHA  
            　　2.4.30) CipherSuite SSL_FORTEZZA_KEA_WITH_RC4_128_SHA      
        　　2.5) 压缩方法
        3) server_hello: 
        　　3.1) 版本(ProtocolVersion)
        　　代表服务端"采纳"的最高支持的SSL版本号
            　　3.1.1) 主版本: 3
            　　3.1.2) 次版本: 0
        　　3.2) 随机数(Random)
        　　服务端产生的一个用于生成主密钥(master key)的32字节的随机数(主密钥由客户端和服务端的随机数共同生成)
            　　3.2.1) uint32 gmt_unix_time;
            　　3.2.2) opaque random_bytes[28];
        　　4+28=32字节
        　　3.3) 会话ID: opaque SessionID<0..32>;
        　　3.4) 密文族(加密套件): 
        　　代表服务端采纳的用于本次通讯的的加密套件
        　　3.5) 压缩方法:
        　　代表服务端采纳的用于本次通讯的的压缩方法
    　　总体来看，server_hello就是服务端对客户端的的回应，表示采纳某个方案
        4) certificate: 
    　　SSL服务器将自己的"服务端公钥证书(注意，是公钥整数)"发送给SSL客户端  
    　　ASN.1Cert certificate_list<1..2^24-1>;
        5) server_key_exchange:   
        　　1) RSA
        　　执行RSA密钥协商过程
            　　1.1) RSA参数(ServerRSAParams)
                　　1.1.1) opaque RSA_modulus<1..2^16-1>;
                　　1.1.2) opaque RSA_exponent<1..2^16-1>;
           　　 1.2) 签名参数(Signature)
                　　1.2.1) anonymous: null
                　　1.2.2) rsa
                    　　1.2.2.1) opaque md5_hash[16];
                    　　1.2.2.2) opaque sha_hash[20];
                　　1.2.3) dsa
                    　　1.2.3.1) opaque sha_hash[20];
        　　2) diffie_hellman
        　　执行DH密钥协商过程
            　　2.1) DH参数(ServerDHParams)
                　　2.1.1) opaque DH_p<1..2^16-1>;
                　　2.1.2) opaque DH_g<1..2^16-1>;
                　　2.1.3) opaque DH_Ys<1..2^16-1>;
            　　2.2) 签名参数(Signature)
                　　2.2.1) anonymous: null
                　　2.2.2) rsa
                    　　2.2.2.1) opaque md5_hash[16];
                    　　2.2.2.2) opaque sha_hash[20];
                　　2.2.3) dsa
                    　　2.2.3.1) opaque sha_hash[20];
        　　3) fortezza_kea
        　　执行fortezza_kea密钥协商过程
            　　3.1) opaque r_s [128]
    6) certificate_request:   
        6.1) 证书类型(CertificateType)
            6.1.1) RSA_sign
            6.1.2) DSS_sign
            6.1.3) RSA_fixed_DH
            6.1.4) DSS_fixed_DH
            6.1.5) RSA_ephemeral_DH
            6.1.6) DSS_ephemeral_DH  
            6.1.7) FORTEZZA_MISSI
        6.2) 唯一名称(DistinguishedName)
        certificate_authorities<3..2^16-1>;
    7) server_done: 
    服务器总是发送server_hello_done报文，指示服务器的hello阶段结束
    struct { } ServerHelloDone;
    8) certificate_verify:  
    签名参数(Signature)
        8.1) anonymous: null
        8.2) rsa
            8.2.1) opaque md5_hash[16];
            8.2.2) opaque sha_hash[20];
        8.3) dsa
            8.3.1) opaque sha_hash[20];
    9) client_key_exchange:  
        9.1) RSA
            9.1.1) PreMasterSecret
                9.1.1.1) ProtocolVersion 
                9.1.1.2) opaque random[46];
        9.2) diffie_hellman: opaque DH_Yc<1..2^16-1>;
        9.3) fortezza_kea
            9.3.1) opaque y_c<0..128>;
            9.3.2) opaque r_c[128];
            9.3.3) opaque y_signature[40];
            9.3.4) opaque wrapped_client_write_key[12];
            9.3.5) opaque wrapped_server_write_key[12];
            9.3.6) opaque client_write_iv[24];
            9.3.7) opaque server_write_iv[24];
            9.3.8) opaque master_secret_iv[24];
            9.3.9) opaque encrypted_preMasterSecret[48];
    10) finished:  
        10.1) opaque md5_hash[16];
        10.2) opaque sha_hash[20];
```


# 公钥密码认证基础设施极简介

## X.509证书标准
X.509是PKI里一个重要的数字证书标准,是由国际电信联盟(ITU-T)制定,主要定义了证书中应该包含哪些内容.
其详情可以参考[RFC5280](http://www.ietf.org/rfc/rfc5280.txt)及[wikipedia](https://en.wikipedia.org/wiki/X.509).

### X.509证书结构(v3)

基本部分(Certificate):

1. 版本号(Version); 标识证书的版本(版本1、2或3)

2. 序列号(Serial Number); 标识证书的唯一整数,由证书颁发者分配的本证书的唯一标识符.

3. 算法标识(Algorithm ID); 用于签证书的算法标识,由对象标识符加上相关的参数组成,用于说明本证书所用的数字签名算法.例如:SHA-1和RSA的对象标识符就用来说明该数字签名是利用RSA对SHA-1杂凑加密.

4. 颁发者(Issuer); 证书颁发者的可识别名(DN).

5. 有效期(Validity); 证书有效期的时间段.本字段由”Not Before”和”Not After”两项组成,它们分别由UTC时间或一般的时间表示(在RFC2459中有详细的时间表示规则).

6. 证书主体(Subject); 证书拥有者的可识别名,这个字段必须是非空的,除非你在证书扩展中有别名.

7. 主体公钥信息(Subject Public Key Info); 主体的公钥(以及算法标识符).

8. 颁发者唯一标识符(Issuer Unique Identifier (Optional)); 标识符—证书颁发者的唯一标识符,仅在版本2和版本3中有要求,属可选项.

9. 主体唯一标识符(Subject Unique Identifier (Optional)); 证书拥有者的唯一标识符,仅在版本2和版本3中有要求,属可选项.

扩展部分(extensions).
可选的标准和专用的扩展(仅在版本2和版本3中使用), 扩展部分的元素都有这样的结构:

```
Extension ::= SEQUENCE {
        extnID      OBJECT IDENTIFIER,
        critical    BOOLEAN DEFAULT FALSE,
        extnValue   OCTET STRING }
extnID: 表示一个扩展元素的OID
critical: 表示这个扩展元素是否极重要
extnValue: 表示这个扩展元素的值,字符串类型。
```

1. 发行者密钥标识符; 证书所含密钥的唯一标识符,用来区分同一证书拥有者的多对密钥.

2. 密钥使用; 一个比特串,指明(限定)证书的公钥可以完成的功能或服务,如:证书签名、数据加密等.

3. CRL分布点; 指明CRL的分布地点.

4. 私钥的使用期; 指明证书中与公钥相联系的私钥的使用期限，它也有Not Before和Not After组成。若此项不存在时，公私钥的使用期是一样的。

5. 证书策略; 由对象标识符和限定符组成，这些对象标识符说明证书的颁发和使用策略有关。

6. 策略映射; 表明两个CA域之间的一个或多个策略对象标识符的等价关系，仅在CA证书里存在。

7. 主体别名; 指出证书拥有者的别名，如电子邮件地址、IP地址等，别名是和DN绑定在一起的。

8. 颁发者别名; 指出证书颁发者的别名，如电子邮件地址、IP地址等，但颁发者的DN必须出现在证书的颁发者字段。

9. 主体目录属性; 指出证书拥有者的一系列属性。可以使用这一项来传递访问控制信息

如果某一证书将 KeyUsage 扩展标记为“极重要”,而且设置为“keyCertSign”,则在TLS通信期间该证书出现时将被拒绝,因为该证书扩展表示相关私钥应只用于签写证书,而不应该用于TLS.


### X.509证书文件扩展名
X.509证书文件是Base64编码的文本文件或是DER编码的二进制文件.文件所函的信息是一样的.
常见的扩展名有下面这些, 这些扩展名也可用于别的数据,例如密钥文件.

* .pem - (Privacy-enhanced Electronic Mail). Base64编码的DER编码证书.
  以"-----BEGIN..."开头, "-----END..."结尾. 

* .cer, .crt, .der - certificate的三个字母,通常被用于二进制的DER文件格式(同于.der), 不过也被用于Base64编码的文件(例如 .pem).

* .key - 通常用来存放一个公钥或者私钥,并非X.509证书,编码同样可能是PEM,也可能是DER.

* .csr - Certificate Signing Request,证书签名请求,这个并不是证书,而是向权威证书颁发机构获得签名证书的申请,其核心内容是一个公钥(当然还附带了一些别的信息),在生成这个申请的时候,同时也会生成一个私钥.

* .p7b, .p7c - PKCS#7 SignedData structure without data, just certificate(s) or CRL(s)

* .pfx, .p12 - predecessor of PKCS#12,是一种Microsoft协议，使用户可以将机密信息从一个环境或平台传输到另一个环境或平台. 一般一起包函证书和私钥.

* .jks - 即Java Key Storage,这是Java的专利,利用Java的一个叫"keytool"的工具,可以将PFX转为JKS.

格式转换:

```
DER to PEM: 
openssl x509 -in  <der certificate file> -inform PEM 
-out <pem certificate file> -outform DER 

PEM to DER: 
openssl x509 -in  <pem certificate file> -inform DER  
-out <der certificate file> -outform PEM 
```

### <span id = "X.509证书示例">X.509证书示例</span>
```
$ openssl x509 -in nginx.pem -noout -text
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            f8:45:2b:8c:ab:a0:e9:0d
        Signature Algorithm: sha1WithRSAEncryption
        Issuer: C=CN, ST=GD, L=Default City, O=www.fastweb.com.cn, OU=jd/emailAddress=liuheng@fastweb.com.cn
        Validity
            Not Before: Jan 12 09:14:48 2017 GMT
            Not After : Feb 11 09:14:48 2017 GMT
        Subject: C=CN, ST=GD, L=guangzhou, O=www.fastweb.com.cn, OU=dev, CN=test.keyless.cn/emailAddress=liuheng@fastweb.com.cn
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
            RSA Public Key: (2048 bit)
                Modulus (2048 bit):
                    00:b4:73:84:b9:01:78:04:d3:d0:4c:eb:72:07:1a:
                    bb:f0:16:16:6e:3f:43:9a:0b:8b:0e:b6:10:0c:0f:
                    d3:71:86:ed:ac:a8:9c:9d:42:97:0d:25:8e:94:ab:
                    fa:b5:aa:63:d9:05:48:8c:41:27:36:b9:89:3f:6d:
                    bb:29:1a:be:8f:c9:d0:fc:7d:d6:d6:4b:9e:21:44:
                    ba:b4:b1:cd:7d:60:1d:e3:ac:6e:11:b2:1e:2d:b1:
                    31:da:d9:9e:01:84:26:97:f0:c5:07:0e:0e:3d:72:
                    ea:0c:f1:e6:7e:49:c5:de:92:f4:59:19:23:d9:cb:
                    2c:43:19:75:9d:ce:9e:87:5b:1d:9a:30:48:4c:d3:
                    25:55:6b:f0:55:6a:ac:99:33:a3:03:b9:f0:34:c2:
                    78:a3:67:cd:9d:b9:9d:e6:b3:87:bc:ef:69:17:f1:
                    d7:43:84:0e:7c:6c:22:66:05:34:fa:91:39:e2:40:
                    22:e7:24:ec:32:44:77:c3:19:d2:31:8f:37:67:06:
                    f3:43:9d:55:c5:2f:06:e4:20:c7:7f:c8:78:75:cd:
                    7f:de:a2:86:f0:b3:ca:d1:39:c7:da:7c:06:6c:b2:
                    94:9b:4c:0a:99:17:3a:40:c8:a2:27:d0:df:3b:77:
                    5e:52:30:31:00:85:99:2c:0c:e6:f0:ec:ed:05:7b:
                    06:35
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Basic Constraints: 
                CA:FALSE
            X509v3 Key Usage: 
                Digital Signature, Non Repudiation, Key Encipherment
            X509v3 Subject Alternative Name: 
                IP Address:127.0.0.1
    Signature Algorithm: sha1WithRSAEncryption
        0e:fc:ad:43:19:42:25:45:5b:20:ba:0f:74:fe:51:61:32:44:
        c4:df:09:d5:0a:b2:5f:6a:2d:35:09:3a:ea:ce:5c:e2:92:40:
        13:d6:f8:ec:e4:82:86:9d:49:70:07:a4:09:a7:f8:6d:11:35:
        c2:e4:bd:ad:5a:14:79:ff:64:83:de:f8:1c:29:9d:9e:96:23:
        2b:e9:be:eb:ec:56:e2:68:18:48:a9:8e:05:f4:9e:0c:8c:2c:
        c6:fa:a4:63:81:25:99:44:57:ff:e5:2c:b2:5c:a8:79:25:90:
        b5:68:ce:48:8b:0b:ed:3c:da:ec:62:97:95:03:d8:ff:b7:7e:
        12:cc:dd:f0:c8:a5:bb:ed:2a:fe:92:51:e0:b3:5c:d6:39:8b:
        32:ac:20:bb:34:63:3a:d1:5f:5b:4c:08:8b:d9:25:f1:43:9b:
        c1:c2:5c:7d:16:74:a7:4b:26:56:40:ed:3e:eb:37:92:f5:10:
        61:64:ec:24:f5:d0:ac:2c:fe:41:f1:c0:94:fc:9c:40:ce:91:
        04:07:c1:20:22:1e:5e:69:64:ee:1d:b2:91:5e:97:7d:e8:5c:
        58:9a:51:6d:7a:3c:5e:ad:f3:2a:7a:7e:9c:1a:b1:d8:89:24:
        db:52:94:4e:3b:90:e2:d9:f5:f0:ea:11:52:15:8a:2b:e2:9a:
        2a:da:ad:21
```



## keyless简介


## cloudflare的实现

## VFCC.keyless安装使用
VFCC.keyless随VFCC安装包一起发布，但是可以独立部署。

包含keylessProxy、priKeyServer、pubKeyServer三个程序：

* keylessProxy：

 部署在业务服务器上，监听443（htts）端口。代理tls协议处理，转发请求到80（http）或任何业务处理服务上。使原先不支持https的业务服务可以处理https/http2.0请求。

* priKeyServer：

 标准keyless(cloudflare发布标准)实现的keyserver角色，用于保存私钥。应该部署在客户的服务器上，以达到不用提供私钥而使用https服务的效果。

* pubKeyServer：

 部署在独立的服务器集群上；作用是集中管理证书，使业务服务器上不存在https证书；由keylessProxy在首次收到请求的时候动态加载。

服务拓扑如下：

 ![服务拓扑](https://www.sixianed.com/images/tuopu.png)


###配置

* keylessProxy：

```
{
	# 服务监听在哪个网络端口;
	"addr": ":443",
    
    # 要代理请求到业务服务的地址，支持tcp和unix domain socket;
    "targetAddr": "tcp 127.0.0.1:8080",
    
    # DNS服务器，不同的priKeyServer域解析到多个A记录用于负载均衡。
    "resolvers": ["127.0.0.2:10001", "127.0.0.2:10002"],
    
    # 证书服务地址，支持多条主备;
    "pubKeyServer": ["127.0.0.1:10001", "127.0.0.1:10000"],
    
    # 相当于http的cookie，同一集群应该配成相同值;
    "sessionTicketKey": "When you forgive, you love. And When you love, god's light shines on you",
    
    # 用于和priKeyServer双向认证的证书;
    "proxyCert": "data/client.pem",
    "proxyKey": "data/client.key",
    "proxyCA": "data/cacert.pem",  

	# 域名相关配置;
    "hosts":{
    "www.demo.com":{
        "keyServerAddr": "www.keyless.vfcc.com.cn:2412",
        "keyServerCA": "data/cacert.pem"
        }
    }
}

```
* priKeyServer：

```
{
	# 服务监听在哪个网络端口;
	"addr": ":2412",
	
	# 用于和keylessProxy建立双向认证tls通信；
	"cert":"keys/demo.pem",
	"key":"keys/demo.key",
	"cacert":"data/cacert.pem",
	
	# 存在所有私钥的路径；
	"privKeyDir":"./keys"
}
```

* pubKeyServer：

```
{
	# 服务监听在哪个网络端口;
	"addr": ":10000",
	
	# 用于和keylessProxy建立tls通信；
	"cert": "data/pubserver.pem",
	"key": "data/pubserver.key",
	
	# 只有配在这里的ip允许询问；
	"whiteip": "127.0.0.1 127.0.0.2",
    
    # 域名相关配置;
    "hosts":{
        "www.demo.com": "./certs/demo.pem"
    }
}
```


