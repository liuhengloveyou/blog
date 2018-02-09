---
title: Linux 性能监测：mem
date: 2017-10-13 11:45:45
time: 1507866364
tags:
  - linux
  - mem
categories: 性能调优
comments: true
---

## 关于内存系统

linux 系统中内存地址分为虚拟地址和物理地址，虚拟地址必须通过mmu映射成物理地址。为了完成虚拟地址到物理地址的映射，linux内核中必须为每一个用户态进程维护一个页目录和相应的页表项。一般系统中页表中一页大小为4K，利用getconf PAGESIZE可以获取系统中页大小。

### linux伙伴系统

为了将系统中的内存页做相应的管理，linux内核将系统中内存为分为不同的**node**，**zone**。系统将不同cpu访问速率的内存归纳为不同的**node**；**zone**表示同一个**node**不同内存区域，一般分问DMA， NORMAL， HIGHMEM。
每一个zone上面有active_list，inactive_list.在每一个zone中需要管理这个ZONE中的活动页和非活动页，这样就方便每个ZONE中页面的回收nr_inactive_anon 3949nr_active_anon 3299nr_inactive_file 7305nr_active_file 3182nr_unevictable 0页面交换，linux可以将系统中匿名页交换到交换分区或者交换文件中去，当系统中的内存紧张时。swapon -s 查看系统中交换分区或者交换文件使用情况swapon -a 开启系统的交换功能swapoff -a 关闭系统的交换功能系统中缓存类型分为页缓存和块缓存。当系统去读取文件系统中的文件时，系统会将读到的文件的内容缓存到一个地址空间中，组成这个地址空间的内存页就是页缓存，叫做cache.系统在读取文件系统中类似目录，超级块或者管理块时，读取到系统中的内存页中，这种页面叫做块缓存，也叫做buffer.linux如果按页管理分配内存，对较小的内存分配是一种严重的浪费。slab内存分配器解决内核空间较小的内存分配问题。slab就是为了满足内核中各个模块特定大小内存的快速分配，就从伙伴系统中要出内存页，自己建立一个相对独立的内存池子，向特定的内核模块分配特定大小的内存。slabtopcat /**proc**/slabinfo**linux系统中内存使用分类******内核系统中分配的内存用户态代码段，数据段，堆空间，栈空间文件地址空间缓存，块缓存文件在用户空间的地址映射消耗的内存.mmap 匿名映射的页，shmem共享内存使用的页.**可回收的页和不可回收的页******上面总结了linux中内存页的不同种类，上面不同类型的页面基本上可以分为两种不同的类型，一种是可回收页面，另外一种为不可以回收的页面。除了第一种，内核系统中分配的内存为不可回收的外，其它类型的页面都是可以回收的页面。**可回收页面分类******匿名页面需要将页面内容交换到交换设备或者文件才能回收该页面文件地址空间缓存，块缓存通过回写页面内容后再回收页面.**如何查看系统中不同类型内存数量******使用这个命令可以看到系统中空闲内存数量，buffer缓存数量，页缓存数量.同时可以看到交换分区换入，换出页面的数目.root@localhost:~**# vmstat 1 -S m**procs -----------memory---------- ---swap-- -----io---- -system-- ----cpu---- r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa21  0      0    665     69    508    0    0     0     0   19    5 38  3 59  019  0      0    665     69    508    0    0     0     0 2161 3112 97  4  0  020  0      0    665     69    508    0    0     0     0 1903 3394 97  3  0  0**查看进程内存使用情况******topshift + mlinux系统中的进程按照消耗内存大小进行排列，VIRT表示虚拟地址空间内存大小，RES表示实际内存使用大小。shift + plinux系统中的进程按照消耗CPU大小进行排列**使用****pmap查看进程内存使用情况********pmap** pid我们可以看到整个进程占用的虚拟内存的情况**查看****slab使用情况******slabtopcat /proc/slabinfo

这里的讲到的 “内存” 包括物理内存和虚拟内存，虚拟内存（Virtual Memory）把计算机的内存空间扩展到硬盘，物理内存（RAM）和硬盘的一部分空间（SWAP）组合在一起作为虚拟内存为计算机提供了一个连贯的虚拟内存空间，好处是我们拥有的内存 ”变多了“，可以运行更多、更大的程序，坏处是把部分硬盘当内存用整体性能受到影响，硬盘读写速度要比内存慢几个数量级，并且 RAM 和 SWAP 之间的交换增加了系统的负担。

在操作系统里，虚拟内存被分成页，在 x86 系统上每个页大小是 4KB。Linux 内核读写虚拟内存是以 “页” 为单位操作的，把内存转移到硬盘交换空间（SWAP）和从交换空间读取到内存的时候都是按页来读写的。内存和 SWAP 的这种交换过程称为页面交换（Paging），值得注意的是 paging 和 swapping 是两个完全不同的概念，国内很多参考书把这两个概念混为一谈，swapping 也翻译成交换，在操作系统里是指把某程序完全交换到硬盘以腾出内存给新程序使用，和 paging 只交换程序的部分（页面）是两个不同的概念。纯粹的 swapping 在现代操作系统中已经很难看到了，因为把整个程序交换到硬盘的办法既耗时又费力而且没必要，现代操作系统基本都是 paging 或者 paging/swapping 混合，swapping 最初是在 Unix system V 上实现的。

虚拟内存管理是 Linux 内核里面最复杂的部分，要弄懂这部分内容可能需要[一整本书的讲解](http://www.amazon.com/Understanding-Linux-Virtual-Memory-Manager/dp/0131453483)。VPSee 在这里只介绍和性能监测有关的两个内核进程：kswapd 和 pdflush。

kswapd daemon 用来检查 pages_high 和 pages_low，如果可用内存少于 pages_low，kswapd 就开始扫描并试图释放 32个页面，并且重复扫描释放的过程直到可用内存大于 pages_high 为止。扫描的时候检查3件事：1）如果页面没有修改，把页放到可用内存列表里；2）如果页面被文件系统修改，把页面内容写到磁盘上；3）如果页面被修改了，但不是被文件系统修改的，把页面写到交换空间。pdflush daemon 用来同步文件相关的内存页面，把内存页面及时同步到硬盘上。比如打开一个文件，文件被导入到内存里，对文件做了修改后并保存后，内核并不马上保存文件到硬盘，由 pdflush 决定什么时候把相应页面写入硬盘，这由一个内核参数 vm.dirty_background_ratio 来控制，比如下面的参数显示脏页面（dirty pages）达到所有内存页面10％的时候开始写入硬盘。·········10········20········30········40········50········60········1.# /sbin/sysctl -n vm.dirty_background_ratio2.10vmstat继续 vmstat 一些参数的介绍，上一篇 [Linux 性能监测：CPU](http://linux.cn/article-1770-1.html) 介绍了 vmstat 的部分参数，这里介绍另外一部分。以下数据来自 VPSee 的一个 256MB RAM，512MB SWAP 的 Xen VPS：

·········10········20········30········40········50········60········1.# vmstat 12.procs -----------memory---------- ---swap-- -----io---- --system-- -----cpu------3.r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st4.0  3 252696   2432    268   7148 3604 2368  3608  2372  288  288  0  0 21 78  15.0  2 253484   2216    228   7104 5368 2976  5372  3036  930  519  0  0  0 100  06.0  1 259252   2616    128   6148 19784 18712 19784 18712 3821 1853  0  1  3 95  17.1  2 260008   2188    144   6824 11824 2584 12664  2584 1347 1174 14  0  0 86  08.2  1 262140   2964    128   5852 24912 17304 24952 17304 4737 2341 86 10  0  0  4swpd，已使用的 SWAP 空间大小，KB 为单位；free，可用的物理内存大小，KB 为单位；buff，物理内存用来缓存读写操作的 buffer 大小，KB 为单位；cache，物理内存用来缓存进程地址空间的 cache 大小，KB 为单位；si，数据从 SWAP 读取到 RAM（swap in）的大小，KB 为单位；so，数据从 RAM 写到 SWAP（swap out）的大小，KB 为单位；bi，磁盘块从文件系统或 SWAP 读取到 RAM（blocks in）的大小，block 为单位；bo，磁盘块从 RAM 写到文件系统或 SWAP（blocks out）的大小，block 为单位；上面是一个频繁读写交换区的例子，可以观察到以下几点：

物理可用内存 free 基本没什么显著变化，swapd 逐步增加，说明最小可用的内存始终保持在 256MB X 10％ = 2.56MB 左右，当脏页达到10％的时候（vm.dirty_background_ratio ＝ 10）就开始大量使用 swap；buff 稳步减少说明系统知道内存不够了，kwapd 正在从 buff 那里借用部分内存；kswapd 持续把脏页面写到 swap 交换区（so），并且从 swapd 逐渐增加看出确实如此。根据上面讲的 kswapd 扫描时检查的三件事，如果页面被修改了，但不是被文件系统修改的，把页面写到 swap，所以这里 swapd 持续增加。via <http://www.vpsee.com/2009/11/linux-system-performance-monitoring-memory/> 





## 查看LINUX内存占用情况

### free

**CentOS 6及以前**

```
$ free
              total       used        free    shared    buffers    cached
Mem:        4040360    4012200       28160         0     176628   3571348
-/+ buffers/cache:      264224     3776136
Swap:       4200956      12184     4188772
$
```

**[CentOS 7](https://access.redhat.com/solutions/406773#)**

```
              total        used        free      shared  buff/cache   available
Mem:        1012952      252740      158732       11108      601480      543584
Swap:       1048572        5380     1043192
```

| 字段        | 含意                                       |
| :-------- | :--------------------------------------- |
| total     | 全部已安装内存（/proc/meminfo 中的 MemTotal 项）     |
| used      | 已用内存（全部计算 － 空间＋缓冲＋缓存）                    |
| free      | 未使用内存（/proc/meminfo 中的 MemFree 项）        |
| shared    | 主要被 tmpfs 使用的内存（/proc/meminfo 中的 Shmem 项） |
| buff      | 被内核缓冲使用的内存（/proc/meminfo 中的 Buffers 项）   |
| cache     | 被页面缓存和 slab 使用的内存（/proc/meminfo 中的 Cached 和 SSReclaimable 项） |
| available |                                          |

buff和cache是算作used还是算作free呢？一方面，它们已经被分配了可以算作used；另一方面，当程序需要时可以回收它们，可以算作free。

所以，怎么算都合理。**这就是老版free命令第一行和第二行的区别**：

- 第一行(Mem)：buff和cache被算作used。也就是说，它的used包含buffers和cached。
- 第二行(-/+ buffers/cache)：的含义就是把buffers/cache减下来，算作free。也就是说，它的used是指程序使用的；它的free包含buffers/cache；

另外，CentOS 7中加入了一个available，它是什么呢？手册上是这么说的：

> MemAvailable: An estimate of how much memory is available for starting new applications, without swapping.

前面说过，当程序需要时可以回收buff/cache，那么MemAvailabe不就是free+buff/cache吗？但是buff/cache中不是所有的内存都可以被回收。所以大致可以这么理解，**MemAvailable ＝ free + buff/cache - 不可回收的部分(共享内存段，tmpfs，ramfs等)**。

### ps

- 常用参数：
  - f 以树状结构显示
  - u 显示详细信息
  - a 显示所有进程
  - -A 显示所有进程
  - -u 用户名 是显示该用户下的进程
  - -l 更多进程详细信息

- 字段
  - sz：进程映像所占用的物理页面数量，也就是以物理页面为单位表示的虚拟内存大小；
  - rss：进程当前所占用的物理内存大小，单位为kB；
  - vsz：进程的虚拟内存大小，单位为kB，它等于sz乘于物理页面大小（x86平台通常为4kB）。 

如：

```
$ ps -e -o 'pid,comm,args,pcpu,rsz,vsz,stime,user,uid'  其中rsz是是实际内存
```

### top

常用的命令：

 　　P：按%CPU使用率排行
 　　T：按MITE+排行
 　　M：按%MEM排行

输出含义：

| 列名      | 含义                                       |
| :------ | :--------------------------------------- |
| PID     | 进程id                                     |
| PPID    | 父进程id                                    |
| RUSER   | Real user name                           |
| UID     | 进程所有者的用户id                               |
| USER    | 进程所有者的用户名                                |
| GROUP   | 进程所有者的组名                                 |
| TTY     | 启动进程的终端名。不是从终端启动的进程则显示为 ?                |
| PR      | 优先级                                      |
| NI      | nice值。负值表示高优先级，正值表示低优先级                  |
| P       | 最后使用的CPU，仅在多CPU环境下有意义                    |
| %CPU    | 上次更新到现在的CPU时间占用百分比                       |
| TIME    | 进程使用的CPU时间总计，单位秒                         |
| TIME+   | 进程使用的CPU时间总计，单位1/100秒                    |
| %MEM    | 进程使用的物理内存百分比                             |
| VIRT    | 进程使用的虚拟内存总量，单位kb。VIRT=SWAP+RES           |
| SWAP    | 进程使用的虚拟内存中，被换出的大小，单位kb。                  |
| RES     | 进程使用的、未被换出的物理内存大小，单位kb。RES=CODE+DATA     |
| CODE    | 可执行代码占用的物理内存大小，单位kb                      |
| DATA    | 可执行代码以外的部分(数据段+栈)占用的物理内存大小，单位kb          |
| SHR     | 共享内存大小，单位kb                              |
| nFLT    | 页面错误次数                                   |
| nDRT    | 最后一次写入到现在，被修改过的页面数。                      |
| S       | 进程状态。            D=不可中断的睡眠状态            R=运行            S=睡眠            T=跟踪/停止            Z=僵尸进程 |
| COMMAND | 命令名/命令行                                  |
| WCHAN   | 若该进程在睡眠，则显示睡眠中的系统函数名                     |
| Flags   | 任务标志，参考 sched.h                          |

### pmap

> pmap - report memory map of a process(查看进程的内存映像信息)

- 选项含义

​       -x   extended       Show the extended format. 显示扩展格式

​       -d   device         Show the device format.   显示设备格式

​       -q   quiet          Do not display some header/footer lines. 不显示头尾行

​       -V   show version   Displays version of program. 显示版本

- 扩展格式和设备格式域：

​        Address:  start address of map  映像起始地址

​        Kbytes:  size of map in kilobytes  映像大小

​        RSS:  resident set size in kilobytes  驻留集大小

​        Dirty:  dirty pages (both shared and private) in kilobytes  脏页大小

​        Mode:  permissions on map 映像权限: r=read, w=write, x=execute, s=shared, p=private (copy on write)  

​        Mapping:  file backing the map , or '[ anon ]' for allocated memory, or '[ stack ]' for the program stack.  映像支持文件,[anon]为已分配内存 [stack]为程序堆栈

​        Offset:  offset into the file  文件偏移

​        Device:  device name (major:minor)  设备名

```
# pmap -d 1
1:   /usr/lib/systemd/systemd --switched-root --system --deserialize 21
Address           Kbytes Mode  Offset           Device    Mapping
00007f3820000000     164 rw--- 0000000000000000 000:00000   [ anon ]
... ...
mapped: 125136K    writeable/private: 17772K    shared: 0K
```
最后一行的含意：

- mapped：表示该进程映射的虚拟地址空间大小，也就是该进程预先分配的虚拟内存大小，即ps出的vsz
- writeable/private：表示进程所占用的私有地址空间大小，也就是该进程实际使用的内存大小      
- shared: 表示进程和其他进程共享的内存大小


### /proc/<pid>/status & /proc/<pid>/smaps

通过/proc/<pid>/status可以查看进程的内存使用情况，包括虚拟内 存大小（VmSize），物理内存大小（VmRSS），数据段大小（VmData），栈的大小 （VmStk），代码段的大小（VmExe），共享库的代码段大小（VmLib）等等。

$ cat /proc/10069/status
Name:   a.out
State:  S (sleeping)
Tgid:   10069
Pid:    10069
PPid:   6793
TracerPid:      0
Uid:    1001    1001    1001    1001
Gid:    1001    1001    1001    1001
FDSize: 256
Groups: 1000 1001 
VmPeak:     1692 kB
VmSize:     1616 kB
VmLck:         0 kB
VmHWM:       304 kB
VmRSS:       304 kB
VmData:       28 kB
VmStk:        88 kB
VmExe:         4 kB
VmLib:      1464 kB
VmPTE:        20 kB
Threads:        1
SigQ:   0/16382
SigPnd: 0000000000000000
ShdPnd: 0000000000000000
SigBlk: 0000000000000000
SigIgn: 0000000000000000
SigCgt: 0000000000000000
CapInh: 0000000000000000
CapPrm: 0000000000000000
CapEff: 0000000000000000
CapBnd: ffffffffffffffff
Cpus_allowed:   f
Cpus_allowed_list:      0-3
Mems_allowed:   1
Mems_allowed_list:      0
voluntary_ctxt_switches:        1
nonvoluntary_ctxt_switches:     1


注意，VmData，VmStk，VmExe和VmLib之和并不等于VmSize。这是因为共享库函数的数 据段没有计算进去（VmData仅包含a.out程序的数据段，不包括共享库函数的数据段， 也不包括通过mmap映射的区域。VmLib仅包括共享库的代码段，不包括共享库的数据 段）。

通过/proc/<pid>/smaps可以查看进程整个虚拟地址空间的映射情况，它的输出从低地址到高地址按顺序输出每一个映射区域的相关信息，如下所示：

$ cat /proc/10069/smaps
00110000-00263000 r-xp 00000000 08:07 128311     /lib/tls/i686/cmov/libc-2.11.1.so
Size:               1356 kB
Rss:                 148 kB
Pss:                   8 kB
Shared_Clean:        148 kB
Shared_Dirty:          0 kB
Private_Clean:         0 kB
Private_Dirty:         0 kB
Referenced:          148 kB
Swap:                  0 kB
KernelPageSize:        4 kB
MMUPageSize:           4 kB
......
......
bfd7f000-bfd94000 rw-p 00000000 00:00 0          [stack]
Size:                 88 kB
Rss:                   8 kB
Pss:                   8 kB
Shared_Clean:          0 kB
Shared_Dirty:          0 kB
Private_Clean:         0 kB
Private_Dirty:         8 kB
Referenced:            8 kB
Swap:                  0 kB
KernelPageSize:        4 kB
MMUPageSize:           4 kB
注意：rwxp中，p表示私有映射（采用Copy-On-Write技术）。 Size字段就是该区域的大小。

 

## 使用mtrace检查内存溢出

Mtrace主要能够检测一些内存分配和泄漏的失败等。
使用mtrace来调试程序有4个基本的步骤，需要用到GNU C 函数库里面的一些辅助的函数功能。 

1. 在需要跟踪的程序中需要包含头文件<mcheck.h>，而且在main()函数的最开始包含一个函数调用：mtrace()。由于在 main函数的最开头调用了mtrace()，所以该进程后面的一切分配和释放内存的操作都可以由mtrace来跟踪和分析。

2. 定义一个环境变量，用来指示一个文件。该文件用来输出log信息。如下的例子： 
```
$export MALLOC_TRACE=mymemory.log 
```
3. 正常运行程序。此时程序中的关于内存分配和释放的操作都可以记录下来。 

4. 然后用mtrace使用工具来分析log文件。例如：
``` 
$mtrace testmem $MALLOC_TRACE 
```

示例: 
```
$ cat testmtrace.c 
#include <mcheck.h> 
#include <stdio.h> 
#include <stdlib.h> 

int main() 
{ 
char *hello; 
mtrace(); 
hello = (char*) malloc(20); 
sprintf(hello,"nhello world!"); 
return 1; 
} 
$export MALLOC_TRACE=mytrace.log 
$ gcc testmtrace.c -o testmtrace 
$./testmtrace 
$ mtrace testmtrace mytrace.log 

Memory not freed: 
----------------- 
Address Size Caller 
0x08049860 0x14 at /usr/src/build/53700-i386/BUILD/glibc-2.2.4/csu/init.c:0
```