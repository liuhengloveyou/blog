---
title: TLS1.3协议文档
comments: true
date: 2017-12-07 17:15:19
time: 1512638119
tags:
	- tls
categories: web
---


**The Transport Layer Security (TLS) Protocol Version 1.3**

[draft-ietf-tls-tls13-22](https://tools.ietf.org/html/draft-ietf-tls-tls13-22)



## 1. 简介

TLS的主要目标是在通信两者之间提供安全通道。具体来说，这个通道应该提供以下属性：

- 身份验证：通道的服务端身份应该始终是被认证的; 客户端可选地被认证。身份验证可以通过非对称密码实现（例如：RSA，ECDSA，EdDSA）或共享密钥（PSK）。

- 保密性：通过加密通道发送的数据只对通信双方可见。TLS并不隐藏它传输的数据的长度，尽管通信双方为改进防范流量分析措施，能够填充TLS记录以便模糊长度。

- 完整性：在加密通道上发送的数据不能被攻击者修改。

即使面对完全控制网络的攻击者，这些属性也应该是为真的，如[ RFC3552 ]中所述。

TLS协议由两个主要组件组成：

- 握手协议，为通信双方做身份认证，协商密码模式和参数，并建立共享密钥资料。握手协议旨在防止篡改； 如果连接没有受到攻击，主动攻击者不应该强迫对等点协商不同的参数。

- 记录协议，它使用握手协议所建立的参数来保护通信双方之间的通信。记录协议将流量划分为一系列的记录，每个记录都是独立地使用通信密钥保护的。

TLS是应用协议独立的；更高层的协议可以透明地运行在TLS之上。然而，TLS标准没有说明协议如何与TLS增加安全性；如何启动TLS握手以及如何解释交换的身份验证证书，都留给了在TLS之上运行的协议的设计者和实现者的判断。

本文档定义了TLS1.3。虽然TLS 1.3不是直接的与以前的版本兼容，TLS的所有版本都包含一个版本控制机制，允许客户端和服务器 -- 如果双方都支持共同版本 -- 可互操作协商通信。

### 1.3. 与TLS1.2的主要区别：

以下是TLS 1.2和TLS 1.3之间主要功能的差异列表。 它并不是详尽无遗的，也有许多细微的差别。

- 支持的对称算法列表已经删除了所有被认为是过时的算法。 保留了所有使用AEAD的加密算法。 加密套件概念已经被改变，从记录保护算法（包括密钥长度）和一个用于密钥生成函数的hash和HMAC中分离为：认证、密钥交换机制。

- 添加0-RTT模式，以某些安全属性为代价，通过在连接中设置一些应用数据节省了一个往返。

- 静态RSA和Diffie-Hellman密码套件已被删除;所有基于公钥的密钥交换机制现在都提供了向前保密。

- ServerHello之后的所有握手消息都被加密了。新引入的EncryptedExtension消息允许以前在ServerHello中发送的各种扩展也可以享受保密性。

- 密钥导出函数已被重新设计。 新设计允许密码学家更容易地分析，因为它们改进了密钥分离属性。 HMAC-based Extract-and-Expand Key Derivation Function（HKDF）被用作一个基本的原语。

- 握手状态机已经进行了重大调整，使其更加一致，并且消除了如ChangeCipherSpec的多余的消息。

- 椭圆曲线算法(ECC)现在在基本规范中，包括新的签名算法，如ed25519和ed448。TLS 1.3移除点格式协商，支持每条曲线的单点格式。

- 其他加密改进，包括删除压缩和自定义DHE组，更改RSA填充以使用PSS，以及删除DSA。

- TLS 1.2版本协商机制已被弃用，支持在扩展中使用版本列表。 这增加了与错误实现版本协商的服务器的兼容性。

- 在没有服务器端状态和早期TLS版本的基于pskbased的ciphersuite的会话中，会话恢复被一个新的PSK交换取代。


### 1.4. 对TLS1.2产生影响的更新：

本文档定义了可能影响TLS 1.2实现的若干变更：

- 版本降级保护机制(4.1.3.)。
- RSA SSA-PSS签名方案(4.2.3.)。
- “supported_versions”  在ClientHello扩展中可用于协商要使用的TLS版本，优先于ClientHello的legacy_version字段。

TLS 1.3的实现也支持TLS 1.2，即使在没有使用TLS 1.3时，也需要包括更改以支持这些更改。有关更多细节见下文。

## 2. 协议概述

安全通道使用的加密参数由TLS握手协议生成。客户机和服务器在第一次通信时使用了TLS的这个子协议。握手协议允许对等点协商一个协议版本，选择加密算法，选择性地对彼此进行身份验证，并建立共享密钥。当握手完成后，对等点使用已确定的密钥来保护应用程序层的流量。

握手失败或其他协议错误触发连接的终止，可选在发出警告消息之前(第6节)。

**TLS支持三种基本的密钥交换模式**：

- (EC)DHE (Diffie-Hellman both the finite field and elliptic curve varieties)
- PSK-only
- PSK with (EC)DHE

图1：展示了基本的TLS握手过程:

```
Client                                               Server

Key  ^ ClientHello
Exch | + key_share*
     | + signature_algorithms*
     | + psk_key_exchange_modes*
     v + pre_shared_key*         -------->
                                                       ServerHello  ^ Key
                                                      + key_share*  | Exch
                                                 + pre_shared_key*  v
                                             {EncryptedExtensions}  ^  Server
                                             {CertificateRequest*}  v  Params
                                                    {Certificate*}  ^
                                              {CertificateVerify*}  | Auth
                                                        {Finished}  v
                                 <--------     [Application Data*]
     ^ {Certificate*}
Auth | {CertificateVerify*}
     v {Finished}                -------->
       [Application Data]        <------->      [Application Data]

              +  Indicates noteworthy extensions sent in the
                 previously noted message.

              *  Indicates optional or situation-dependent
                 messages/extensions that are not always sent.

              {} Indicates messages protected using keys
                 derived from a [sender]_handshake_traffic_secret.

              [] Indicates messages protected using keys
                 derived from [sender]_application_traffic_secret_N
```

握手可以被认为有三个阶段(上图所示):

- 密钥交换：建立共享密钥材料并选择加密参数。 此阶段后的所有内容都已加密。
- 服务器参数：建立其他握手参数（客户端是否认证，应用层协议支持等）。
- 身份验证：验证服务器(以及客户端)，并提供密钥确认和握手完整性。

在**密钥交换**阶段，客户端发送ClientHello（第4.1.2节）消息，其中包含一个随机数（ClientHello.random）；其提供的协议版本；对称密码/ HKDF哈希对的列表；一些Diffie-Hellman密钥共享（在“key_share”扩展第4.2.7节），一组预共享密钥标签（在“pre_shared_key”扩展第4.2.10节中）或两者；以及潜在的一些其他扩展。

服务器处理ClientHello并确定连接的加密**参数**。 然后它用自己的ServerHello（第4.1.3节）进行响应，并指定协商的连接参数。 ClientHello和ServerHello的组合决定了共享密钥。（1） 如果使用（EC）DHE密钥建立，则ServerHello包含一个“key_share”扩展，服务器的短暂Diffie-Hellman共享必须与客户端的一个共享在同一个组中。 （2）如果使用PSK密钥建立，则ServerHello包含一个“pre_shared_key”扩展，指示客户端提供的PSK 哪个被选择。 （3）一起使用（EC）DHE和PSK，在这种情况下，两个扩展都将被提供。

服务器发送两条信息去建立服务器参数：

**EncryptedExtensions**：对ClientHello扩展的响应，不需要确定加密参数，而不是特定于各个证书的加密参数。 [第4.3.1节]

**CertificateRequest**：如果需要基于证书的客户端身份验证，则所需参数是证书。 如果不需要客户端认证，则省略此消息。 [第4.3.2节]

最终，客户端和服务器交换**认证**消息。

**Certificate**：证书和证书扩展。 服务器如果不通过证书进行身份验证，并且如果服务器没有发送CertificateRequest（由此指示客户端不应该使用证书进行身份验证），客户端将忽略此消息。 请注意，如果使用原始公钥[RFC7250]或缓存信息扩展[RFC7924]，则此消息将不包含证书，而是包含与服务器长期密钥相对应的其他值。 [第4.4.2节]

**CertificateVerify**：使用与证书消息中的公钥相对应的私钥对整个握手进行签名。 如果不验证证书，则省略此消息。 [第4.4.3节]

**Finished**：整个握手消息的MAC（消息验证码）。 该消息提供密钥确认，将端点的身份与交换的密钥绑定，并且也可以在PSK模式验证握手。 [第4.4.4节]

此时，握手完成，客户端和服务器可以交换应用层数据。 **在发送 Finished 消息之前不得发送应用程序数据**。 请注意，虽然服务器可能在接收到客户端的认证消息之前发送应用程序数据，但是当时发送的任何数据当然都将发送到未认证的对端。

### 2.1.  不正确的 **DHE Share**

如果客户端没有提供足够的“key_share”扩展（例如，它只包含服务器不可接受或不支持的DHE或ECDHE组），则服务器将使用 **HelloRetryRequest **来纠正不匹配，然后客户端需要使用合适的 “key_share”扩展重新启动握手，如图2所示。如果无法协商通用的密码参数，服务器必须以适当的警报中止握手。

```
         Client                                               Server

         ClientHello
         + key_share             -------->
                                 <--------         HelloRetryRequest
                                                         + key_share

         ClientHello
         + key_share             -------->
                                                         ServerHello
                                                         + key_share
                                               {EncryptedExtensions}
                                               {CertificateRequest*}
                                                      {Certificate*}
                                                {CertificateVerify*}
                                                          {Finished}
                                 <--------       [Application Data*]
         {Certificate*}
         {CertificateVerify*}
         {Finished}              -------->
         [Application Data]      <------->        [Application Data]
```
图2：具有不匹配参数的完整握手的消息流

注意：握手记录包括初始的ClientHello / HelloRetryRequest交换；它没有被重新设置为新的ClientHello。

TLS还允许几个基本的握手的优化变种，如下面的部分所述。

### 2.2.  复用(Resumption)和预共享密钥(Pre-Shared Key (PSK))

虽然TLS PSKs可以在带外建立，PSK也可以在先前的连接中建立然后重新使用（“复用”）。一旦握手完成，服务器可以向客户端发送一个对应于从初始握手导出的密钥的PSK标识（见第4.6.1节）。 客户端可以在将来的握手中使用该PSK身份来协商使用PSK。 如果服务器接受它，则新连接的安全上下文与原始连接相关联，并且使用从初始握手导出的密钥来引导加密状态而不是完全握手。 在TLS 1.2及以下版本中，此功能由“session IDs”和“session tickets”[RFC5077]提供。“session IDs”和“session tickets”这两种机制都在TLS 1.3中被淘汰。

PSK可以与（EC）DHE密钥交换一起使用，以提供与共享密钥相结合的前向保密，或者可以单独使用，以牺牲保密性为代价。

图3：复用和PSK的消息流：（显示出一对握手，其中第一个建立PSK，第二个使用它）：

```
       Client                                               Server

Initial Handshake:
       ClientHello
       + key_share               -------->
                                                       ServerHello
                                                       + key_share
                                             {EncryptedExtensions}
                                             {CertificateRequest*}
                                                    {Certificate*}
                                              {CertificateVerify*}
                                                        {Finished}
                                 <--------     [Application Data*]
       {Certificate*}
       {CertificateVerify*}
       {Finished}                -------->
                                 <--------      [NewSessionTicket]
       [Application Data]        <------->      [Application Data]


Subsequent Handshake:
       ClientHello
       + key_share*
       + psk_key_exchange_modes
       + pre_shared_key          -------->
                                                       ServerHello
                                                  + pre_shared_key
                                                      + key_share*
                                             {EncryptedExtensions}
                                                        {Finished}
                                 <--------     [Application Data*]
       {Finished}                -------->
       [Application Data]        <------->      [Application Data]
```

当服务器通过PSK进行身份验证时，它不会发送 Certificate 或 CertificateVerify 消息。 当客户端通过PSK恢复时，它还应该为服务器提供一个“key_share”扩展，以允许服务器拒绝恢复，如果需要，可以恢复到完全握手。 服务器用“pre_shared_key”扩展进行响应以协商使用PSK密钥建立，并且可以（如此处所示）用“key_share”扩展来响应（EC）DHE密钥建立，从而提供前向保密。

当PSK设置为带外时，PSK标识和与PSK一起使用的KDF也必须被提供。 注意：在使用带外提供的预共享密钥时，关键考虑是在密钥生成期间使用足够的熵，如[RFC4086]中所述。

### 2.3. 0-RTT 数据

当客户端和服务器共享一个PSK（从外部获取或通过先前的握手获得）时，TLS 1.3允许客户端在first flight上发送数据（“early data”）。 客户端使用PSK认证服务器并对早期数据进行加密。

当客户使用外部获取的PSK发送早期数据时，则必须向双方提供以下附加信息：

- 与PSK一起使用的加密套件
- 应用层协议协商（Application-Layer Protocol Negotiation, ALPN）协议，如果有的话将被使用
- 服务器名称指示（Server Name Indication, SNI），如果有的话将被使用

图4：0-RTT握手的消息流

```
 Client                                               Server

         ClientHello
         + early_data
         + key_share*
         + psk_key_exchange_modes
         + pre_shared_key
         (Application Data*)     -------->
                                                         ServerHello
                                                    + pre_shared_key
                                                        + key_share*
                                               {EncryptedExtensions}
                                                       + early_data*
                                                          {Finished}
                                 <--------       [Application Data*]
         (EndOfEarlyData)
         {Finished}              -------->

         [Application Data]      <------->        [Application Data]

               +  Indicates noteworthy extensions sent in the previously noted message.

               *  Indicates optional or situation-dependent messages/extensions that are not always sent.

               () Indicates messages protected using keys derived from client_early_traffic_secret.

               {} Indicates messages protected using keys derived from a [sender]_handshake_traffic_secret.

               [] Indicates messages protected using keys derived from traffic_secret_N
```

**重要说明**：0-RTT数据的安全属性比其他类型的TLS数据的安全属性弱。这个数据不是转发的秘密，因为它只是使用提供的PSK导出的密钥进行加密。特别：

1. 该数据不是前向保密，因为其仅在使用所提供的PSK导出的密钥下加密。

2. 连接之间不保证防重放。 除非服务器采用TLS以外的特殊措施，否则服务器不能保证相同的0-RTT数据在多个0-RTT连接上不被发送（更多详细信息，请参见第4.2.10.4节）。 如果数据通过TLS客户端认证或应用层协议进行身份验证，这一点尤为重要。 然而，0-RTT数据不能在连接中重复（即，服务器不会为相同的连接处理相同的数据两次），并且攻击者将无法使0-RTT数据看起来是1-RTT数据（ 因为它是用不同的密钥保护的。）

   重放攻击（Replay Attacks）是指攻击者发送一个接收方已经正常接收过的包。由于重放的数据包是过去的一个有效数据包，如果没有防重放的处理，接收方是没办法辨别出来的。


3. 没有定义其使用的配置文件，协议不得使用0-RTT数据。该配置文件需要确定哪些消息或交互可安全地与0-RTT一起使用。此外，为了避免意外误用，除非特别要求，否则实现不应该启用0-RTT。实现应该为0-RTT数据提供特殊功能，以确保应用程序总是知道它正在发送或接收可能被重放的数据。

## 3. 描述语言

该文档处理外部表示中的数据格式。下面将使用非常基本的和稍微随意定义的表示语法。

### 3.1. Basic Block Size

## 4. 握手协议

握手协议用于协商连接的安全参数。握手消息被提供给TLS记录层，它们被封装在一个或多个TLSPlaintext或TLSCiphertext结构中，这些结构经过当前活动连接状态的指定处理和传输。

```
enum {
	client_hello(1),
	server_hello(2),
	new_session_ticket(4),
	end_of_early_data(5),
	encrypted_extensions(8),
	certificate(11),
	certificate_request(13),
	certificate_verify(15),
	finished(20),
	key_update(24),
	message_hash(254),
	(255)
} HandshakeType;

struct {
	HandshakeType msg_type;    /* handshake type */
	uint24 length;             /* bytes in message */
	select (Handshake.msg_type) {
		case client_hello:          ClientHello;
		case server_hello:          ServerHello;
		case end_of_early_data:     EndOfEarlyData;
		case encrypted_extensions:  EncryptedExtensions;
		case certificate_request:   CertificateRequest;
		case certificate:           Certificate;
		case certificate_verify:    CertificateVerify;
		case finished:              Finished;
		case new_session_ticket:    NewSessionTicket;
		case key_update:            KeyUpdate;
	};
} Handshake;
```

协议信息必须按照第4.4.1节中定义的并在第2节的图中显示的顺序发送。 以意外顺序接收握手消息的对端必须使用“unexpected_message”警报中止握手。

新的握手消息类型由IANA指派，如第11节所述。

### 4.1. 密钥交换消息

密钥交换消息用于交换客户端和服务器之间的安全功能，并建立用于保护握手和数据的通信密钥。

### 4.1.1. 密码谈判

在TLS中，客户端在ClientHello中为密码谈判提供以下四组选项:

- 一个密码套件列表，显示了客户端支持的AEAD算法/ HKDF哈希对。
- 一个“supported_groups”（第4.2.4节）扩展，指示客户端支持的(EC)DHE组的和包含这些组中的一些或全部的（EC)DHE共享的“key_share”扩展（第4.2.5节）。
- 一个“signature_algorithms”（第4.2.3节）扩展，指示客户端可以接受的签名算法的。
- 一个“pre_shared_key”（第4.2.8节）扩展，包含客户端已知的对称密钥身份列表的和指示可与PSK一起使用的密钥交换模式的“psk_key_exchange_modes”扩展（第4.2.6节）。

如果服务器没有选择PSK，则这些选项中的前三个是完全不相关的：服务器独立地选择密码套件，用于密钥建立的(EC)DHE组和密钥共享，以及签名算法/证书对，以认证本身给客户端。如果在“supported_groups”中没有重叠，则服务器必须中止握手。

如果服务器选择一个PSK，它还必须从客户端的“psk_key_exchange_modes”扩展（PSK单独或与(EC)DHE）指示的集合中选择密钥建立模式。注意，如果PSK可以在没有(EC)DHE的情况下使用，则在“supported_groups”参数中的非重叠不需要是致命的，因为它在前面段落中讨论的非PSK情况下。

如果服务器选择(EC)DHE组，并且客户端在初始ClientHello中没有提供兼容的“key_share”扩展名，则服务器必须使用HelloRetryRequest（第4.1.4节）消息进行响应。

如果服务器成功地选择了参数，并且不需要HelloRetryRequest，则它会在ServerHello中指示所选参数，如下所示：

- 如果正在使用PSK，那么服务器将发送一个“pre_shared_key”扩展，指明所选择的密钥。
- 如果不使用PSK，则总是使用（EC）DHE和基于证书的认证。
- 当（EC）DHE正在使用时，服务器还将提供“key_share”扩展。
- 当通过证书进行认证时（即，当PSK未使用时），服务器将发送证书（第4.4.1节）和CertificateVerify（第4.4.2节）消息。


如果服务器无法协商出支持的参数集(例如:在客户端和服务器参数之间没有重叠，它必须以 “handshake_failure” 或 “insufficient_security” 警告(第6节)来终止握手。

### 4.1.2. Client Hello

当客户端首次连接服务器时，它需要发送的第一条消息应该是ClientHello。当服务器使用HelloRetryRequest响应其ClientHello时，客户端也应该发送ClientHello消息。在这种情况下，客户端必须发送相同的ClientHello（不修改），除了下列情况：

- 如果HelloRetryRequest中提供了“key_share”扩展，那么将列表中的共享列表替换为来自指定组的单个 KeyShareEntry 列表。
- 删除“early_data”扩展（第4.2.7节）如果存在。 HelloRetryRequest后不允许使用“early_data”。
- 包括“cookie”扩展，如果在HelloRetryRequest中提供了一个“cookie”。
- 如果通过重新计算“obfuscated_ticket_age”和绑定值，并(可选地)删除与服务器指示的密码套件不兼容的任何PSKs，就可以更新“pre_shared_key”扩展。
- 可选的添加、删除、更新 "padding" extension [RFC7685]的长度。

因为TLS 1.3禁止重新谈判，如果一个服务器已经协商了TLS1.3并在任何其他时间接收到一个ClientHello，它必须发送"unexpected_message"终止连接。

如果一个服务器建立了一个老版本的TLS连接，并且在重新谈判中收到TLS 1.3 “ClientHello”，它必须保留之前的协议版本。特别是，它不能协商TLS 1.3。

这个消息的结构：

```c
uint16 ProtocolVersion;
opaque Random[32];

uint8 CipherSuite[2];    /* Cryptographic suite selector */

struct {
	ProtocolVersion legacy_version = 0x0303;    /* TLS v1.2 */
	Random random;
	opaque legacy_session_id<0..32>;
	CipherSuite cipher_suites<2..2^16-2>;
	opaque legacy_compression_methods<1..2^8-1>;
	Extension extensions<8..2^16-1>;
} ClientHello;
```

 

TLS 1.3 ClientHellos将至少包含两个扩展名“supported_versions”以及“key_share”或“pre_shared_key”。

扩展的存在可以通过确定在ClientHello的结尾处是否存在跟在compression_methods之后的字节来检测。

 

【legacy_version】
在TLS的先前版本中，此字段用于版本协商，表示客户端支持的最高版本号。在TLS 1.3中，客户端在“supported_versions”扩展中指示其版本首选项（第4.2.1节），并且legacy_version字段必须设置为0x0303，这是TLS 1.2的版本号。 
【random】
32字节由安全随机数生成器生成。
【legacy_session_id】
TLS在TLS 1.3之前的版本支持会话恢复功能，已在此版本中与预共享密钥合并（见第2.2节）。该字段必须被协商TLS 1.3的服务器忽略，并且必须由不具有由pre-TLS 1.3服务器设置的高速缓存的会话ID的客户端设置为零长度向量（即，单个零字节长度字段）。
【cipher_suites】
这是客户端支持的对称密码选项的列表，特别是记录保护算法（包括秘密密钥长度）和要与HKDF一起使用的哈希，以客户端偏好的降序排列。如果列表包含密码套件，服务器不能识别，支持或希望使用，则服务器必须忽略这些密码套件，并照常处理剩余的套件。值在附录B.4中定义。如果客户端正在尝试PSK密钥建立，则它应当通告至少一个包含与PSK相关联的哈希的加密套件。
【legacy_compression_methods】
TLS 1.3之前的版本支持压缩，并在此字段中发送支持的压缩方法列表。对于每个TLS 1.3 ClientHello，该向量必须精确地包含一个设置为零的一个字节，其对应于TLS的先前版本中的“null”压缩方法。如果接收到TLS 1.3 ClientHello与此字段中的任何其他值，则服务器必须使用“illegal_parameter”警报中止握手。请注意，TLS 1.3服务器可能接收TLS 1.2或之前的ClientHellos，其中包含其他压缩方法，并且必须遵循TLS的相应先前版本的过程。
【extensions】
客户端通过在扩展字段中发送数据，从服务器请求扩展功能。实际的“扩展”格式在第4.2节中定义。在TLS 1.3中，使用某些扩展是强制性的，因为功能被移动到扩展中以保持ClientHello与先前版本的TLS的兼容性。

如果客户端请求使用扩展的附加功能，并且该功能不是由服务器提供的，则客户端可以中止握手。 请注意，TLS 1.3 ClientHello消息始终包含扩展（最低限度必须包含“supported_versions”或它们将被解释为TLS 1.2 ClientHello消息）。 TLS 1.3服务器可能从不包含扩展名的1.3之前的TLS版本接收ClientHello消息。 如果在1.3之前协商TLS的版本，服务器必须检查消息在legacy_compression_methods之后是否包含数据，或者它包含没有数据跟随的有效扩展块。 如果不是，那么它必须用“decode_error”警报来中止握手。

如果客户端使用扩展名请求附加功能，并且此功能不由服务器提供，客户端可能会中止握手。

发送ClientHello消息后，客户端等待ServerHello或HelloRetryRequest消息。

### [4.1.3.](https://tlswg.github.io/tls13-spec/#rfc.section.4.1.3) [Server Hello](https://tlswg.github.io/tls13-spec/#server-hello)

能够找到可接受的一组算法并且客户端的“key_share”扩展是可接受的

```
   struct {
       ProtocolVersion version;
       Random random;
       CipherSuite cipher_suite;
       Extension extensions<6..2^16-1>;
   } ServerHello;
```

 

服务器必须从

ClientHello.supported_versions

扩展中的列表中选择一个版本

**0x0304**

【

random

】

由安全随机数生成器生成的随机32字节。有关其他信息，请参阅附录C.如果协商TLS 1.2或TLS 1.1，最后8个字节必须被覆盖。该结构由服务器生成，必须独立于ClientHello.random生成。

cipher_suite

【

extensions

】

 

目前唯一这样的扩展是“key_share”和“pre_shared_key”

两个扩展之一

TLS 1.3具有嵌入在服务器的随机值中的**降级保护机制**。 TLS 1.3服务器协商TLS 1.2或以下响应ClientHello必须专门设置其随机值的最后8个字节。
如果协商TLS 1.2，服务器必须设置其随机值的最后8个字节为：

```
  44 4F 57 4E 47 52 44 01
  D  O  W  N  G  R  D   
```

TLS 1.1

最后8个字节

```
  44 4F 57 4E 47 52 44 00
```

TLS 1.3客户端

**不等于**

不等于

如果找到匹配，客户端必须用“illegal_parameter”警报中止握手。

防止降级攻击

在重新协商期间接收TLS 1.3 ServerHello的客户端必须使用“protocol_version”警报中止握手。注意，重新协商只针对先于TLS1.3的版本。

### [4.1.4.](https://tlswg.github.io/tls13-spec/#rfc.section.4.1.4) [Hello Retry Request](https://tlswg.github.io/tls13-spec/#hello-retry-request)

如果服务器能够找到相互支持的可接受的一组算法和组，但是客户端的ClientHello没有包含足够的信息来继续握手，则服务器发送此消息以响应ClientHello消息。

如果服务器无法成功选择算法和组，则必须使用“handshake_failure”警报中止握手。

```
   struct {
       ProtocolVersion server_version;
       CipherSuite cipher_suite;
       Extension extensions<2..2^16-1>;
   } HelloRetryRequest;
```

server_version和extensions与ServerHello中的相应值具有相同的含义。服务器应该只发送客户端生成正确的ClientHello对所需的扩展。与ServerHello一样，HelloRetryRequest不得包含客户端在其ClientHello中不是首次提供的任何扩展，但可选的“cookie”扩展（见第4.2.2节）除外。

在接收到HelloRetryRequest时，客户端必须验证扩展块不为空，否则必须使用“decode_error”警报中止握手。如果HelloRetryRequest不会导致ClientHello的任何更改，客户端必须使用“illegal_parameter”警报中止握手。如果客户端在同一连接中接收到第二个HelloRetryRequest（即ClientHello本身响应于HelloRetryRequest），则它必须用“unexpected_message”警报中止握手。

客户端必须处理HelloRetryRequest中的所有扩展，并发送第二个更新的ClientHello

- cookie（见第4.2.2节）
- key_share（见第4.2.5节）

此外，在其更新的ClientHello中，客户端不应提供与所选密码套件以外的哈希相关联的任何预共享密钥。 这允许客户端避免在第二个ClientHello中计算多个散列的部分哈希转录。 接收未提供的密码套件的客户端必须中止握手。 服务器必须确保在接收到一致的更新ClientHello时协商相同的密码套件（如果服务器选择密码套件作为协商的第一步，则会自动发生）。客户端收到ServerHello后必须检查ServerHello中提供的密码套件是否与HelloRetryRequest中的密码套件相同，否则将以“illegal_parameter”警报中止握手。

### 4.2. 扩展（Extensions） 

 tag-length-value

```
   struct {
       ExtensionType extension_type;
       opaque extension_data<0..2^16-1>;
   } Extension;

   enum {
       server_name(0),                                /* RFC 6066 */
       max_fragment_length(1),                        /* RFC 6066 */
       status_request(5),                             /* RFC 6066 */
       supported_groups(10),                          /* RFC 4492, 7919 */
       signature_algorithms(13),                      /* RFC 5246 */
       use_srtp(14),                                  /* RFC 5764 */
       heartbeat(15),                                 /* RFC 6520 */ 
       application_layer_protocol_negotiation(16),    /* RFC 7301 */
       signed_certificate_timestamp(18),              /* RFC 6962 */
       client_certificate_type(19),                   /* RFC 7250 */
       server_certificate_type(20),                   /* RFC 7250 */
       padding(21),                                   /* RFC 7685 */
       key_share(40),                                 /* [[this document]] */
       pre_shared_key(41),                            /* [[this document]] */
       early_data(42),                                /* [[this document]] */
       supported_versions(43),                        /* [[this document]] */
       cookie(44),                                    /* [[this document]] */
       psk_key_exchange_modes(45),                    /* [[this document]] */
       certificate_authorities(47),                   /* [[this document]] */
       oid_filters(48),                               /* [[this document]] */
       post_handshake_auth(49),                       /* [[this document]] */
       (65535)
   } ExtensionType;
```

- “extension_type”标识特定的扩展类型。
- “extension_data”包含特定于该特定扩展类型的信息。

请求/响应

如果远程端点没有发送相应的扩展请求，除了HelloRetryRequest中的“cookie”扩展之外，实现不得发送扩展响应。在接收到这样的扩展时，端点必须用“unsupported_extension”警报中止握手。

下表列出了可以使用以下符号显示给定扩展名的消息：：CH（ClientHello），SH（ServerHello），EE（EncryptedExtensions），CT（Certificate），CR（CertificateRequest），NST（NewSessionTicket）和HRR ( HelloRetryRequest）。如果实现接收到它识别的扩展，并且没有为它出现的消息指定它，它必须用“illegal_parameter”警报来中止握手。

| Extension                                | TLS 1.3     |
| ---------------------------------------- | ----------- |
| server_name [[RFC6066\]](https://tlswg.github.io/tls13-spec/#RFC6066) | CH, EE      |
| max_fragment_length [[RFC6066\]](https://tlswg.github.io/tls13-spec/#RFC6066) | CH, EE      |
| ~~client_certificate_url [RFC6066]~~     | CH, EE      |
| status_request [[RFC6066\]](https://tlswg.github.io/tls13-spec/#RFC6066) | CH, CT      |
| ~~user_mapping [RFC4681]~~               | CH, EE      |
| ~~cert_type [RFC6091]~~                  | CH, EE      |
| supported_groups [[RFC7919\]](https://tlswg.github.io/tls13-spec/#RFC7919) | CH, EE      |
| signature_algorithms [[RFC5246\]](https://tlswg.github.io/tls13-spec/#RFC5246) | CH, CR      |
| use_srtp [[RFC5764\]](https://tlswg.github.io/tls13-spec/#RFC5764) | CH, EE      |
| heartbeat [[RFC6520\]](https://tlswg.github.io/tls13-spec/#RFC6520) | CH, EE      |
| application_layer_protocol_negotiation [[RFC7301\]](https://tlswg.github.io/tls13-spec/#RFC7301) | CH, EE      |
| signed_certificate_timestamp [[RFC6962\]](https://tlswg.github.io/tls13-spec/#RFC6962) | CH, CR, CT  |
| client_certificate_type [[RFC7250\]](https://tlswg.github.io/tls13-spec/#RFC7250) | CH, EE      |
| server_certificate_type [[RFC7250\]](https://tlswg.github.io/tls13-spec/#RFC7250) | CH, CT      |
| padding [[RFC7685\]](https://tlswg.github.io/tls13-spec/#RFC7685) | CH          |
| key_share [[this document]]              | CH, SH, HRR |
| pre_shared_key [[this document]]         | CH, SH      |
| psk_key_exchange_modes [[this document]] | CH          |
| early_data [[this document]]             | CH, EE, NST |
| cookie [[this document]]                 | CH, HRR     |
| supported_versions [[this document]]     | CH          |
| certificate_authorities [[this document]] | CH, CR      |
| oid_filters [[this document]]            | CR          |

当存在不同类型的多个扩展时，扩展可以以任何顺序出现，除了“pre_shared_key”第4.2.8节，它必须是ClientHello中的最后一个扩展。**不能有多个同一类型的扩展。**
在TLS 1.3中，与TLS 1.2不同，即使在恢复PSK模式下，每次握手都重新协商扩展。然而，0-RTT参数是在先前握手中协商的参数;不匹配可能需要拒绝0-RTT（见第4.2.7节）。

在新协议中可能会出现的新特性与现有功能之间存在微妙（而不是微妙的）交互，这可能会导致整体安全性的显着降低。设计新扩展时，应考虑以下注意事项：
-- 服务器不同意扩展的一些情况是错误条件，有些则简单地拒绝支持特定功能。一般来说，前者应该使用错误警报，后者的服务器扩展响应中会显示一个字段。
-- 扩展应尽可能设计为防止任何强制使用（或不使用）特定功能的攻击通过操纵握手信息。无论该功能是否被认为引起安全问题，都应遵循这一原则。通常，扩展字段被包括在完成消息散列的输入中的事实将是足够的，但是当扩展改变在握手阶段中发送的消息的含义时，需要特别小心。设计师和实现者应该意识到，在握手已通过身份验证之前，主动攻击者可以修改消息并插入，删除或替换扩展。

### [4.2.1.](https://tlswg.github.io/tls13-spec/#rfc.section.4.2.1) [Supported Versions](https://tlswg.github.io/tls13-spec/#supported-versions)

```
   struct {
       ProtocolVersion versions<2..254>;
   } SupportedVersions;
```

客户端使用“supported_versions”扩展来指示它支持哪些版本的TLS

优先顺序

首先是最优先的版本

**0x0304**

- 如果不存在此扩展，那么符合本规范的服务器必须按照[RFC5246]中的规定协商TLS 1.2或先前版本，即使ClientHello.legacy_version为0x0304或更高版本。
- 如果存在此扩展，服务器必须忽略ClientHello.legacy_version值，并且必须仅使用“supported_versions”扩展来确定客户端首选项。服务器必须只选择该扩展中存在的TLS版本，并且必须忽略任何未知版本。注意，如果一方支持稀疏范围，这种机制使得可以在TLS 1.2之前协商版本。选择支持TLS的以前版本的TLS 1.3的实现应支持TLS 1.2。服务器应准备接收包含此扩展名的ClientHellos，但不要在版本列表中包含0x0304。

服务器不得发送“supported_versions”扩展名

服务器的所选版本包含在ServerHello.version字段中

#### 

### [4.2.2.](https://tlswg.github.io/tls13-spec/#rfc.section.4.2.2) [Cookie](https://tlswg.github.io/tls13-spec/#cookie)

```
   struct {
       opaque cookie<1..2^16-1>;
   } Cookie;
```

- 允许服务器强制客户端在其明显的网络地址展示可达性（从而提供DoS保护的度量）。 这主要用于非面向连接的传输（参见[RFC6347]）。
- 允许服务器向客户端卸载状态，从而允许它发送HelloRetryRequest而不存储任何状态。 服务器通过将序列化的哈希状态存储在cookie中（用一些合适的完整性算法保护）来实现。

当发送HelloRetryRequest时，服务器可以向客户端提供“cookie”扩展

当发送新的ClientHello时，客户端必须将HelloRetryRequest中收到的扩展的内容复制到新ClientHello中的“cookie”扩展中

客户端

不得在后续连接中使用Cookie。

### [4.2.3.](https://tlswg.github.io/tls13-spec/#rfc.section.4.2.3) [Signature Algorithms](https://tlswg.github.io/tls13-spec/#signature-algorithms)

客户端使用“signature_algorithms”扩展来向服务器指示

哪些签名算法可以在数字签名中使用

用“missing_extension”警报中止握手

ClientHello中此扩展的“extension_data”字段包含SignatureSchemeList值：

```
   enum {
       /* RSASSA-PKCS1-v1_5 algorithms */
       rsa_pkcs1_sha256(0x0401),
       rsa_pkcs1_sha384(0x0501),
       rsa_pkcs1_sha512(0x0601),

       /* ECDSA algorithms */
       ecdsa_secp256r1_sha256(0x0403),
       ecdsa_secp384r1_sha384(0x0503),
       ecdsa_secp521r1_sha512(0x0603),

       /* RSASSA-PSS algorithms */
       rsa_pss_sha256(0x0804),
       rsa_pss_sha384(0x0805),
       rsa_pss_sha512(0x0806),

       /* EdDSA algorithms */
       ed25519(0x0807),
       ed448(0x0808),

       /* Legacy algorithms */
       rsa_pkcs1_sha1(0x0201),
       ecdsa_sha1(0x0203),

       /* Reserved Code Points */
       private_use(0xFE00..0xFFFF),
       (0xFFFF)
   } SignatureScheme;

   struct {
       SignatureScheme supported_signature_algorithms<2..2^16-2>;
   } SignatureSchemeList;
```

降序

签名算法输入任意长度的消息，

而不是摘要

【RSASSA-PKCS1-v1_5算法】
表示使用RSASSA-PKCS1-v1_5 [RFC3447]与[SHS]中定义的相应散列算法的签名算法。这些值仅涉及出现在证书中的签名（参见第4.4.1.2节），并且未定义用于签署的TLS握手消息。
【ECDSA算法】
表示使用ECDSA [ECDSA]的签名算法，在ANSI X9.62 [X962]和FIPS 186-4 [DSS]中定义的相应曲线以及如[SHS]中定义的相应散列算法。签名被表示为DER编码的[X690] ECDSA-Sig-Value结构。
【RSASSA-PSS算法】
表示使用具有掩码生成功能1的RSASSA-PSS [RFC3447]的签名算法。在掩码生成函数中使用的摘要和被签名的摘要都是如在[SHS]中定义的相应的哈希算法。当在签署的TLS握手消息中使用时，盐的长度必须等于摘要输出的长度。此代码点也定义为与TLS 1.2一起使用。
【EdDSA算法】
表示使用[I-D.irtf-cfrg-eddsa]或其后继中定义的EdDSA的签名算法。注意，这些对应于“PureEdDSA”算法，而不是“prehash”变体。

【遗留算法】

表示由于使用具有已知缺点的算法，特别是在本上下文中与使用RSASSA-PKCS1-v1_5或ECDSA的RSA一起使用的SHA-1，这些算法已被弃用。 这些值仅指出现在证书中的签名（参见第4.4.2.2节），并且未定义用于签名的TLS握手消息。 端点不应该协商这些算法，但允许这样做仅仅是为了向后兼容。 提供这些值的客户端必须将它们列为最低优先级（在SignatureSchemeList中的所有其他算法之后列出）。 TLS 1.3服务器不得提供SHA-1签名证书，除非没有生成有效的证书链（见第4.4.2.2节）。

rsa_pkcs1_sha1，dsa_sha1和ecdsa_sha1不应该提供。 提供这些值以实现向后兼容性的客户端必须将它们列为最低优先级（在SignatureSchemeList中的所有其他算法之后列出）。TLS 1.3服务器不得提供SHA-1签名的证书，除非没有有效的证书链（见第4.4.1.2节）。
自签名证书或作为信任锚的证书上的签名不会生效，因为它们开始了认证路径（参见[RFC5280]，第3.2节）。 开始认证路径的证书可以使用未在“signature_algorithms”扩展中通告为支持的签名算法。
注意，TLS 1.2定义了不同的扩展。 TLS 1.3实现愿意协商TLS 1.2在协商该版本时，必须按照[RFC5246]的要求进行操作。 尤其是：

- TLS 1.2 ClientHellos可以忽略此扩展。
- 在TLS 1.2中，扩展包含hash/signature pairs。 这些对被编码为两个八位字节，因此已分配SignatureScheme值以与TLS 1.2的编码对齐。 一些传统对保留未分配。 这些算法自TLS 1.3起已弃用。 它们不得由任何实施提供或协商。 特别是，不得使用MD5 [SLOTH]和SHA-224。
- ECDSA签名方案与TLS 1.2的ECDSA哈希/签名对相一致。 然而，旧的语义没有约束签名曲线。 如果协商TLS 1.2，则实现必须准备接受使用它们在“supported_groups”扩展中通告的任何曲线的签名。
- 支持RSASSA-PSS（在TLS 1.3中是强制性的）的实现必须准备接受使用该方案的签名，即使协商TLS 1.2。 在TLS 1.2中，RSASSA-PSS与RSA密码套件一起使用。

#### [4.2.4.](https://tlswg.github.io/tls13-spec/#rfc.section.4.2.3.1) [Certificate Authorities](https://tlswg.github.io/tls13-spec/#certificate-authorities)

指示端点支持的证书授权，并且接收端点应该使用它来指导证书选择

```
   opaque DistinguishedName<1..2^16-1>;

   struct {
       DistinguishedName authorities<3..2^16-1>;
   } CertificateAuthoritiesExtension;
```

可接受证书颁发机构的可分辨名称[X501]的列表

DER编码

客户端可以在ClientHello消息中发送“certificate_authorities”扩展

服务器可以在CertificateRequest消息中发送它

在TLS 1.3中不使用“trusted_ca_keys”扩展名（RFC6066），但它可能出现在先前TLS版本的客户端的ClientHello消息中。

### [4.2.5.](https://tlswg.github.io/tls13-spec/#rfc.section.4.2.4) [Post-Handshake Client Authentication](https://tlswg.github.io/tls13-spec/#negotiated-groups)

### [4.2.6.](https://tlswg.github.io/tls13-spec/#rfc.section.4.2.4) [Negotiated Groups](https://tlswg.github.io/tls13-spec/#negotiated-groups)

“supported_groups”扩展指示客户端支持的用于密钥交换的命名组

在TLS 1.3之前的TLS版本中，此扩展名称为“elliptic_curves”，并且只包含椭圆曲线组

**签名算法现在独立协商**

```
   enum {
       /* Elliptic Curve Groups (ECDHE) */
       secp256r1(0x0017), secp384r1(0x0018), secp521r1(0x0019),
       x25519(0x001D), x448(0x001E),

       /* Finite Field Groups (DHE) */
       ffdhe2048(0x0100), ffdhe3072(0x0101), ffdhe4096 (0x0102),
       ffdhe6144(0x0103), ffdhe8192(0x0104),

       /* Reserved Code Points */
       ffdhe_private_use(0x01FC..0x01FF),
       ecdhe_private_use(0xFE00..0xFEFF),
       (0xFFFF)
   } NamedGroup;

   struct {
       NamedGroup named_group_list<2..2^16-1>;
   } NamedGroupList;
```

- Elliptic Curve Groups（ECDHE） 表示支持对应的命名曲线，在FIPS 186-4 [DSS]或[RFC7748]中定义。值0xFE00到0xFEFF保留供私人使用。
- Finite Field Groups（DHE） 表示支持相应的有限域组，在[RFC7919]中定义。值0x01FC至0x01FF保留供私人使用。

named_group_list中的项根据客户端的首选项排序

从TLS 1.3开始，服务器被允许向客户端发送“supported_groups”扩展。如果服务器有一个组，它喜欢“key_share”扩展中的那些，但仍然愿意接受ClientHello，它应该发送“supported_groups”来更新客户端的偏好视图;此扩展应包含服务器支持的所有组，无论它们当前是否由客户端支持。客户端不能在成功完成握手之对“supported_groups”中找到的任何信息采取行动，但可以使用从成功完成的握手中获得的信息来更改在后续连接中的“key_share”扩展中使用的组。

### [4.2.7.](https://tlswg.github.io/tls13-spec/#rfc.section.4.2.5) [Key Share](https://tlswg.github.io/tls13-spec/#key-share)

端点的加密参数

客户端可以发送

空的

client_shares向量，以便以额外的往返为代价从服务器请求组选择

```
   struct {
       NamedGroup group;
       opaque key_exchange<1..2^16-1>;
   } KeyShareEntry;
```

key_exchange

```
   struct {
       select (Handshake.msg_type) {
           case client_hello:
               KeyShareEntry client_shares<0..2^16-1>;

           case hello_retry_request:
               NamedGroup selected_group;

           case server_hello:
               KeyShareEntry server_share;
       };
   } KeyShare;
```

client_shares

降序

每个KeyShareEntry值必须对应于在“supported_groups”扩展中提供的组，并且必须以相同的顺序出现。

 

selected_group

server_share

客户端提供任意数量的KeyShareEntry值，每个值表示一组**密钥交换参数**。例如，客户端可能为几个椭圆曲线或多个FFDHE组提供共享。每个KeyShareEntry的key_exchange值必须独立生成。客户不得为同一组提供多个KeyShareEntry值。客户端不得为客户端的“supported_groups”扩展中未列出的组提供任何KeyShareEntry值。服务器可能会检查违反了这些规则的行为，并且如果违反了则使用“illegal_parameter”警报来中止握手。

在HelloRetryRequest中接收到此扩展时，客户端必须验证

（1）selected_group字段**对应于**在原始ClientHello中的“supported_groups”扩展中提供的组;

（2）selected_group字段与原始ClientHello中的“key_share”扩展中提供的组**不对应**。

如果这些检查中的任一个失败，则客户端必须用“illegal_parameter”警报来中止握手。否则，当发送新的ClientHello时，客户端必须用在触发HelloRetryRequest的selected_group字段中指示的组替换原来的“key_share”扩展，其中只包含新的KeyShareEntry。

如果使用（EC）DHE密钥建立，服务器在ServerHello中只提供一个KeyShareEntry。 该值必须与服务器为协商密钥交换选择的客户端提供的KeyShareEntry值在同一组。

服务器不得为“supported_groups”扩展中指定的任何组发送KeyShareEntry，并且在使用“psk_ke”PskKeyExchangeMode时不得发送KeyShareEntry。

如果客户端收到HelloRetryRequest，客户端必须验证ServerHello中选择的NamedGroup与HelloRetryRequest中的相同，否则必须以“illegal_parameter”警报中止握手。

#### [4.2.7.1.](https://tlswg.github.io/tls13-spec/#rfc.section.4.2.5.1) [Diffie-Hellman Parameters](https://tlswg.github.io/tls13-spec/#ffdhe-param)

客户端和服务器的Diffie-Hellman [DH]参数都编码在KeyShareEntry中的KeyShare结构中的opaque key_exchange字段中。

 

注意：对于给定的Diffie-Hellman组，填充导致所有公钥具有相同的长度。
对端应该通过确保1 <Y <p-1来验证对方的公钥Y. 此检查确保远程对端正常运行，并且不强制本地系统进入小型组。

#### [4.2.7.2.](https://tlswg.github.io/tls13-spec/#rfc.section.4.2.5.2) [ECDHE Parameters](https://tlswg.github.io/tls13-spec/#ecdhe-param)

客户端和服务器的ECDHE参数都编码在KeyShare结构中的KeyShareEntry的opaque key_exchange字段中。

对于secp256r1，secp384r1和secp521r1，内容是以下结构体的序列化值：

```
   struct {
       uint8      legacy_form = 4;
       opaque     X[coordinate_length];
       opaque     Y[coordinate_length];
   } KeyShare;
```

X和Y分别是网络字节顺序中X和Y值的二进制表示。 没有内部长度标记，因此每个数字表示占用曲线参数隐含的八位字节数。 对于P-256，这意味着X和Y中的每一个使用32个八位字节，如果需要，则在左侧填充零。 对于P-384，它们分别占用48个八位字节，对于P-521，它们各占用66个八位字节。

对于曲线secp256r1，secp384r1和secp521r1，对端必须通过确保该点是椭圆曲线上的有效点来验证彼此的公共值Y. 相应的验证程序在[X962]的4.3.7节中定义，或者在[KEYAGREEMENT]的5.6.2.6节中定义。 该过程由三个步骤组成：

（1）验证Y不是无穷大点（O），

（2）验证Y =（x，y）两个整数都在正确的间隔，

（3）确保（ x，y）是椭圆曲线方程的正确解。 对于这些曲线，实现者不需要验证正确子组中的成员资格。

对于X25519和X448，公共值的内容是[RFC7748]中定义的相应功能的字节串输入和输出，X25519的32个字节和X448的56个字节。

注意：1.3之前版本的TLS允许 point format 协商; TLS 1.3删除此功能，有利于每个曲线的单点格式。

### [4.2.8.](https://tlswg.github.io/tls13-spec/#rfc.section.4.2.6) [Pre-Shared Key Exchange Modes](https://tlswg.github.io/tls13-spec/#pre-shared-key-exchange-modes)

为了使用PSK，客户端还必须发送一个“psk_key_exchange_modes”扩展。 

如果客户端提供了一个“pre_shared_key”扩展，客户端必须提供一个“psk_key_exchange_modes”扩展。如果客户端提供不带“psk_key_exchange_modes”扩展名的“pre_shared_key”，服务器必须中止握手。服务器不得选择客户端未列出的密钥交换模式。 此扩展还限制与PSK恢复使用的模式; 服务器不应发送与所通告的模式不兼容的NewSessionTicket; 但是如果服务器这样做，则影响将只是客户端在恢复时的尝试失败。

服务器不得发送“psk_key_exchange_modes”扩展名。

```
   enum { psk_ke(0), psk_dhe_ke(1), (255) } PskKeyExchangeMode;

   struct {
       PskKeyExchangeMode ke_modes<1..255>;
   } PskKeyExchangeModes;
```

psk_ke

**仅PSK密钥建立**

 

在这种模式下，服务器不能提供“key_share”值。

sk_dhe_ke

**PSK与（EC）DHE密钥建立**

 

在这种模式下，客户端和服务器必须提供“key_share”值

### [4.2.9.](https://tlswg.github.io/tls13-spec/#rfc.section.4.2.7) [Early Data Indication](https://tlswg.github.io/tls13-spec/#early-data-indication)

**当使用PSK时，客户端可以在其第一个消息中发送应用数据**

 

**如果客户端选择这样做，它必须提供一个“early_data”扩展以及“pre_shared_key”扩展。**

```
   struct {} Empty;

   struct {
       select (Handshake.msg_type) {
           case new_session_ticket:     uint32 max_early_data_size;
           case client_hello:           Empty;
           case encrypted_extensions:   Empty;
       };
   } EarlyDataIndication;
```

有关使用max_early_data_size字段，请参见第4.6.1节。
0-RTT数据（对称密码套件，ALPN协议等）的参数与建立PSK的连接中协商的参数相同。用于加密早期数据的PSK必须是客户端“pre_shared_key”扩展中列出的第一个PSK。
对于通过NewSessionTicket提供的PSK，服务器必须验证所选PSK身份的 ticket 年龄（从PskIdentity.obfuscated_ticket_age 模 2 ^ 32中减去ticket_age_add计算）在从ticket开始以来的时间范围内（见第4.2节.10.4）。如果不是，服务器应该进行握手，但拒绝0-RTT，并且不应该采取任何其他操作,假定该ClientHello是全新的。
在第一次flight中发送的0-RTT消息与其他flight（握手和应用程序数据）中发送的相应消息具有相同（加密）的内容类型，但受到不同密钥的保护。在收到服务器的完成消息后，如果服务器已接收到早期数据，则会发送EndOfEarlyData消息以指示密钥更改。该消息将使用0-RTT流量密钥进行加密。

- 忽略扩展并返回常规的1-RTT响应。然后，服务器通过尝试解密握手业务密钥中的接收记录来忽略早期数据，直到能够接收客户端的第二次飞行并完成普通的1-RTT握手，跳过无法解密的记录，直到配置的max_early_data_size。
- 请求客户端通过响应HelloRetryRequest发送另一个ClientHello。 客户端不得在其后续ClientHello中包含“early_data”扩展。 然后，服务器通过跳过具有外部内容类型“application_data”的所有记录（指示它们被加密）来忽略早期数据。
- 在EncryptedExtensions中返回自己的扩展名，表示它打算处理早期的数据。 服务器不可能只接受早期数据消息的一部分。 即使服务器发送接收早期数据的消息，但是实际的早期数据本身可能已经在服务器生成此消息时正在运行。

已经接受了PSK密码套件并且选择了客户端的“pre_shared_key”扩展中提供的第一个密钥

- TLS版本号和加密套件。
- 所选的ALPN协议 [RFC7301]（如果有）。

如果任何这些检查失败，服务器不得使用扩展名进行响应，并且必须使用上面列出的前两种机制之一丢弃所有第一个飞行数据（从而回落到1-RTT或2-RTT）。 如果客户端尝试进行0-RTT握手，但是服务器拒绝服务器，则服务器通常不具有0-RTT记录保护密钥，而必须使用试用解密（使用1-RTT握手密钥或通过查找明文ClientHello 在HelloRetryRequest的情况下）找到第一个非0RTT消息。

如果服务器选择接受“early_data”扩展，那么在处理早期数据记录时，它必须遵守与所有记录相同的错误处理要求。 具体来说，如果服务器在接受的“early_data”扩展后无法解密任何0-RTT记录，则它必须根据第5.2节使用“bad_record_mac”警报终止连接。

如果服务器拒绝“early_data”扩展，则客户端应用程序可以在握手完成后选择重新发送早期数据。 请注意，早期数据的自动重新传输可能导致关于连接状态不正确的假设。 例如，当协商的连接从早期数据中使用的协议选择不同的ALPN协议时，应用程序可能需要构建不同的消息。 类似地，如果早期数据假定有关连接状态的任何内容，则握手完成后可能发送错误。

如果服务器拒绝“early_data”扩展，则一旦握手已完成，客户端应用可以选择重传早期数据。 TLS实现不应自动重新发送早期数据; 应用程序能够更好地决定重新传输是否合适。 除非协商的连接选择相同的ALPN协议，否则TLS实现不得自动重新发送早期数据。如果选择了不同的协议，应用程序可能需要构造不同的消息。类似地，如果早期数据假定关于连接状态的任何事情，则它可能在握手完成之后错误地发送。

### [4.2.10.](https://tlswg.github.io/tls13-spec/#rfc.section.4.2.8) [Pre-Shared Key Extension](https://tlswg.github.io/tls13-spec/#pre-shared-key-extension)

指示与PSK密钥建立相关联的给定握手使用的预共享密钥的身份

```
   struct {
       opaque identity<1..2^16-1>;
       uint32 obfuscated_ticket_age;
   } PskIdentity;

   opaque PskBinderEntry<32..255>;

   struct {
       select (Handshake.msg_type) {
           case client_hello:
               PskIdentity identities<7..2^16-1>;
               PskBinderEntry binders<33..2^16-1>;

           case server_hello:
               uint16 selected_identity;
       };

   } PreSharedKeyExtension;
```

obfuscated_ticket_age

selected_identity

每个PSK与单个哈希算法相关联。对于通过ticket机制建立的PSK（第4.6.1节），这是用于KDF的哈希。对于外部建立的PSK，当PSK建立时，必须设置哈希算法。服务器必须确保它选择兼容的PSK（如果有的话）和密码套件。
实现者的注意：实现PSK /密码套件匹配要求的最直接的方法是先协商密码套件，然后排除任何不兼容的PSK。
在接受PSK密钥建立之前，服务器务必验证相应的binder值（见下面的4.2.8.1节）。如果此值不存在或未验证，则服务器必须中止握手。服务器不应该尝试验证多个binder;而是他们应该选择单个PSK并且仅验证对应于该PSK的绑定器。为了接受PSK密钥建立，服务器发送指示所选择的标识的“pre_shared_key”扩展。
客户端必须验证服务器的selected_identity是否在客户端提供的范围内，服务器选择了包含与PSK关联的哈希的加密套件，并且如果ClientHello“psk_key_exchange_modes”需要，还存在服务器“key_share”扩展。如果这些值不一致，客户端必须使用“illegal_parameter”警报中止握手。
如果服务器提供了“early_data”扩展，客户端必须验证服务器的selected_identity是否为0.如果返回任何其他值，客户端必须使用“illegal_parameter”警报中止握手。
**该扩展必须是ClientHello中的最后一个扩展**（这有助于如下所述的实现）。**服务器必须检查它是最后一个扩展，否则失败握手与“illegal_parameter”警报。**

#### [4.2.8.1.](https://tlswg.github.io/tls13-spec/#rfc.section.4.2.8.1) [PSK Binder](https://tlswg.github.io/tls13-spec/#psk-binder)

PSK和当前握手之间

建立PSK的会话（如果通过NewSessionTicket消息）和使用它的会话之间

绑定者列表中的每个条目被计算为直到并包括PreSharedKeyExtension.identities字段的ClientHello的部分（包括握手报头）上的HMAC。

```
   ClientHello1[truncated]
```

```
   ClientHello1 + HelloRetryRequest + ClientHello2[truncated]
```

#### [4.2.8.2.](https://tlswg.github.io/tls13-spec/#rfc.section.4.2.8.2) [Processing Order](https://tlswg.github.io/tls13-spec/#processing-order)

客户端被允许“流”0-RTT数据，直到它们接收服务器的 Finished，然后发送EndOfEarlyData消息

为了避免死锁，当接受“early_data”时，服务器必须处理客户端的ClientHello，然后立即发送ServerHello，而不是等待客户端的EndOfEarlyData消息。

#### [4.2.8.3.](https://tlswg.github.io/tls13-spec/#rfc.section.4.2.8.3) [Replay Properties](https://tlswg.github.io/tls13-spec/#replay-time)

**重放保护**

服务器应该使用客户端“pre_shared_key”扩展中的“obfuscated_ticket_age”参数来限制第一个flight可能被重放的时间。

ticket

由客户端提供的ticket期限（减去“ticket_age_add”的值）将比服务器上经过一个往返时间的实际时间短。这个差异包括向客户端发送NewSessionTicket消息的延迟，以及将ClientHello发送到服务器所花费的时间。因此，服务器应该在发送NewSessionTicket消息之前测量往返时间，并在它保存的值中记录它。

ticket

- 服务器生成会话ticket的时间和估计的往返时间可以一起添加以形成基线时间。
- 需要NewSessionTicket的“ticket_age_add”参数来从“obfuscated_ticket_age”参数恢复ticket期限。

有几个潜在的误差源使得精确的时间测量困难。客户端和服务器时钟速率的变化很可能是最小的，尽管可能具有总时间校正。网络传播延迟很可能是由于经过时间的合法值不匹配引起的。 NewSessionTicket和ClientHello消息都可能被重新传输并因此被延迟，这可能被TCP隐藏。
建议在时钟误差和测量误差方面留有小量余量。However, any allowance also increases the opportunity for replay. 在这种情况下，最好是拒绝早期数据并回退到完全的1-RTT握手，而不是承担更大的重放攻击的风险。

### 4.3. 服务器参数

EncryptedExtensions

CertificateRequest

### [4.3.1.](https://tlswg.github.io/tls13-spec/#rfc.section.4.3.1) [Encrypted Extensions](https://tlswg.github.io/tls13-spec/#encrypted-extensions)

在所有握手中，服务器必须在ServerHello消息之后立即发送EncryptedExtensions消息

这是在从server_handshake_traffic_secret派生的密钥下加密的第一条消息。

EncryptedExtensions消息包含应该被保护的扩展

客户端必须检查EncryptedExtensions是否存在任何禁止的扩展

用“illegal_parameter”警报中止握手

```
   struct {
       Extension extensions<0..2^16-1>;
   } EncryptedExtensions;
```

### [4.3.2.](https://tlswg.github.io/tls13-spec/#rfc.section.4.3.2) [Certificate Request](https://tlswg.github.io/tls13-spec/#certificate-request)

使用证书进行身份验证的服务器可以选择向客户端请求证书

```
   struct {
       opaque certificate_request_context<0..2^8-1>;
       Extension extensions<2..2^16-1>;
   } CertificateRequest;
```

【certificate_request_context】
一个不透明的字符串，用于标识证书请求，并在客户端的证书消息中回显。 certificate_request_context在此连接的范围内必须是唯一的（从而防止客户端CertificateVerify消息的重放）。该字段应为零长度，除非用于第4.6.2节中描述的握手后身份验证交换。
【extensions】
描述正在请求的证书的参数的可选扩展集。必须指定“signature_algorithms”扩展名。
在TLS的先前版本中，服务器将接受携带签名算法和证书授权的列表的CertificateRequest消息。在TLS 1.3中，前者通过发送“signature_algorithms”扩展来表示。后者通过发送“certificate_authorities”扩展名来表示（见第4.2.3.1节）。
使用PSK进行认证的服务器不得发送CertificateRequest消息。

#### [4.3.2.1.](https://tlswg.github.io/tls13-spec/#rfc.section.4.3.2.1) [OID Filters](https://tlswg.github.io/tls13-spec/#oid-filters)

允许服务器提供一组OID /值对

它希望客户端的证书匹配

 此扩展必须只在CertificateRequest消息中发送

```
  struct {
      opaque certificate_extension_oid<1..2^8-1>;
      opaque certificate_extension_values<0..2^16-1>;
  } OIDFilter;

  struct {
      OIDFilter filters<0..2^16-1>;
  } OIDFilterExtension;
```

具有允许值的证书扩展OID [RFC5280]的列表

DER编码

一些证书扩展OID允许多个值

如果服务器包含非空的certificate_extensions列表，则响应中包含的客户端证书必须包含客户端识别的所有指定的扩展OID。对于客户端识别的每个扩展OID，所有指定的值必须存在于客户端证书中（但是证书也可以具有其他值）。但是，客户端必须忽略并跳过任何无法识别的证书扩展OID。如果客户端忽略了一些所需的证书扩展OID并提供了不满足请求的证书，则服务器可以自行决定是否继续会话而不进行客户端身份验证，或者使用“unsupported_certificate”警报中止握手。 

PKIX RFC定义了各种证书扩展OID及其对应的值类型。根据类型，匹配的证书扩展值不一定是按位相等的。期望TLS实现将依靠它们的PKI库来使用证书扩展OID来执行证书选择。

本文档定义了[RFC5280]中定义的两个标准证书扩展的匹配规则：

- The Key Usage extension in a certificate matches the request when all key usage bits asserted in the request are also asserted in the Key Usage certificate extension.
- The Extended Key Usage extension in a certificate matches the request when all key purpose OIDs present in the request are also found in the Extended Key Usage certificate extension. The special anyExtendedKeyUsage OID MUST NOT be used in the request.

## [4.4.](https://tlswg.github.io/tls13-spec/#rfc.section.4.4) [Authentication Messages](https://tlswg.github.io/tls13-spec/#authentication-messages)

如第2节所述，TLS通常使用一组公共消息来进行身份验证，密钥确认和握手完整性：Certificate，CertificateVerify和Finished。 （PreSharedKey绑定器也以类似的方式执行密钥确认。）这三个消息总是作为它们的握手飞行中的最后消息发送。 Certificate和CertificateVerify消息仅在某些情况下发送，如下所定义。Finished

的消息总是作为认证块的一部分发送。这些消息在从[sender]_handshake_traffic_secret派生的密钥下加密。

认证消息的计算统一采用以下输入：

- 要使用的证书和签名密钥。
- 握手基于握手消息的记录的上下文
- 用于计算MAC密钥的基本密钥。

Certificate

用于认证的证书和链中的任何支持证书

CertificateVerify

值Hash（握手上下文+证书）上的签名

Finished

使用从基本密钥导出的MAC密钥的值超过值Hash（握手上下文+证书+证书验证）的MAC

| Mode           | Handshake Context                        | Base Key                        |
| -------------- | ---------------------------------------- | ------------------------------- |
| Server         | ClientHello … later of EncryptedExtensions/CertificateRequest | server_handshake_traffic_secret |
| Client         | ClientHello … ServerFinished             | client_handshake_traffic_secret |
| Post-Handshake | ClientHello … ClientFinished + CertificateRequest | client_traffic_secret_N         |

在所有情况下，通过连接指示的握手消息（包括握手消息类型和长度字段，但不包括记录层头部）来形成握手上下文。

### [4.4.1.](https://tlswg.github.io/tls13-spec/#rfc.section.4.4.1) [Certificate](https://tlswg.github.io/tls13-spec/#certificate)

服务器必须发送证书消息

当且仅当服务器通过CertificateRequest消息请求客户端认证时，客户端必须发送证书消息

如果服务器请求客户端认证但没有合适的证书可用，则客户端必须发送不包含证书的证书消息（即，具有长度为0的“certificate_list”字段）

```
   opaque ASN1Cert<1..2^24-1>;

   struct {
       ASN1Cert cert_data;
       Extension extensions<0..2^16-1>;
   } CertificateEntry;

   struct {
       opaque certificate_request_context<0..2^8-1>;
       CertificateEntry certificate_list<0..2^24-1>;
   } Certificate;
```

certificate_request_context

certificate_list

每个结构包含单个证书和一组扩展

**发送者的证书必须在列表中的第一个CertificateEntry中**

**后面的每个证书应该直接证明前一个证书**

注意：在TLS 1.3之前，“certificate_list”排序需要每个证书来证明紧接在其前面的证书，然而，一些实现允许一些灵活性。服务器有时为了过渡目的而发送当前和已弃用的中间体，而其他的配置不正确，但这些情况仍然可以正确地验证。为了最大程度的兼容性，所有实现应该准备处理潜在的外部证书和任何TLS版本的任意排序，除了必须首先是最终实体证书。
服务器的certificate_list必须总是非空的。如果客户端没有相应的证书来响应服务器的身份验证请求，则客户端将发送一个空的certificate_list。

#### [4.4.1.1.](https://tlswg.github.io/tls13-spec/#rfc.section.4.4.1.1) [OCSP Status and SCT Extensions](https://tlswg.github.io/tls13-spec/#ocsp-status-and-sct-extensions)

[RFC6066]和[RFC6961]提供了协商服务器向客户端发送OCSP响应的扩展。 在TLS 1.2及以下版本中，服务器用空扩展名回复以指示此扩展的协商，并且OCSP信息在CertificateStatus消息中携带。 在TLS 1.3中，服务器的OCSP信息携带在包含相关证书的CertificateEntry中的扩展中。 具体来说：来自服务器的“status_request”或“status_request_v2”扩展的主体必须是分别在[RFC6066]和[RFC6961]中定义的CertificateStatus结构。
类似地，[RFC6962]提供用于服务器发送签名证书时间戳（SCT）作为ServerHello中的扩展的机制。 在TLS 1.3中，服务器的SCT信息在CertificateEntry中的扩展中承载。

#### [4.4.1.2.](https://tlswg.github.io/tls13-spec/#rfc.section.4.4.1.2) [Server Certificate Selection](https://tlswg.github.io/tls13-spec/#server-certificate-selection)

以下规则适用于服务器发送的证书：

- 证书类型必须是X.509v3 [RFC5280]，除非另有明确协商（例如，[RFC5081]）。
- 服务器的终端实体证书的公钥（和相关限制）必须与所选的认证算法（当前为RSA或ECDSA）兼容。
- 证书必须允许密钥用于在客户端的“signature_algorithms”扩展中指示的签名方案的签名（即，如果密钥使用扩展存在则必须设置digitalSignature位必须被设置）。
- “server_name”和“trusted_ca_keys”扩展名[RFC6066]用于指导证书选择。由于服务器可能需要存在“server_name”扩展，因此客户端应在适用时发送此扩展。

#### [4.4.1.3.](https://tlswg.github.io/tls13-spec/#rfc.section.4.4.1.3) [Client Certificate Selection](https://tlswg.github.io/tls13-spec/#client-certificate-selection)

以下规则适用于客户端发送的证书：

- 证书类型必须是X.509v3 [RFC5280]，除非另有明确协商（例如，[RFC5081]）。
- 如果证书请求消息中的certificate_authorities列表不为空，则证书链中的至少一个证书应该由所列出的CA之一发布。
- 证书必须使用可接受的签名算法签名，如第4.3.2节所述。 注意，这放松了在TLS的先前版本中发现的证书签名算法的约束。
- 如果证书请求消息中的certificate_extensions列表不为空，那么终端实体证书必须匹配客户端识别的扩展OID，如第4.3.2节所述。

#### [4.4.1.4.](https://tlswg.github.io/tls13-spec/#rfc.section.4.4.1.4) [Receiving a Certificate Message](https://tlswg.github.io/tls13-spec/#receiving-a-certificate-message)

一般来说，详细的证书验证过程超出了TLS的范围（参见[RFC5280]）。本节提供TLS特定的要求。
如果服务器提供空的证书消息，客户端必须用“decode_error”警报中止握手。
如果客户端不发送任何证书，则服务器可以自行决定是否在没有客户端认证的情况下继续握手，或者使用“certificate_required”警报来中止握手。此外，如果证书链的某些方面是不可接受的（例如，它不是由已知的可信CA签署的），则服务器可以自行决定是继续握手（考虑到客户端未认证）还是中止握手。
任何接收使用任何使用MD5哈希的签名算法签名的证书的端点必须中止具有“bad_certificate”警报的握手。SHA-1已弃用，建议任何使用任何签名算法使用SHA-1散列签名的证书终止具有“bad_certificate”警报的握手。建议所有端点尽快转换到SHA-256或更高版本，以保持与逐步淘汰SHA-1支持过程中当前的实现的互操作性。
注意，包含用于一个签名算法的密钥的证书可以使用不同的签名算法（例如，用ECDSA密钥签名的RSA密钥）来签名。

### [4.4.2.](https://tlswg.github.io/tls13-spec/#rfc.section.4.4.2) [Certificate Verify](https://tlswg.github.io/tls13-spec/#certificate-verify)

该消息用于提供端点拥有与其证书相对应的私钥的明确证明，并且还为到目前为止的握手提供完整性。服务器必须在通过证书进行身份验证时发送此消息。 客户端必须在通过证书进行身份验证时（即，当证书消息非空时）发送此消息。发送时，此消息必须紧接在证书消息之后并紧接在完成消息之前。
此消息的结构：

```
   struct {
       SignatureScheme algorithm;
       opaque signature<0..2^16-1>;
   } CertificateVerify;
```

```
   Hash(Handshake Context + Certificate)
```

- 签名密钥
- 上下文字符串
- 要签署的实际内容


- 由八位字节32（0x20）组成的字符串重复64次
- 上下文字符串
- 用作分隔符的单个0字节
- 要签名的内容

```
   2020202020202020202020202020202020202020202020202020202020202020
   2020202020202020202020202020202020202020202020202020202020202020
   544c5320312e332c207365727665722043657274696669636174655665726966
   79
   00
   0101010101010101010101010101010101010101010101010101010101010101
```

签名算法必须与发送方的端实体证书中的密钥兼容

### [4.4.3.](https://tlswg.github.io/tls13-spec/#rfc.section.4.4.3) [Finished](https://tlswg.github.io/tls13-spec/#finished)

提供握手和所计算的密钥的认证

Finished消息

Finished消息

利用

HKDF

```
finished_key =
    HKDF-Expand-Label(BaseKey, "finished", "", Hash.length)
```

```
   struct {
       opaque verify_data[Hash.length];
   } Finished;
```

```
   verify_data =
       HMAC(finished_key, Hash(Handshake Context +
                               Certificate* +
                               CertificateVerify*))

   * Only included if present.
```

## [4.5.](https://tlswg.github.io/tls13-spec/#rfc.section.4.5) [End of Early Data](https://tlswg.github.io/tls13-spec/#end-of-early-data)

```
   struct {} EndOfEarlyData;
```

## [4.6.](https://tlswg.github.io/tls13-spec/#rfc.section.4.6) [Post-Handshake Messages](https://tlswg.github.io/tls13-spec/#post-handshake-messages)

### 

### [4.6.1.](https://tlswg.github.io/tls13-spec/#rfc.section.4.6.1) [New Session Ticket Message](https://tlswg.github.io/tls13-spec/#NewSessionTicket)

在服务器收到客户端完成的消息后的任何时间，就可以发送消息NewSessionTicket。此消息在ticket值和恢复主密钥之间创建一个预共享密钥（PSK）的绑定。

### 客户端可以在未来的握手中使用PSK，通过在ClientHello中包含“pre_shared_key”扩展，在扩展中包含ticket值（参加4.2.8节）。服务器可以在一个连接上发送多个tickets，无论是立即还是在特定事件后。例如，服务器可能为了添加客户端验证状态，在post-handshake验证后发送一个新的ticket。客户端应该尝试使用每个ticket最多一次，并且使用最近收到的ticket。

### 任何ticket恢复必须仅使用具有相同的KDF哈希的密码套件，建立初始连接，并且只有在客户端提供相同的SNI值在原来的连接，如第3节中描述[RFC6066] 。

### 注：虽然恢复主密钥取决于客户端的第二次飞行，但是不要求客户端认证的服务器可能独立地计算谈话的剩余部分，然后在发送它的Finished消息时，立即发送一个NewSessionTicket，而不是等待客户端的Finished消息。在客户端打开多个TLS连接时，这将减少握手恢复的开销。

```
   struct {
       uint32 ticket_lifetime;
       uint32 ticket_age_add;
       opaque ticket<1..2^16-1>;
       Extension extensions<0..2^16-2>;
   } NewSessionTicket;
```

ticket_lifetime

ticket_age_add

包括在“pre_shared_key”

目前为NewSessionTicket定义的唯一的扩展是“early_data”，表示ticket可以被用来发送0-RTT数据（第4.2.7节）。它包含以下值：
【max_early_data_size】
当使用这种ticket，以字节为单位，客户端被允许发送，0-RTT数据的最大量。服务器接收数据超过max_early_data_size0-RTT字节应该终止连接使用“unexpected_message”警报。

### [4.6.2.](https://tlswg.github.io/tls13-spec/#rfc.section.4.6.2) [Post-Handshake Authentication](https://tlswg.github.io/tls13-spec/#post-handshake-authentication)

CertificateRequest消息，在握手已经完成后，

Certificate

Certificate消息以及Finished

注：由于客户端身份验证可能需要提示用户，服务器必须为一些延迟做好准备，待接收包括发送和接收响应之间CertificateRequest其他消息任意数量。此外，哪些客户端收到紧密相继可能响应它们以不同的顺序比他们收到了多个CertificateRequests（价值certificate_request_context允许服务器歧义的响应）。

### 4. 握手协议

```
   enum {
       update_not_requested(0), update_requested(1), (255)
   } KeyUpdateRequest;

   struct {
       KeyUpdateRequest request_update;
   } KeyUpdate;
```

request_update

是否

keyupdate握手消息被用来表示发件人更新它发送的加密密钥。此消息可以在发送Finished消息后发送。在系统实现KeyUpdate接收成品必须终止连接随着“unexpected_message”警告消息之前收到的消息。发送KeyUpdate消息后，发送方使用下一代键，如第7.2节所述计算发送其所有流量。在接收到KeyUpdate，接收机必须更新其接收密钥。
如果request_update字段设置为“update_requested”，然后接收方必须发送自己的KeyUpdate随着request_update设置为“update_not_requested”发送其下一个应用程序的数据记录之前。这种机制一左一右强制允许更新整个连接，但是会导致接收多个KeyUpdates而这是无声的一次更新，以应对实现。还要注意的是实现接收发送给KeyUpdate随着request_update设置为update_requested和接收端的KeyUpdate，因为这些消息可能已在飞行之间的消息任意数量。然而，由于发送和接收密钥是从独立的通信秘密来源，保留这个秘密没有收到威胁的流量发送键之前发送的数据的前向安全性的变化。
如果实现独立发送KeyUpdates，用request_update设为“update_requested”，它们交叉和在飞行中，那么每个方将另外由两代发送响应，其结果是每一边的增量。

发送者和接收者必须用旧密钥加密他们的KeyUpdate消息。此外，这两端都必须强制，在接受任何一个用新密钥加密的消息之前，用旧密钥加密的KeyUpdate消息被接收。不这样做，可能遭到消息截断攻击。