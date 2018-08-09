---
title: Linux TCP相关参数
date: 2018-7-6 15:45:45
time: 1530860865
tags:
	- linux
	- tcp
categories: 网络
comments: true
---

# Linux TCP相关参数

下面以server端为视角，从连接建立、 数据包接收 和 数据包发送 这3条路径对参数进行归类梳理。

## 一、连接建立

![600597ea206d2763f202da8db3d1aadced0f88ab](https://oss.aliyuncs.com/yqfiles/600597ea206d2763f202da8db3d1aadced0f88ab.png)

简单看下连接的建立过程，客户端向server发送SYN包，server回复SYN＋ACK，同时将这个处于SYN_RECV状态的连接保存到半连接队列。客户端返回ACK包完成三次握手，server将ESTABLISHED状态的连接移入accept队列，等待应用调用accept()。

可以看到建立连接涉及两个队列：

- 半连接队列，保存SYN_RECV状态的连接。队列长度由net.ipv4.tcp_max_syn_backlog设置

- accept队列，保存ESTABLISHED状态的连接。队列长度为min(net.core.somaxconn, backlog)。其中backlog是我们创建ServerSocket(intport,int backlog)时指定的参数，如果我们设置的backlog大于net.core.somaxconn，accept队列的长度将被设置为net.core.somaxconn

另外，为了应对SYNflooding（即客户端只发送SYN包发起握手而不回应ACK完成连接建立，填满server端的半连接队列，让它无法处理正常的握手请求），Linux实现了一种称为SYNcookie的机制，通过net.ipv4.tcp_syncookies控制，设置为1表示开启。简单说SYNcookie就是将连接信息编码在ISN(initialsequencenumber)中返回给客户端，这时server不需要将半连接保存在队列中，而是利用客户端随后发来的ACK带回的ISN还原连接信息，以完成连接的建立，避免了半连接队列被攻击SYN包填满。对于一去不复返的客户端握手，不理它就是了。

## 二、数据包的接收

先看看接收数据包经过的路径：

![a888dbbb5c42ee0109d3111c97a4ee404899fb3b](https://oss.aliyuncs.com/yqfiles/a888dbbb5c42ee0109d3111c97a4ee404899fb3b.png)

数据包的接收，从下往上经过了三层：网卡驱动、系统内核空间，最后到用户态空间的应用。Linux内核使用sk_buff(socketkernel buffers)数据结构描述一个数据包。当一个新的数据包到达，NIC（networkinterface controller）调用DMAengine，通过RingBuffer将数据包放置到内核内存区。RingBuffer的大小固定，它不包含实际的数据包，而是包含了指向sk_buff的描述符。当RingBuffer满的时候，新来的数据包将给丢弃。一旦数据包被成功接收，NIC发起中断，由内核的中断处理程序将数据包传递给IP层。经过IP层的处理，数据包被放入队列等待TCP层处理。每个数据包经过TCP层一系列复杂的步骤，更新TCP状态机，最终到达recvBuffer，等待被应用接收处理。有一点需要注意，数据包到达recvBuffer，TCP就会回ACK确认，既TCP的ACK表示数据包已经被操作系统内核收到，但并不确保应用层一定收到数据（例如这个时候系统crash），因此一般建议应用协议层也要设计自己的确认机制。

上面就是一个相当简化的数据包接收流程，让我们逐层看看队列缓冲有关的参数。

1. 网卡Bonding模式
   当主机有1个以上的网卡时，Linux会将多个网卡绑定为一个虚拟的bonded网络接口，对TCP/IP而言只存在一个bonded网卡。多网卡绑定一方面能够提高网络吞吐量，另一方面也可以增强网络高可用。Linux支持7种Bonding模式：


   详细的说明参考内核文档LinuxEthernet Bonding Driver HOWTO。我们可以通过cat/proc/net/bonding/bond0查看本机的Bonding模式：

   一般很少需要开发去设置网卡Bonding模式，自己实验的话可以参考这篇文档

- Mode 0(balance-rr) Round-robin策略，这个模式具备负载均衡和容错能力
- Mode 1(active-backup) 主备策略，在绑定中只有一个网卡被激活，其他处于备份状态
- Mode 2(balance-xor) XOR策略，通过源MAC地址与目的MAC地址做异或操作选择slave网卡
- Mode 3 (broadcast) 广播，在所有的网卡上传送所有的报文
- Mode 4 (802.3ad) IEEE 802.3ad动态链路聚合。创建共享相同的速率和双工模式的聚合组
- Mode 5 (balance-tlb) Adaptive transmit loadbalancing
- Mode 6 (balance-alb) Adaptive loadbalancing

网卡多队列及中断绑定
随着网络的带宽的不断提升，单核CPU已经不能满足网卡的需求，这时通过多队列网卡驱动的支持，可以将每个队列通过中断绑定到不同的CPU核上，充分利用多核提升数据包的处理能力。
首先查看网卡是否支持多队列，使用lspci-vvv命令，找到Ethernetcontroller项：

![620a069ea1106e0da886ad412c35ceb5d4dfcf54](https://oss.aliyuncs.com/yqfiles/620a069ea1106e0da886ad412c35ceb5d4dfcf54.png)

如果有MSI-X， Enable+ 并且Count > 1，则该网卡是多队列网卡。

然后查看是否打开了网卡多队列。使用命令cat/proc/interrupts，如果看到eth0-TxRx-0表明多队列支持已经打开：

![926d94cb2cc548f5f2877ad65a1bdecef39d1ae8](https://oss.aliyuncs.com/yqfiles/926d94cb2cc548f5f2877ad65a1bdecef39d1ae8.png)

最后确认每个队列是否绑定到不同的CPU。cat/proc/interrupts查询到每个队列的中断号，对应的文件/proc/irq/${IRQ_NUM}/smp_affinity为中断号IRQ_NUM绑定的CPU核的情况。以十六进制表示，每一位代表一个CPU核：

（00000001）代表CPU0（00000010）代表CPU1（00000011）代表CPU0和CPU1

如果绑定的不均衡，可以手工设置，例如：

echo "1" > /proc/irq/99/smp_affinity echo "2" > /proc/irq/100/smp_affinity echo "4" > /proc/irq/101/smp_affinity echo "8" > /proc/irq/102/smp_affinity echo "10" > /proc/irq/103/smp_affinity echo "20" > /proc/irq/104/smp_affinity echo "40" > /proc/irq/105/smp_affinity echo "80" > /proc/irq/106/smp_affinity 

RingBuffer
Ring Buffer位于NIC和IP层之间，是一个典型的FIFO（先进先出）环形队列。RingBuffer没有包含数据本身，而是包含了指向sk_buff（socketkernel buffers）的描述符。
可以使用ethtool-g eth0查看当前RingBuffer的设置：

![419de6b6d5457bbab231453609cc293dda13a63f](https://oss.aliyuncs.com/yqfiles/419de6b6d5457bbab231453609cc293dda13a63f.png)

上面的例子接收队列为4096，传输队列为256。可以通过ifconfig观察接收和传输队列的运行状况：

![6cfcb57bc6a600d62830d9f6ececb679ae02dd2a](https://oss.aliyuncs.com/yqfiles/6cfcb57bc6a600d62830d9f6ececb679ae02dd2a.png)

- RXerrors：收包总的错误数
- RX dropped:表示数据包已经进入了RingBuffer，但是由于内存不够等系统原因，导致在拷贝到内存的过程中被丢弃。
- RX overruns:overruns意味着数据包没到RingBuffer就被网卡物理层给丢弃了，而CPU无法及时的处理中断是造成RingBuffer满的原因之一，例如中断分配的不均匀。
  当dropped数量持续增加，建议增大RingBuffer，使用ethtool-G进行设置。

InputPacket Queue(数据包接收队列)
当接收数据包的速率大于内核TCP处理包的速率，数据包将会缓冲在TCP层之前的队列中。接收队列的长度由参数net.core.netdev_max_backlog设置。

 

recvBuffer
recv buffer是调节TCP性能的关键参数。BDP(Bandwidth-delayproduct，带宽延迟积) 是网络的带宽和与RTT(roundtrip time)的乘积，BDP的含义是任意时刻处于在途未确认的最大数据量。RTT使用ping命令可以很容易的得到。为了达到最大的吞吐量，recvBuffer的设置应该大于BDP，即recvBuffer >= bandwidth * RTT。假设带宽是100Mbps，RTT是100ms，那么BDP的计算如下：

BDP = 100Mbps * 100ms = (100 / 8) * (100 / 1000) = 1.25MB

Linux在2.6.17以后增加了recvBuffer自动调节机制，recvbuffer的实际大小会自动在最小值和最大值之间浮动，以期找到性能和资源的平衡点，因此大多数情况下不建议将recvbuffer手工设置成固定值。
当net.ipv4.tcp_moderate_rcvbuf设置为1时，自动调节机制生效，每个TCP连接的recvBuffer由下面的3元数组指定：

net.ipv4.tcp_rmem =  

最初recvbuffer被设置为，同时这个缺省值会覆盖net.core.rmem_default的设置。随后recvbuffer根据实际情况在最大值和最小值之间动态调节。在缓冲的动态调优机制开启的情况下，我们将net.ipv4.tcp_rmem的最大值设置为BDP。
当net.ipv4.tcp_moderate_rcvbuf被设置为0，或者设置了socket选项SO_RCVBUF，缓冲的动态调节机制被关闭。recvbuffer的缺省值由net.core.rmem_default设置，但如果设置了net.ipv4.tcp_rmem，缺省值则被覆盖。可以通过系统调用setsockopt()设置recvbuffer的最大值为net.core.rmem_max。在缓冲动态调节机制关闭的情况下，建议把缓冲的缺省值设置为BDP。

 

注意这里还有一个细节，缓冲除了保存接收的数据本身，还需要一部分空间保存socket数据结构等额外信息。因此上面讨论的recvbuffer最佳值仅仅等于BDP是不够的，还需要考虑保存socket等额外信息的开销。Linux根据参数net.ipv4.tcp_adv_win_scale计算额外开销的大小：

![5c8e80dae645b41776ff97557da1611b5fc6fec3](https://oss.aliyuncs.com/yqfiles/5c8e80dae645b41776ff97557da1611b5fc6fec3.png)

如果net.ipv4.tcp_adv_win_scale的值为1，则二分之一的缓冲空间用来做额外开销，如果为2的话，则四分之一缓冲空间用来做额外开销。因此recvbuffer的最佳值应该设置为：

![200b16bb10a516f2947e816f4ee029350325bee2](https://oss.aliyuncs.com/yqfiles/200b16bb10a516f2947e816f4ee029350325bee2.png)

## 三、数据包的发送

发送数据包经过的路径：

![28e8a57db42f544afb9222f264ac40facf64f7bd](https://oss.aliyuncs.com/yqfiles/28e8a57db42f544afb9222f264ac40facf64f7bd.png)

和接收数据的路径相反，数据包的发送从上往下也经过了三层：用户态空间的应用、系统内核空间、最后到网卡驱动。应用先将数据写入TCP sendbuffer，TCP层将sendbuffer中的数据构建成数据包转交给IP层。IP层会将待发送的数据包放入队列QDisc(queueingdiscipline)。数据包成功放入QDisc后，指向数据包的描述符sk_buff被放入RingBuffer输出队列，随后网卡驱动调用DMAengine将数据发送到网络链路上。

同样我们逐层来梳理队列缓冲有关的参数。

1. sendBuffer
   同recvBuffer类似，和sendBuffer有关的参数如下：

   net.ipv4.tcp_wmem = net.core.wmem_defaultnet.core.wmem_max

   发送端缓冲的自动调节机制很早就已经实现，并且是无条件开启，没有参数去设置。如果指定了tcp_wmem，则net.core.wmem_default被tcp_wmem的覆盖。sendBuffer在tcp_wmem的最小值和最大值之间自动调节。如果调用setsockopt()设置了socket选项SO_SNDBUF，将关闭发送端缓冲的自动调节机制，tcp_wmem将被忽略，SO_SNDBUF的最大值由net.core.wmem_max限制。

2. QDisc
   QDisc（queueing discipline ）位于IP层和网卡的ringbuffer之间。我们已经知道，ringbuffer是一个简单的FIFO队列，这种设计使网卡的驱动层保持简单和快速。而QDisc实现了流量管理的高级功能，包括流量分类，优先级和流量整形（rate-shaping）。可以使用tc命令配置QDisc。
   QDisc的队列长度由txqueuelen设置，和接收数据包的队列长度由内核参数net.core.netdev_max_backlog控制所不同，txqueuelen是和网卡关联，可以用ifconfig命令查看当前的大小：

   ![68d2b35dbcb2bfea01822eb67c27e8dd355aa5e3](https://oss.aliyuncs.com/yqfiles/68d2b35dbcb2bfea01822eb67c27e8dd355aa5e3.png)

   使用ifconfig调整txqueuelen的大小：

   ifconfig eth0 txqueuelen 2000

3. RingBuffer
   和数据包的接收一样，发送数据包也要经过RingBuffer，使用ethtool-g eth0查看：

   ![40c9df795f4df8882c92845cfc787dc588479302](https://oss.aliyuncs.com/yqfiles/40c9df795f4df8882c92845cfc787dc588479302.png)

   其中TX项是RingBuffer的传输队列，也就是发送队列的长度。设置也是使用命令ethtool-G。

4. TCPSegmentation和Checksum Offloading
   操作系统可以把一些TCP/IP的功能转交给网卡去完成，特别是Segmentation(分片)和checksum的计算，这样可以节省CPU资源，并且由硬件代替OS执行这些操作会带来性能的提升。
   一般以太网的MTU（MaximumTransmission Unit）为1500 bytes，假设应用要发送数据包的大小为7300bytes，MTU1500字节－ IP头部20字节 －TCP头部20字节＝有效负载为1460字节，因此7300字节需要拆分成5个segment：

   ![53fe356d0b6b72820880df4ebcd47a85c1a17271](https://oss.aliyuncs.com/yqfiles/53fe356d0b6b72820880df4ebcd47a85c1a17271.png)

   Segmentation(分片)操作可以由操作系统移交给网卡完成，虽然最终线路上仍然是传输5个包，但这样节省了CPU资源并带来性能的提升：

   ​

   ![8ad5fced2f932c2b8cc6a4ae6f253a75360dd8ab](https://oss.aliyuncs.com/yqfiles/8ad5fced2f932c2b8cc6a4ae6f253a75360dd8ab.png)

   ​

   可以使用ethtool-k eth0查看网卡当前的offloading情况：

   ​

   ![144ad6969094cfaaf7f55d945e33777ddab06229](https://oss.aliyuncs.com/yqfiles/144ad6969094cfaaf7f55d945e33777ddab06229.png)

   ​

   上面这个例子checksum和tcpsegmentation的offloading都是打开的。如果想设置网卡的offloading开关，可以使用ethtool-K(注意K是大写)命令，例如下面的命令关闭了tcp segmentation offload：

   ​

   sudo ethtool -K eth0 tso off

5. 网卡多队列和网卡Bonding模式
   在数据包的接收过程中已经介绍过了。

至此，终于梳理完毕。整理TCP队列相关参数的起因是最近在排查一个网络超时问题，原因还没有找到，产生的“副作用”就是这篇文档。再想深入解决这个问题可能需要做TCP协议代码的profile，需要继续学习，希望不久的将来就可以再写文档和大家分享了。



## 三、连接关闭

1. **net.ipv4.tcp_timestamps**

RFC 1323 在 TCP Reliability一节里，引入了timestamp的TCP option，两个4字节的时间戳字段，其中第一个4字节字段用来保存发送该数据包的时间，第二个4字节字段用来保存最近一次接收对方发送到数据的时间。有了这两个时间字段，也就有了后续优化的余地。

tcp_tw_reuse 和 tcp_tw_recycle就依赖这些时间字段。

2. **net.ipv4.tcp_tw_reuse**

字面意思 reuse TIME_WAIT 状态的连接。

时刻记住一条socket连接就是个五元组，出现TIME_WAIT状态的连接，一定出现在主动关闭连接的一方。所以，当主动关闭连接的一方，再次向对方发起连接请求的时候（例如，客户端关闭连接，客户端再次连接服务端，此时可以复用了；负载均衡服务器，主动关闭后端的连接，当有新的HTTP请求，负载均衡服务器再次连接后端服务器，此时也可以复用），可以复用TIME_WAIT状态的连接。

通过字面解释，以及例子说明，你看到了，tcp_tw_reuse应用的场景：某一方，需要不断的通过“短连接”连接其他服务器，总是自己先关闭连接(TIME_WAIT在自己这方)，关闭后又不断的重新连接对方。

那么，当连接被复用了之后，延迟或者重发的数据包到达，新的连接怎么判断，到达的数据是属于复用后的连接，还是复用前的连接呢？那就需要依赖前面提到的两个时间字段了。复用连接后，这条连接的时间被更新为当前的时间，当延迟的数据达到，延迟数据的时间是小于新连接的时间，所以，内核可以通过时间判断出，延迟的数据可以安全的丢弃掉了。

这个配置，依赖于连接双方，同时对timestamps的支持。同时，这个配置，仅仅影响outbound连接，即做为客户端的角色，连接服务端[connect(dest_ip, dest_port)]时复用TIME_WAIT的socket。

3. **net.ipv4.tcp_tw_recycle**

快速回收/销毁掉 TIME_WAIT。

当开启了这个配置后，内核会快速的回收处于TIME_WAIT状态的socket连接。多快？不再是2MSL，而是一个RTO（retransmission timeout，数据包重传的timeout时间）的时间，这个时间根据RTT动态计算出来，但是远小于2MSL。

有了这个配置，还是需要保障 丢失重传或者延迟的数据包，不会被新的连接(注意，这里不再是复用了，而是之前处于TIME_WAIT状态的连接已经被destroy掉了，新的连接，刚好是和某一个被destroy掉的连接使用了相同的五元组而已)所错误的接收。在启用该配置，当一个socket连接进入TIME_WAIT状态后，内核里会记录包括该socket连接对应的五元组中的对方IP等在内的一些统计数据，当然也包括从该对方IP所接收到的最近的一次数据包时间。当有新的数据包到达，只要时间晚于内核记录的这个时间，数据包都会被统统的丢掉。

这个配置，依赖于连接双方对timestamps的支持。同时，这个配置，主要影响到了inbound的连接（对outbound的连接也有影响，但是不是复用），即做为服务端角色，客户端连进来，服务端主动关闭了连接，TIME_WAIT状态的socket处于服务端，服务端快速的回收该状态的连接。

# socket选项

## SO_LINGER

在默认情况下,当调用close关闭socke的使用,close会立即返回,如果send buffer中还有数据,系统会试着先把send buffer中的数据发送出去,然后close才返回.

SO_LINGER选项则是用来修改这种默认操作的.于SO_LINGER相关联的一个结构体如下:

```c
#include <sys/socket.h>  
struct linger {  
	int l_onoff  //0=off, nonzero=on(开关)  
	int l_linger //linger time(延迟时间)  
}  
```

1. 当l_onoff被设置为0的时候
  将会关闭SO_LINGER选项,即TCP或则SCTP保持默认操作:close立即返回.l_linger值被忽略。

2. l_lineoff值非0，0 = l_linger

   当调用close的时候,TCP连接会立即断开.send buffer中未被发送的数据将被丢弃,并向对方发送一个RST信息.值得注意的是，由于这种方式，是非正常的4中握手方式结束TCP链接，所以，TCP 连接将不会进入TIME_WAIT状态，这样会导致新建立的可能和就连接的数据造成混乱。

3. l_onoff和l_linger都是非0

   在这种情况下，调用close去关闭socket的时候，内核将会延迟。也就是说，如果send buffer中还有数据尚未发送，该进程将会被休眠直到一下任何一种情况发生：

   - send buffer中的所有数据都被发送并且得到对方TCP的应答消息（这种应答并不是意味着对方应用程序已经接收到数据，在后面shutdown将会具体讲道）
   - 延迟时间消耗完。在延迟时间被消耗完之后，send buffer中的所有数据都将会被丢弃。

上面两种情况中，如果socket被设置为O_NONBLOCK状态，程序将不会等待close返回，send buffer中的所有数据都将会被丢弃。所以，需要我们判断close的返回值。在send buffer中的所有数据都被发送之前并且延迟时间没有消耗完，close返回的话，close将会返回一个EWOULDBLOCK的error.

下面用几个实例来说明：

A.    Close默认操作：立即返回

​                                          ![img](http://hi.csdn.net/attachment/201009/20/4758664_1284946493v0CR.jpg)

此种情况，close立即返回，如果send buffer中还有数据，close将会等到所有数据被发送完之后之后返回。由于我们并没有等待对方TCP发送的ACK信息，所以我们只能保证数据已经发 送到对方，我们并不知道对方是否已经接受了数据。由于此种情况，TCP连接终止是按照正常的4次握手方式，需要经过TIME_WAIT。

 

   B.    l_onoff非0，并且使之l_linger为一个整数

 

 

​                                         ![img](http://hi.csdn.net/attachment/201009/20/4758664_1284946493YaXY.jpg)

在这种情况下，close会在接收到对方TCP的ACK信息之后才返回(l_linger消耗完之前)。但是这种ACK信息只能保证对方已经接收到数据，并不保证对方应用程序已经读取数据。

 

 

C.    l_linger设置值太小

 

 

​                                   ![img](http://hi.csdn.net/attachment/201009/20/4758664_12849464934Ozc.jpg)       

 

这种情况，由于l_linger值太小，在send buffer中的数据都发送完之前，close就返回，此种情况终止TCP连接，更l_linger = 0类似，TCP连接终止不是按照正常的4步握手，所以，TCP连接不会进入TIME_WAIT状态，那么，client会向server发送一个RST信 息.

 

 

D.    Shutdown，等待应用程序读取数据

 

 

 

​                                         ![img](http://hi.csdn.net/attachment/201009/20/4758664_1284946493rHmd.jpg)

同上面的B进行对比，调用shutdown后紧接着调用read,此时read会被阻塞,直到接收到对方的FIN,也就是说read是在 server的应用程序调用close之后才返回的。当server应用程序读取到来自client的数据和FIN之后，server会进入一个叫 CLOSE_WAIT，关于CLOSE_WAIT，详见我的博客[《 Linux 网络编程 之 TCP状态转换》](http://blog.csdn.net/feiyinzilgd/archive/2010/09/19/5893995.aspx) 。那么，如果server端要断开该TCP连接，需要server应用程序调用一次close，也就意味着向client发送FIN。这个时候，说明 server端的应用程序已经读取到client发送的数据和FIN。read会在接收到server的FIN之后返回。所以，shutdown 可以确保server端应用程序已经读取数据了，而不仅仅是server已经接收到数据而已。

 

shutdown参数如下:

SHUT_RD:调用shutdown的一端receive buffer将被丢弃掉,无法接受数据,但是可以发送数据,send buffer的数据可以被发送出去

SHUT_WR:调用shutdown的一端无法发送数据,但是可以接受数据.该参数表示不能调用send.但是如果还有数据在send buffer中,这些数据还是会被继续发送出去的.


## SO_REUSEADDR和SO_REUSEPORT

SO_REUSEADDR允许一个server程序listen监听并bind到一个端口,既是这个端口已经被一个正在运行的连接使用了.
SO_REUSEADDR允许同一个端口上绑定多个IP.只要这些IP不同.另外,还可以在绑定IP通配符.但是最好是先绑定确定的IP,最后绑定通配符IP.以免系统拒绝.

简而言之,SO_REUSEADDR允许多个server绑定到同一个port上,只要这些server指定的IP不同,但是SO_REUSEADDR需要在bind调用之前就设定.在TCP中,不允许建立起一个已经存在的相同的IP和端口的连接.但是在UDP中,是允许的.

我们一般会在下面这种情况中遇到:

1. 一个监听(listen)server已经启动
2. 当有client有连接请求的时候,server产生一个子进程去处理该client的事物.
3. server主进程终止了,但是子进程还在占用该连接处理client的事情.虽然子进程终止了,但是由于子进程没有终止,该socket的引用计数不会为0，所以该socket不会被关闭.
4. server程序重启.

默认情况下,server重启,调用socket,bind,然后listen会失败.因为该端口正在被使用.如果设定SO_REUSEADDR,那么server重启才会成功.因此,所有的TCP server都必须设定此选项,用以应对server重启的现象.