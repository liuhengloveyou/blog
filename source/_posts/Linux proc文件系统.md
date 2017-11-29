---
title: Linux proc文件系统
date: 2017-10-13 11:45:45
time: 1507866366
tags:
  - linux
  - proc
categories: 性能调优
comments: true
---

### /proc目录下查询

Linux 内核提供了一种通过 /proc 文件系统，在运行时访问内核内部数据结构、改变内核设置的机制。proc文件系统是一个伪文件系统，它只存在内存当中，而不占用外存空间。它以文件系统的方式为访问系统内核数据的操作提供接口。

用户和应用程序可以通过 proc得到系统的信息，并可以改变内核的某些参数。由于系统的信息，如进程，是动态改变的，所以用户或应用程序读取proc文件时，proc文件系统是 动态从系统内核读出所需信息并提交的。下面列出的这些文件或子文件夹，并不是都是在你的系统中存在，这取决于你的内核配置和装载的模块。另外，在 /proc下还有三个很重要的目录：net，scsi和sys。 Sys目录是可写的，可以通过它来访问或修改内核的参数，而net和scsi则依赖于内核配置。例如，如果系统不支持scsi，则scsi 目录不存在。

除了以上介绍的这些，还有的是一些以数字命名的目录，它们是进程目录。系统中当前运行的每一个进程都有对应的一个目录在/proc下，以进程的 PID号为目录名，它们是读取进程信息的接口。而self目录则是读取进程本身的信息接口，是一个link。

#### 例子1：可以使用cat /proc/xxx,显示相应信息。

 

[![复制代码](http://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

```
/proc/buddyinfo      ###每个内存区中的每个order有多少块可用，和内存碎片问题有关

/proc/cmdline        ###启动时传递给kernel的参数信息

/proc/cpuinfo        ###cpu的信息，physical为物理CPU，cpu cores为物理cpu中的核心，而processor为逻辑cpu，例如开了超线程，可能会出现4个核心，8个逻辑cpu；siblings>cpu cores 则开了超线程

/proc/crypto         ###内核使用的所有已安装的加密密码及细节

/proc/devices        ###已经加载的设备并分类

/proc/dma            ###已注册使用的ISA DMA频道列表

/proc/execdomains    ###Linux内核当前支持的execution domains

/proc/fb             ###帧缓冲设备列表，包括数量和控制它的驱动

/proc/filesystems    ###内核当前支持的文件系统类型

/proc/interrupts     ###x86架构中的每个IRQ中断数

/proc/iomem          ###每个物理设备当前在系统内存中的映射

/proc/ioports        ###一个设备的输入输出所使用的注册端口范围

/proc/kcore          ###代表系统的物理内存，存储为核心文件格式，里边显示的是字节数，等于RAM大小加上4kb

/proc/kmsg           ###记录内核生成的信息，可以通过/sbin/klogd或/bin/dmesg来处理

/proc/loadavg     　　###根据过去一段时间内CPU和IO的状态得出的负载状态，与uptime命令有关
/proc/locks          ###内核锁住的文件列表

/proc/mdstat         ###多硬盘，RAID配置信息(md=multiple disks)

/proc/meminfo        ###RAM使用的相关信息

/proc/misc           ###其他的主要设备(设备号为10)上注册的驱动

/proc/modules        ###所有加载到内核的模块列表

/proc/mounts         ###系统中使用的所有挂载

/proc/mtrr           ###系统使用的Memory Type Range Registers (MTRRs)

/proc/partitions     ###分区中的块分配信息

/proc/pci            ###系统中的PCI设备列表

/proc/slabinfo       ###系统中所有活动的 slab 缓存信息

/proc/stat           ### 所有的CPU活动信息

/proc/sysrq-trigger  ###    

 /proc/uptime     　　###系统已经运行了多久

/proc/swaps      　　 ###交换空间的使用情况

/proc/version     　　###Linux内核版本和gcc版本

/proc/bus          　 ###系统总线(Bus)信息，例如pci/usb等

/proc/driver      　　###驱动信息

/proc/fs             ###文件系统信息

/proc/ide          　###ide设备信息

/proc/irq          　###中断请求设备信息

/proc/net         　　###网卡设备信息

/proc/scsi         　 ###scsi设备信息

/proc/tty            ### tty设备信息

/proc/net/dev     　　###显示网络适配器及统计信息

/proc/vmstat      　　###虚拟内存统计信息

/proc/vmcore     　　 ###内核panic时的内存映像

/proc/diskstats    　### 取得磁盘信息

/proc/schedstat   　　### kernel调度器的统计信息

/proc/zoneinfo     　###显示内存空间的统计信息，对分析虚拟内存行为很有用   
```

[![复制代码](http://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

 

#### 　　　　　例子2：显示某个进程相关的信息

[![复制代码](http://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

```
/proc/N 　　　　　　　###pid为N的进程信息

/proc/N/cmdline 　　###进程启动命令

/proc/N/cwd 　　　　 ###链接到进程当前工作目录

/proc/N/environ 　　###进程环境变量列表

/proc/N/exe 　　　　 ###链接到进程的执行命令文件

/proc/N/fd 　　　　　###包含进程相关的所有的文件描述符

/proc/N/maps 　　　　###与进程相关的内存映射信息

/proc/N/mem 　　　　 ###指代进程持有的内存，不可读

/proc/N/root 　　　　###链接到进程的根目录

/proc/N/stat 　　　　###进程的状态

/proc/N/statm 　　　 ###进程使用的内存的状态

/proc/N/status 　　　###进程状态信息，比stat/statm更具可读性

/proc/self 　　　　　 ###链接到当前正在运行的进程
```

[![复制代码](http://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

#### 　　　　 例子3：显示整个系统内存映像

```
$cat /proc/iomem
```

　　　　显示效果如下

[![复制代码](http://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

```
00000000-00000fff : reserved
00001000-0009fbff : System RAM
0009fc00-0009ffff : RAM buffer
000a0000-000bffff : PCI Bus 0000:00
000c0000-000effff : PCI Bus 0000:00
  000c0000-000ccfff : Video ROM
  000cf000-000cffff : Adapter ROM
000f0000-000fffff : PCI Bus 0000:00
  000f0000-000fffff : reserved
    000f0000-000fffff : System ROM
00100000-dfdf9bff : System RAM
  01000000-017bc95b : Kernel code
  017bc95c-01d2593f : Kernel data
  01e90000-01fd2fff : Kernel bss
dfdf9c00-dfe4bbff : ACPI Non-volatile Storage
dfe4bc00-dfe4dbff : ACPI Tables
dfe4dc00-f7ffffff : reserved
  dff00000-f7ffffff : PCI Bus 0000:00
    e0000000-efffffff : PCI Bus 0000:02
      e0000000-efffffff : 0000:02:00.0
    f0000000-f01fffff : PCI Bus 0000:04
    f0200000-f03fffff : PCI Bus 0000:04
    f3d00000-f3dfffff : PCI Bus 0000:05
      f3de0000-f3deffff : 0000:05:00.0
        f3de0000-f3deffff : tg3
      f3df0000-f3dfffff : 0000:05:00.0
        f3df0000-f3dfffff : tg3
    f3e00000-f3efffff : PCI Bus 0000:01
    f3f00000-f3ffffff : PCI Bus 0000:03
    f4000000-f7efffff : PCI Bus 0000:02
      f4000000-f5ffffff : 0000:02:00.0
      f6000000-f6ffffff : 0000:02:00.0
      f7e00000-f7e1ffff : 0000:02:00.0
    f7ffa000-f7ffa3ff : 0000:00:1a.7
      f7ffa000-f7ffa3ff : ehci_hcd
    f7ffb000-f7ffb0ff : 0000:00:1f.3
    f7ffc000-f7ffffff : 0000:00:1b.0
      f7ffc000-f7ffffff : ICH HD audio
f8000000-fcffffff : reserved
  f8000000-fbffffff : PCI MMCONFIG 0000 [bus 00-3f]
fe000000-fed003ff : reserved
  fec00000-fec003ff : IOAPIC 0
  fec80000-fec803ff : IOAPIC 1
  fed00000-fed003ff : HPET 0
    fed00000-fed003ff : PNP0103:00
fed20000-fed9ffff : PCI Bus 0000:00
fedab410-fedab414 : iTCO_wdt
fee00000-feefffff : reserved
  fee00000-fee00fff : Local APIC
ff97c000-ff97ffff : PCI Bus 0000:00
ff980000-ff980fff : PCI Bus 0000:00
  ff980000-ff9803ff : 0000:00:1d.7
    ff980000-ff9803ff : ehci_hcd
ffb00000-ffffffff : reserved
100000000-41fffffff : System RAM
```

[![复制代码](http://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

#### 　　　　 例子4：显示进程的内存映像

```
$cat /proc/N/maps
```

　　　　显示效果：一共分6列，

列1：address: 0085d000-00872000 虚拟内存区域的起始和终止地址文件所占的地址空间
列2：perms:rw-p 权限：r=read, w=write, x=execute, s=shared, p=private(copy on write)
列3：offset: 00000000 虚拟内存区域在被映射文件中的偏移量
列4：dev: 03:08 文件的主设备号和次设备号
列5：inode: 设备的节点号，0表示没有节点与内存相对应
列6：name: /lib/ld-2.3.4.so 被映射文件的文件名

[![复制代码](http://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

```
列1　　　　　　　　　 列2　　列3　　　　列4　　列5　　　　　　　　　　　　　　　　　　　　列6　
00400000-006bc000 r-xp 00000000 fc:01 2360287                            /usr/bin/python2.7  
008bb000-008bc000 r--p 002bb000 fc:01 2360287                            /usr/bin/python2.7
008bc000-00931000 rw-p 002bc000 fc:01 2360287                            /usr/bin/python2.7
00931000-00943000 rw-p 00000000 00:00 0 
01fa7000-02c15000 rw-p 00000000 00:00 0                                  [heap]
7f6ef306f000-7f6ef30af000 rw-p 00000000 00:00 0 
7f6ef30ef000-7f6ef3df0000 rw-p 00000000 00:00 0 
7f6ef3df0000-7f6ef3dfc000 r-xp 00000000 fc:01 2493117                    /usr/lib/python2.7/dist-packages/OpenSSL/SSL.so
7f6ef3dfc000-7f6ef3ffb000 ---p 0000c000 fc:01 2493117                    /usr/lib/python2.7/dist-packages/OpenSSL/SSL.so
7f6ef3ffb000-7f6ef3ffc000 r--p 0000b000 fc:01 2493117                    /usr/lib/python2.7/dist-packages/OpenSSL/SSL.so
7f6ef3ffc000-7f6ef4000000 rw-p 0000c000 fc:01 2493117                    /usr/lib/python2.7/dist-packages/OpenSSL/SSL.so

```

[![复制代码](http://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

 











深入理解linux系统下proc文件系统内容

Linux系统上的/proc目录是一种文件系统，即proc文件系统。与其它常见的文件系统不同的是，/proc是一种伪文件系统（也即虚拟文件系统），存储的是当前内核运行状态的一系列特殊文件，用户可以通过这些文件查看有关系统硬件及当前正在运行进程的信息，甚至可以通过更改其中某些文件来改变内核的运行状态。

基于/proc文件系统如上所述的特殊性，其内的文件也常被称作虚拟文件，并具有一些独特的特点。例如，其中有些文件虽然使用查看命令查看时会返回大量信息，但文件本身的大小却会显示为0字节。此外，这些特殊文件中大多数文件的时间及日期属性通常为当前系统时间和日期，这跟它们随时会被刷新（存储于RAM中）有关。

为了查看及使用上的方便，这些文件通常会按照相关性进行分类存储于不同的目录甚至子目录中，如/proc/scsi目录中存储的就是当前系统上所有SCSI设备的相关信息，/proc/N中存储的则是系统当前正在运行的进程的相关信息，其中N为正在运行的进程（可以想象得到，在某进程结束后其相关目录则会消失）。

大多数虚拟文件可以使用文件查看命令如cat、more或者less进行查看，有些文件信息表述的内容可以一目了然，但也有文件的信息却不怎么具有可读性。不过，这些可读性较差的文件在使用一些命令如apm、free、lspci或top查看时却可以有着不错的表现。

一、        进程目录中的常见文件介绍

/proc目录中包含许多以数字命名的子目录，这些数字表示系统当前正在运行进程的进程号，里面包含对应进程相关的多个信息文件。

上面列出的是/proc目录中一些进程相关的目录，每个目录中是当程本身相关信息的文件。下面是作者系统（RHEL5.3）上运行的一个PID为2674的进程saslauthd的相关文件，其中有些文件是每个进程都会具有的，后文会对这些常见文件做出说明。

1.1、cmdline — 启动当前进程的完整命令，但僵尸进程目录中的此文件不包含任何信息；

1.2、cwd — 指向当前进程运行目录的一个符号链接；

1.3、environ — 当前进程的环境变量列表，彼此间用空字符（NULL）隔开；变量用大写字母表示，其值用小写字母表示；

1.4、exe — 指向启动当前进程的可执行文件（完整路径）的符号链接，通过/proc/N/exe可以启动当前进程的一个拷贝；

1.5、fd — 这是个目录，包含当前进程打开的每一个文件的文件描述符（file descriptor），这些文件描述符是指向实际文件的一个符号链接；

1.6、limits — 当前进程所使用的每一个受限资源的软限制、硬限制和管理单元；此文件仅可由实际启动当前进程的UID用户读取；（2.6.24以后的内核版本支持此功能）；

1.7、maps — 当前进程关联到的每个可执行文件和库文件在内存中的映射区域及其访问权限所组成的列表；

1.8、mem — 当前进程所占用的内存空间，由open、read和lseek等系统调用使用，不能被用户读取；

1.9、root — 指向当前进程运行根目录的符号链接；在Unix和Linux系统上，通常采用chroot命令使每个进程运行于独立的根目录；

1.10、stat — 当前进程的状态信息，包含一系统格式化后的数据列，可读性差，通常由ps命令使用；

1.11、statm — 当前进程占用内存的状态信息，通常以“页面”（page）表示；

1.12、status — 与stat所提供信息类似，但可读性较好，如下所示，每行表示一个属性信息；其详细介绍请参见 proc的man手册页；

1.13、task — 目录文件，包含由当前进程所运行的每一个线程的相关信息，每个线程的相关信息文件均保存在一个由线程号（tid）命名的目录中，这类似于其内容类似于每个进程目录中的内容；（内核2.6版本以后支持此功能）

二、/proc目录下常见的文件介绍

2.1、/proc/apm

高级电源管理（APM）版本信息及电池相关状态信息，通常由apm命令使用；

2.2、/proc/buddyinfo

用于诊断内存碎片问题的相关信息文件；

2.3、/proc/cmdline

在启动时传递至内核的相关参数信息，这些信息通常由lilo或grub等启动管理工具进行传递；

2.4、/proc/cpuinfo

处理器的相关信息的文件；

2.5、/proc/crypto

系统上已安装的内核使用的密码算法及每个算法的详细信息列表；

2.6、/proc/devices

系统已经加载的所有块设备和字符设备的信息，包含主设备号和设备组（与主设备号对应的设备类型）名；

2.7、/proc/diskstats

每块磁盘设备的磁盘I/O统计信息列表；（内核2.5.69以后的版本支持此功能）

2.8、/proc/dma

每个正在使用且注册的ISA DMA通道的信息列表；

2.9、/proc/execdomains

内核当前支持的执行域（每种操作系统独特“个性”）信息列表；

2.10、/proc/fb

帧缓冲设备列表文件，包含帧缓冲设备的设备号和相关驱动信息；

2.11、/proc/filesystems

当前被内核支持的文件系统类型列表文件，被标示为nodev的文件系统表示不需要块设备的支持；通常mount一个设备时，如果没有指定文件系统类型将通过此文件来决定其所需文件系统的类型；

2.12、/proc/interrupts

X86或X86_64体系架构系统上每个IRQ相关的中断号列表；多路处理器平台上每个CPU对于每个I/O设备均有自己的中断号；

2.13、/proc/iomem

每个物理设备上的记忆体（RAM或者ROM）在系统内存中的映射信息；

2.14、/proc/ioports

当前正在使用且已经注册过的与物理设备进行通讯的输入-输出端口范围信息列表；如下面所示，第一列表示注册的I/O端口范围，其后表示相关的设备；

2.15、/proc/kallsyms

模块管理工具用来动态链接或绑定可装载模块的符号定义，由内核输出；（内核2.5.71以后的版本支持此功能）；通常这个文件中的信息量相当大；

2.16、/proc/kcore

系统使用的物理内存，以ELF核心文件（core file）格式存储，其文件大小为已使用的物理内存（RAM）加上4KB；这个文件用来检查内核数据结构的当前状态，因此，通常由GBD通常调试工具使用，但不能使用文件查看命令打开此文件；

2.17、/proc/kmsg

此文件用来保存由内核输出的信息，通常由/sbin/klogd或/bin/dmsg等程序使用，不要试图使用查看命令打开此文件；

2.18、/proc/loadavg

保存关于CPU和磁盘I/O的负载平均值，其前三列分别表示每1秒钟、每5秒钟及每15秒的负载平均值，类似于uptime命令输出的相关信息；第四列是由斜线隔开的两个数值，前者表示当前正由内核调度的实体（进程和线程）的数目，后者表示系统当前存活的内核调度实体的数目；第五列表示此文件被查看前最近一个由内核创建的进程的PID；

2.19、/proc/locks

保存当前由内核锁定的文件的相关信息，包含内核内部的调试数据；每个锁定占据一行，且具有一个惟一的编号；如下输出信息中每行的第二列表示当前锁定使用的锁定类别，POSIX表示目前较新类型的文件锁，由lockf系统调用产生，FLOCK是传统的UNIX文件锁，由flock系统调用产生；第三列也通常由两种类型，ADVISORY表示不允许其他用户锁定此文件，但允许读取，MANDATORY表示此文件锁定期间不允许其他用户任何形式的访问；

2.20、/proc/mdstat

保存RAID相关的多块磁盘的当前状态信息，在没有使用RAID机器上，其显示为如下状态：

2.21、/proc/meminfo

系统中关于当前内存的利用状况等的信息，常由free命令使用；可以使用文件查看命令直接读取此文件，其内容显示为两列，前者为统计属性，后者为对应的值；

2.22、/proc/mounts

在内核2.4.29版本以前，此文件的内容为系统当前挂载的所有文件系统，在2.4.19以后的内核中引进了每个进程使用独立挂载名称空间的方式，此文件则随之变成了指向/proc/self/mounts（每个进程自身挂载名称空间中的所有挂载点列表）文件的符号链接；/proc/self是一个独特的目录，后文中会对此目录进行介绍；

如下所示，其中第一列表示挂载的设备，第二列表示在当前目录树中的挂载点，第三点表示当前文件系统的类型，第四列表示挂载属性（ro或者rw），第五列和第六列用来匹配/etc/mtab文件中的转储（dump）属性；

2.23、/proc/modules

当前装入内核的所有模块名称列表，可以由lsmod命令使用，也可以直接查看；如下所示，其中第一列表示模块名，第二列表示此模块占用内存空间大小，第三列表示此模块有多少实例被装入，第四列表示此模块依赖于其它哪些模块，第五列表示此模块的装载状态（Live：已经装入；Loading：正在装入；Unloading：正在卸载），第六列表示此模块在内核内存（kernel memory）中的偏移量；

2.24、/proc/partitions

块设备每个分区的主设备号（major）和次设备号（minor）等信息，同时包括每个分区所包含的块（block）数目（如下面输出中第三列所示）；

2.25、/proc/pci

内核初始化时发现的所有PCI设备及其配置信息列表，其配置信息多为某PCI设备相关IRQ信息，可读性不高，可以用“/sbin/lspci –vb”命令获得较易理解的相关信息；在2.6内核以后，此文件已为/proc/bus/pci目录及其下的文件代替；

2.26、/proc/slabinfo

在内核中频繁使用的对象（如inode、dentry等）都有自己的cache，即slab pool，而/proc/slabinfo文件列出了这些对象相关slap的信息；详情可以参见内核文档中slapinfo的手册页；

2.27、/proc/stat

实时追踪自系统上次启动以来的多种统计信息；如下所示，其中，

“cpu”行后的八个值分别表示以1/100（jiffies）秒为单位的统计值（包括系统运行于用户模式、低优先级用户模式，运系统模式、空闲模式、I/O等待模式的时间等）；

“intr”行给出中断的信息，第一个为自系统启动以来，发生的所有的中断的次数；然后每个数对应一个特定的中断自系统启动以来所发生的次数；

“ctxt”给出了自系统启动以来CPU发生的上下文交换的次数。

“btime”给出了从系统启动到现在为止的时间，单位为秒；

“processes (total_forks) 自系统启动以来所创建的任务的个数目；

“procs_running”：当前运行队列的任务的数目；

“procs_blocked”：当前被阻塞的任务的数目；

2.28、/proc/swaps

当前系统上的交换分区及其空间利用信息，如果有多个交换分区的话，则会每个交换分区的信息分别存储于/proc/swap目录中的单独文件中，而其优先级数字越低，被使用到的可能性越大；下面是作者系统中只有一个交换分区时的输出信息；

2.29、/proc/uptime

系统上次启动以来的运行时间，如下所示，其第一个数字表示系统运行时间，第二个数字表示系统空闲时间，单位是秒；

2.30、/proc/version

当前系统运行的内核版本号，在作者的RHEL5.3上还会显示系统安装的gcc版本，如下所示；

2.31、/proc/vmstat

当前系统虚拟内存的多种统计数据，信息量可能会比较大，这因系统而有所不同，可读性较好；下面为作者机器上输出信息的一个片段；（2.6以后的内核支持此文件）

2.32、/proc/zoneinfo

内存区域（zone）的详细信息列表，信息量较大，下面列出的是一个输出片段：

三、/proc/sys目录详解

与/proc下其它文件的“只读”属性不同的是，管理员可对/proc/sys子目录中的许多文件内容进行修改以更改内核的运行特性，事先可以使用“ls -l”命令查看某文件是否“可写入”。写入操作通常使用类似于“echo  DATA > /path/to/your/filename”的格式进行。需要注意的是，即使文件可写，其一般也不可以使用编辑器进行编辑。

3.1、/proc/sys/debug 子目录

此目录通常是一空目录；

3.2、/proc/sys/dev 子目录

为系统上特殊设备提供参数信息文件的目录，其不同设备的信息文件分别存储于不同的子目录中，如大多数系统上都会具有的/proc/sys/dev/cdrom和/proc/sys/dev/raid（如果内核编译时开启了支持raid的功能） 目录，其内存储的通常是系统上cdrom和raid的相关参数信息文件。