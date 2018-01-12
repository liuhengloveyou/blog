---
title: TLS1.3协议
comments: true
date: 2017-12-07 17:15:19
time: 1512638119
tags:
	- tls
	- https
categories: web
---


**The Transport Layer Security (TLS) Protocol Version 1.3**

原文：[draft-ietf-tls-tls13](https://tlswg.github.io/tls13-spec/draft-ietf-tls-tls13.html)



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



## 4. 握手协议([Handshake Protocol](https://tlswg.github.io/tls13-spec/draft-ietf-tls-tls13.html#handshake-protocol))

握手协议用于协商一个连接的安全参数。握手消息被提供给TLS记录层，它们被封装在一个或多个TLSPlaintext或TLSCiphertext结构中，这些结构由指定的当前活动连接状态处理和传输。

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

协议信息**必须**按照`第4.4.1节`中定义的并在`第2节`的图中显示的顺序发送。 以意外顺序接收握手消息的对端必须使用“unexpected_message”警报中止握手。

新的握手消息类型由IANA指派，如`第11节`所述。

### 4.1. 密钥交换消息( [Key Exchange Messages](https://tlswg.github.io/tls13-spec/draft-ietf-tls-tls13.html#key-exchange-messages))

密钥交换消息用于确定客户端和服务器之间的安全能力边界，并建立用于保护握手和数据的通信密钥。

### 4.1.1. 密码谈判([Cryptographic Negotiation](https://tlswg.github.io/tls13-spec/draft-ietf-tls-tls13.html#cryptographic-negotiation))

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

如果一个服务器建立了一个老版本的TLS连接，并且在重新谈判中收到TLS 1.3 “ClientHello”，它必须保留之前的协议版本。特别是，它**必须**不能协商TLS 1.3。

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

**legacy_version**	在以前的TLS版本中，该字段用于版本协商，并代表客户端支持的最高版本号。经验表明，许多服务器没有适当地实现版本协商，导致"version intolerance"，在这个版本中，服务器拒绝接受一个比它支持的版本号更高的可接受的ClientHello。在TLS 1.3中，客户端在“supported_version”扩展(第4.2.1节)中表示其版本首选项，而legacy_version字段必须设置为0x0303，这是TLS 1.2的版本号。(有关向后兼容性的详细信息，请参阅附录D)。这个值不必是随机的，但应该是不可预测的，以避免僵化。否则它必须设为零长度向量(即一个零字节长度字段)。

**random**	由一个安全的随机数生成器生成的32字节。有关附加信息，请参阅`附录C`。

**legacy_session_id**	TLS 1.3之前的TLS版本支持“会话恢复”特性，该特性已与此版本中的预共享密钥合并(参见2.2节)。具有由pre-TLS 1.3服务器设置的缓存会话ID的客户机应该将该字段设置为该值。在兼容性模式(见附录D.4)中，该字段必须是非空的，因此一个未提供pre-TLS 1.3会话的客户机必须生成一个新的32字节值。

**cipher_suites**	这是客户端支持的对称密码选项的列表，具体来说就是记录保护算法(包括密钥长度)和使用HKDF的散列，按客户偏好的降序排列。如果该列表包含服务器不承认、不支持或不希望使用的密码套件，则服务器必须忽略这些密码套件，并像往常一样处理其余的密码。

**legacy_compression_methods**	TLS 1.3之前的版本支持压缩，并在此字段中发送支持的压缩方法列表。对于每个TLS 1.3 ClientHello，该向量必须精确地包含一个设置为零的一个字节，其对应于TLS的先前版本中的“null”压缩方法。如果接收到TLS 1.3 ClientHello与此字段中的任何其他值，则服务器必须使用“illegal_parameter”警报中止握手。请注意，TLS 1.3服务器可能接收TLS 1.2或之前的ClientHellos，其中包含其他压缩方法，并且必须遵循TLS的相应先前版本的过程。

**extensions**	客户端通过在扩展字段中发送数据请求服务器扩展功能。实际的“扩展”格式在第4.2节中定义。在TLS 1.3中，使用某些扩展是强制性的，因为功能被移动到扩展中以保持ClientHello与先前版本的TLS的兼容性。服务器必须忽略未识别的扩展。

所有版本的TLS都允许扩展字段可选择地遵循compression_methods字段。TLS 1.3 ClientHello消息总是包含扩展(至少有 "supported_versions"，否则将被解释为TLS 1.2 ClientHello消息)。然而，TLS 1.3服务器可能会接收到来自于以前版本TLS的没有扩展字段的ClientHello消息。可以通过确定在ClientHello结尾的compression_methods字段后面是否有字节来检测扩展的存在。注意，这种检测可选数据的方法不同于具有可变长度字段的常规TLS方法，但是在定义扩展之前，它用于与TLS的兼容性。TLS 1.3服务器将首先执行此检查，如果存在“支持版本”扩展，则仅尝试协商TLS 1.3。如果协商一个在1.3之前版本的TLS，服务器必须检查消息是否包含在legacy_compression_methods之后的任何数据，或者它包含一个没有数据的有效扩展块。如果没有，那么它必须以“decode_error”警报来中止握手。

如果客户端使用扩展请求附加的功能，而这个功能不是由服务器提供的，那么客户端可能会放弃握手。

发送ClientHello消息后，客户端等待一个ServerHello或HelloRetryRequest消息。如果使用早期数据，客户端可以在等待下一个握手消息时发送早期应用程序数据(第2.3节)。

### 4.1.3. Server Hello

服务器将发送此消息以响应ClientHello消息以进行握手，如果它能够协商出基于ClientHello的可接受的握手参数集合。

这个消息的结构:

```c
struct {
	ProtocolVersion legacy_version = 0x0303;    /* TLS v1.2 */
    Random random;
	opaque legacy_session_id_echo<0..32>;
	CipherSuite cipher_suite;
	uint8 legacy_compression_method = 0;
	Extension extensions<6..2^16-1>;
} ServerHello;
```

- **version** 在以前的TLS版本中，该字段用于版本协商，并表示连接的选定版本号。不幸的是，在呈现新值时出现了middlebox失败。在TLS 1.3中，TLS服务器使用“supported_version”扩展(第4.2.1节)表示其版本，而legacy_version字段必须设置为0x0303，这是TLS 1.2的版本号。(有关向后兼容性的详细信息，请参阅附录D)。
  - **random** 由一个安全的随机数生成器生成的32字节。有关附加信息，请参阅附录C。如果协商TLS 1.2或TLS 1.1，最后8个字节必须被覆盖，但是剩余的字节必须是随机的。这个结构是由服务器生成的，并且必须独立于 ClientHello.random 生成。
  - **legacy_session_id_echo** 客户端legacy_session_id字段的内容。注意，即使客户机的值对应于服务器选择不恢复的缓存的pre - tls 1.3会话，该字段也会得到响应。客户端接收 legacy_session_id 字段与在ClientHello中发送的内容不匹配，它必须以“illegal_parameter”警报来中止握手。
  - **cipher_suite** 服务器从ClientHello.cipher_suites列表中选择的单个密码套件。客户端接收到没有提供的密码套件必须以“illegal_parameter”警告中止握手。
  - **legacy_compression_method** 一个必须为0的字节。
  - **extensions** 扩展的列表。ServerHello必须仅包含建立加密上下文所需的扩展。目前，唯一的扩展是 “key_share” 和 “pre_shared_key”。所有当前TLS 1.3版本的 ServerHello消息将包含这两个扩展中的一个，或者在使用PSK (EC)DHE密钥建立时都包含这两个扩展。其余的扩展分别在EncryptedExtensions消息中单独发送。

  For backward compatibility reasons with  (see [Appendix D.4](https://tlswg.github.io/tls13-spec/draft-ietf-tls-tls13.html#middlebox)) the HelloRetryRequest message uses the same structure as the ServerHello, 

  由于 middleboxes 的向后兼容性原因(见`附录 D.4`)HelloRetryRequest消息使用和ServerHello一样的消息结构，但是Random设置了SHA-256“HelloRetryRequest”的特殊值:

  ```
  CF 21 AD 74 E5 9A 61 11 BE 1D 8C 02 1E 65 B8 91
  C2 A2 11 16 7A BB 8C 5E 07 9E 09 E2 C8 A8 33 9C
  ```

  在接收到带有server_hello类型的消息时，实现必须首先检查随机值，如果它匹配这个值，则按照`第4.1.4节`所述处理它。

  TLS 1.3的降级保护机制嵌入到服务器的随机值中。TLS 1.3服务器为了响应ClientHello而协商TLS 1.2或以下的服务器，必须特别设置其随机值的最后8个字节。

  如果协商TLS 1.2, TLS 1.3服务器必须将其随机值的最后8个字节设置为字节:

  ```
  44 4F 57 4E 47 52 44 01
  ```

  如果协商TLS 1.1或以下，TLS 1.3服务器**必须**，TLS 1.2服务器**应该**将其随机值的最后8个字节设置为字节:

  ```
  44 4F 57 4E 47 52 44 00
  ```

  TLS 1.3客户端接收一个ServerHello指示TLS 1.2或以下，**必须**检查最后8个字节是否与这些值中的任何一个都不相等。TLS 1.2客户端也应该检查最后8个字节不等于第二个值，如果ServerHello表示TLS 1.1或以下。如果找到匹配，则客户端必须以“illegal_parameter”警报中断握手。这一机制提供了有限的保护，以防止被降级攻击：因为ServerKeyExchange(在TLS 1.2及以下的一个消息)中包含了两个随机值的签名，对于一个主动攻击者来说，只要使用短暂的密码，就不可能对随机值进行修改。当使用静态RSA时，它不会提供降级保护。

  **注意**:这是由[RFC5246]更改的，因此在实践中，许多TLS 1.2客户机和服务器将不按照上面的规定运行。

  与TLS 1.2或之前进行重新谈判的遗留TLS客户端，在重新谈判过程中收到TLS 1.3 ServerHello，必须以“protocol_version”警报中止握手。请注意，当TLS 1.3已经谈判时重新谈判是不可能的。

### 4.1.4. Hello Retry Request

如果服务器能够找到相互支持的可接受的一组算法，但是客户端的ClientHello没有包含足够的信息来继续握手，则服务器发送此消息以响应ClientHello消息。如第4.1.3节所述，HelloRetryRequest具有与ServerHello消息相同的格式，legacy_version、legacy_session_id_echo、cipher_suite和legacy_compression方法字段具有相同的含义。但是，为了方便起见，我们在整个文档中讨论了HelloRetryRequest，就好像它是一个截然不同的消息一样。

服务器的扩展必须包含“supported_versions”，否则服务器应该只发送必要的扩展，以便客户端生成正确的ClientHello对。与ServerHello一样，一个HelloRetryRequest不能包含客户端在其ClientHello中首次提供的任何扩展，除了“cookie”(见第4.2.2节)的扩展之外。

在收到HelloRetryRequest后，客户机必须执行第4.1.3节中指定的检查，然后处理扩展，首先使用“supported_version”确定版本。如果“HelloRetryRequest”不会导致ClientHello的任何更改，客户必须中止与“illegal_parameter”的握手。如果客户端在同一连接中接收到第二个“HelloRetryRequest”请求。它必须以“unexpected_message”警报来中止握手。

否则，客户端必须处理HelloRetryRequest中的所有扩展，并发送第二个更新的ClientHello。在本规范中定义的HelloRetryRequest扩展是:

- supported_versions (see Section 4.2.1)
- cookie (see Section 4.2.2)
- key_share (see Section 4.2.8)

此外，在更新的ClientHello中，客户端不应该提供与所选密码套件以外的散列相关联的任何预共享密钥。这允许客户端避免在第二个ClientHello中计算多个哈希的部分哈希文本。客户端接收不提供的密码套件必须终止握手。服务器必须确保在接收到符合更新的ClientHello(如果服务器选择了密码套件作为协商的第一步，然后这将自动发生)时，协商相同的密码套件。在接收到ServerHello之后，客户端必须检查ServerHello中提供的密码套件是否与HelloRetryRequest中所提供的相同，否则将以“illegal_parameter”警告取消握手。

### 4.2. 扩展（[Extensions](https://tlswg.github.io/tls13-spec/draft-ietf-tls-tls13.html#extensions)）

一些TLS消息包含有标记长度的编码过的扩展结构。

```c
struct {
	ExtensionType extension_type;
	opaque extension_data<0..2^16-1>;
} Extension;

enum {
	server_name(0),                             /* RFC 6066 */
	max_fragment_length(1),                     /* RFC 6066 */
	status_request(5),                          /* RFC 6066 */
	supported_groups(10),                       /* RFC 4492, 7919 */
	signature_algorithms(13),                   /* [[this document]] */
	use_srtp(14),                               /* RFC 5764 */
	heartbeat(15),                              /* RFC 6520 */
	application_layer_protocol_negotiation(16), /* RFC 7301 */
	signed_certificate_timestamp(18),           /* RFC 6962 */
	client_certificate_type(19),                /* RFC 7250 */
	server_certificate_type(20),                /* RFC 7250 */
	padding(21),                                /* RFC 7685 */
	key_share(40),                              /* [[this document]] */
	pre_shared_key(41),                         /* [[this document]] */
	early_data(42),                             /* [[this document]] */
	supported_versions(43),                     /* [[this document]] */
	cookie(44),                                 /* [[this document]] */
	psk_key_exchange_modes(45),                 /* [[this document]] */
	certificate_authorities(47),                /* [[this document]] */
	oid_filters(48),                            /* [[this document]] */
	post_handshake_auth(49),                    /* [[this document]] */
	(65535)
} ExtensionType;
```
这个结构里：

- “extension_type”标识特定的扩展类型。
- “extension_data”包含特定于特定扩展类型的信息。

扩展类型的列表由IANA维护，如`第11节`所述。



### 4.3. 服务器参数

接下来的两个来自服务器的消息，EncryptedExtensions and CertificateRequest, 包含来自服务器的信息，它决定了握手的其余部分。这些消息使用来自server_handshake_traffic_secret的键进行加密。

#### 4.3.1. 加密扩展(Encrypted Extensions)

在所有的握手中，服务端**必须**在ServerHello消息后立刻发送EncryptedExtensions消息。这是在从server_handshake_traffic_secret派生的键加密的第一个消息。

EncryptedExtensions消息包含可以被保护的扩展，任何不需要建立密码上下文的，但与单独的证书不相关的。客户端必须检查EncryptedExtensions是否存在任何禁用的扩展，如果发现有，则必须以“illegal_parameter”警告中止与之握手。

这个消息的结构：

```
struct {
	Extension extensions<0..2^16-1>;
} EncryptedExtensions;
```

有关更多信息，请参见第4.2节中的表。

#### 4.3.2. 证书请求(Certificate Request)

正在使用证书进行身份验证的服务器可以选择从客户机请求证书。如果发送这个消息， 必须跟在EncryptedExtensions后面。

这个消息的结构：

```
struct {
	opaque certificate_request_context<0..2^8-1>;
	Extension extensions<2..2^16-1>;
} CertificateRequest;
```

certificate_request_context	An opaque string which identifies the certificate request and which will be echoed in the client’s Certificate message. The certificate_request_context MUST be unique within the scope of this connection (thus preventing replay of client CertificateVerify messages). This field SHALL be zero length unless used for the post-handshake authentication exchanges described in [Section 4.6.2](https://tlswg.github.io/tls13-spec/draft-ietf-tls-tls13.html#post-handshake-authentication). When requesting post-handshake authentication, the server SHOULD make the context unpredictable to the client (e.g., by randomly generating it) in order to prevent an attacker who has temporary access to the client’s private key from pre-computing valid CertificateVerify messages.

extensions	A set of extensions describing the parameters of the certificate being requested. The “signature_algorithms” extension MUST be specified, and other extensions may optionally be included if defined for this message. Clients MUST ignore unrecognized extensions.

在TLS的先前版本中，证书最重要的消息包含了一个签名算法和服务器所接受的证书颁发机构的列表。在TLS 1.3中，前者通过发送“signature_算法”扩展表示。后者通过发送“证书颁发机构”扩展来表示(见4.2.4节)。使用PSK进行身份验证的服务器不能在主握手中发送CertificateRequest消息，尽管他们可能在握手后进行身份验证(见4.6.2节)，但客户机已经发送了“post_handshake_auth”扩展(参见4.2.6节)。



### 4.4. 身份验证消息(Authentication Messages)





### 4.6. Post-Handshake 消息

TLS 也允许在主握手后发别的消息。这些消息使用一个握手内容类型，并在适当的应用程序通信密钥下进行加密。

#### 4.6.1. New Session Ticket 消息

在服务器接收到客户端完成消息之后的任何时间，它都可能发送一个NewSessionTicket消息。此消息创建了ticket和从恢复主机密中派生的秘密PSK之间的唯一关联。

客户端可以使用这个PSK来进行将来的握手，包括在其ClientHello(第4.2.11节)中的“pre_shared_key”扩展中包含ticket。服务端可以在一个连接上发送多个ticket。要么立即在对方之后，要么在特定事件后(见附录c . 4)。例如，服务器可能会在握手身份验证之后发送新的sessionTicket，以封装额外的客户机身份验证状态。多sessionTicket对客户端有多种用途，包括：

- 打开多个并行HTTP连接。
- 通过接口进行连接，通过诸如“快乐的眼球”(RFC8305)或相关技术来实现家庭的联系。

只有使用与建立原始连接相同的KDF哈希算法的密码套件才能恢复任何票据。

如果新的SNI值对在原始会话中显示的服务器证书有效，则客户端必须恢复。 则应该只恢复SNI值与原始会话中使用的值相匹配的情况。后者是性能优化：通常情况下，没有理由期望单个证书所覆盖的不同服务器能够接受对方的ticket，因此企图恢复这种情况将浪费一个一次性ticket。如果提供了这样的指示(外部或任何其他方式)，客户可以重新使用不同的SNI值。




















