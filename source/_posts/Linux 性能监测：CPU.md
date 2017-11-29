---
title: Linux 性能监测：CPU
date: 2017-10-13 11:45:45
time: 1507866362
tags:
	- linux
	- CPU
categories: Linux性能调优
comments: true
---

CPU 的占用主要取决于什么样的资源正在 CPU 上面运行，比如拷贝一个文件通常占用较少 CPU，因为大部分工作是由 DMA（Direct Memory Access）完成，只是在完成拷贝以后给一个中断让 CPU 知道拷贝已经完成；科学计算通常占用较多的 CPU，大部分计算工作都需要在 CPU 上完成，内存、硬盘等子系统只做暂时的数据存储工作。要想监测和理解 CPU 的性能需要知道一些操作系统的基本知识，比如：中断、进程调度、进程上下文切换、可运行队列等。这里 VPSee 用个例子来简单介绍一下这些概念和他们的关系，CPU 很无辜，是个任劳任怨的打工仔，每时每刻都有工作在做（进程、线程）并且自己有一张工作清单（可运行队列），由老板（进程调度）来决定他该干什么，他需要和老板沟通以便得到老板的想法并及时调整自己的工作（上下文切换），部分工作做完以后还需要及时向老板汇报（中断），所以打工仔（CPU）除了做自己该做的工作以外，还有大量时间和精力花在沟通和汇报上。

CPU 也是一种硬件资源，和任何其他硬件设备一样也需要驱动和管理程序才能使用，我们可以把内核的进程调度看作是 CPU 的管理程序，用来管理和分配 CPU 资源，合理安排进程抢占 CPU，并决定哪个进程该使用 CPU、哪个进程该等待。操作系统内核里的进程调度主要用来调度两类资源：进程（或线程）和中断，进程调度给不同的资源分配了不同的优先级，优先级最高的是硬件中断，其次是内核（系统）进程，最后是用户进程。每个 CPU 都维护着一个可运行队列，用来存放那些可运行的线程。线程要么在睡眠状态（blocked 正在等待 IO）要么在可运行状态，如果 CPU 当前负载太高而新的请求不断，就会出现进程调度暂时应付不过来的情况，这个时候就不得不把线程暂时放到可运行队列里。VPSee 在这里要讨论的是性能监测，上面谈了一堆都没提到性能，那么这些概念和性能监测有什么关系呢？关系重大。如果你是老板，你如何检查打工仔的效率（性能）呢？我们一般会通过以下这些信息来判断打工仔是否偷懒：

- 打工仔接受和完成多少任务并向老板汇报了（中断）；
- 打工仔和老板沟通、协商每项工作的工作进度（上下文切换）；
- 打工仔的工作列表是不是都有排满（可运行队列）；
- 打工仔工作效率如何，是不是在偷懒（CPU 利用率）。

现在把打工仔换成 CPU，我们可以通过查看这些重要参数：中断、上下文切换、可运行队列、CPU 利用率来监测 CPU 的性能。

## Linux 系统上检测 CPU 信息

### /proc/cpuinfo虚拟文件
```
# cat /proc/cpuinfo
processor	: 0
vendor_id	: GenuineIntel
cpu family	: 6
model		: 79
model name	: Intel(R) Xeon(R) CPU E5-2682 v4 @ 2.50GHz
stepping	: 1
microcode	: 0x1
cpu MHz		: 2494.224
cache size	: 40960 KB
physical id	: 0
siblings	: 1
core id		: 0
cpu cores	: 1
apicid		: 0
initial apicid	: 0
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush mmx fxsr sse sse2 ss syscall nx pdpe1gb rdtscp lm constant_tsc rep_good nopl eagerfpu pni pclmulqdq ssse3 fma cx16 pcid sse4_1 sse4_2 x2apic movbe popcnt tsc_deadline_timer aes xsave avx f16c rdrand hypervisor lahf_lm abm 3dnowprefetch fsgsbase tsc_adjust bmi1 hle avx2 smep bmi2 erms invpcid rtm rdseed adx smap xsaveopt
bogomips	: 4988.44
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:
```

### cpufreq-info

cpufreq-info命令(cpufrequtils包的一部分)从内核/硬件中收集并报告CPU频率信息。这条命令展示了CPU当前运行的硬件频率，包括CPU所允许的最小/最大频率、CPUfreq策略/统计数据等等。

### cpuid

cpuid命令的功能就相当于一个专用的CPU信息工具，它能通过使用CPUID功能来显示详细的关于CPU硬件的信息。信息报告包括处理器类型/家族、CPU扩展指令集、缓存/TLB（译者注：传输后备缓冲器）配置、电源管理功能等等。

```
# cpuid | more
Disclaimer: cpuid may not support decoding of all cpuid registers.
CPU 0:
   vendor_id = "GenuineIntel"
   version information (1/eax):
      processor type  = primary processor (0)
      family          = Intel Pentium Pro/II/III/Celeron/Core/Core 2/Atom, AMD Athlon/Duron, Cyrix M2, VIA C3 (6)
      model           = 0xf (15)
      stepping id     = 0x1 (1)
      extended family = 0x0 (0)
      extended model  = 0x4 (4)
      (simple synth)  = Intel Xeon (Broadwell), 14nm
   miscellaneous (1/ebx):
      process local APIC physical ID = 0x0 (0)
      cpu count                      = 0x0 (0)
      CLFLUSH line size              = 0x8 (8)
      brand index                    = 0x0 (0)
   brand id = 0x00 (0): unknown
   feature information (1/edx):
      x87 FPU on chip                        = true
      virtual-8086 mode enhancement          = true
      debugging extensions                   = true
... ...
```

### dmidecode

>dmidecode命令直接从BIOS的DMI（桌面管理接口）数据收集关于系统硬件的具体信息。CPU信息报告包括CPU供应商、版本、CPU标志寄存器、最大/当前的时钟速度、(启用的)核心总数、L1/L2/L3缓存配置等等。

```
# dmidecode
# dmidecode 3.0
Scanning /dev/mem for entry point.
SMBIOS 2.8 present.
9 structures occupying 482 bytes.
Table at 0x000F0C90.

... ...

Handle 0x0400, DMI type 4, 42 bytes
Processor Information
	Socket Designation: CPU 0
	Type: Central Processor
	Family: Other
	Manufacturer: Alibaba Cloud
	ID: F1 06 04 00 FF FB 8B 0F
	Version: pc-i440fx-2.1
	Voltage: Unknown
	External Clock: Unknown
	Max Speed: Unknown
	Current Speed: Unknown
	Status: Populated, Enabled
	Upgrade: Other
	L1 Cache Handle: Not Provided
	L2 Cache Handle: Not Provided
	L3 Cache Handle: Not Provided
	Serial Number: Not Specified
	Asset Tag: Not Specified
	Part Number: Not Specified
	Core Count: 1
	Core Enabled: 1
	Thread Count: 1
	Characteristics: None
... ...
```




## 底线

监测 CPU 性能的底线是什么呢？通常我们期望我们的系统能到达以下目标：

- CPU 利用率，如果 CPU 有 100％ 利用率，那么应该到达这样一个平衡：65％－70％ User Time，30％－35％ System Time，0％－5％ Idle Time；
- 上下文切换，上下文切换应该和 CPU 利用率联系起来看，如果能保持上面的 CPU 利用率平衡，大量的上下文切换是可以接受的；
- 可运行队列，每个可运行队列不应该超过3个线程（每处理器），比如：双处理器系统的可运行队列里不应该超过6个线程。

## vmstat

vmstat 是个查看系统整体性能的小工具，小巧、即使在很 heavy 的情况下也运行良好，并且可以用时间间隔采集得到连续的性能数据。

```shell
$ vmstat 1
procs -----------memory---------- ---swap-- -----io---- --system-- -----cpu------
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
 2  1    140 2787980 336304 3531996  0    0     0   128 1166 5033  3  3 70 25  0
 0  1    140 2788296 336304 3531996  0    0     0     0 1194 5605  3  3 69 25  0
 0  1    140 2788436 336304 3531996  0    0     0     0 1249 8036  5  4 67 25  0
 0  1    140 2782688 336304 3531996  0    0     0     0 1333 7792  6  6 64 25  0
 3  1    140 2779292 336304 3531992  0    0     0    28 1323 7087  4  5 67 25  0
```

参数介绍：

- r，可运行队列的线程数，这些线程都是可运行状态，只不过 CPU 暂时不可用；
- b，被 blocked 的进程数，正在等待 IO 请求；
- in，被处理过的中断数
- cs，系统上正在做上下文切换的数目
- us，用户占用 CPU 的百分比
- sy，内核和中断占用 CPU 的百分比
- wa，所有可运行的线程被 blocked 以后都在等待 IO，这时候 CPU 空闲的百分比
- id，CPU 完全空闲的百分比

举两个现实中的例子来实际分析一下：

```
$ vmstat 1
procs -----------memory---------- ---swap-- -----io---- --system-- -----cpu------
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
 4  0    140 2915476 341288 3951700  0    0     0     0 1057  523 19 81  0  0  0
 4  0    140 2915724 341296 3951700  0    0     0     0 1048  546 19 81  0  0  0
 4  0    140 2915848 341296 3951700  0    0     0     0 1044  514 18 82  0  0  0
 4  0    140 2915848 341296 3951700  0    0     0    24 1044  564 20 80  0  0  0
 4  0    140 2915848 341296 3951700  0    0     0     0 1060  546 18 82  0  0  0
```

从上面的数据可以看出几点：

1. interrupts（in）非常高，context switch（cs）比较低，说明这个 CPU 一直在不停的请求资源；
2. system time（sy）一直保持在 80％ 以上，而且上下文切换较低（cs），说明某个进程可能一直霸占着 CPU（不断请求资源）；
3. run queue（r）刚好在4个。

```
$ vmstat 1
procs -----------memory---------- ---swap-- -----io---- --system-- -----cpu------
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
14  0    140 2904316 341912 3952308  0    0     0   460 1106 9593 36 64  1  0  0
17  0    140 2903492 341912 3951780  0    0     0     0 1037 9614 35 65  1  0  0
20  0    140 2902016 341912 3952000  0    0     0     0 1046 9739 35 64  1  0  0
17  0    140 2903904 341912 3951888  0    0     0    76 1044 9879 37 63  0  0  0
16  0    140 2904580 341912 3952108  0    0     0     0 1055 9808 34 65  1  0  0
```

从上面的数据可以看出几点：

1. context switch（cs）比 interrupts（in）要高得多，说明内核不得不来回切换进程；
2. 进一步观察发现 system time（sy）很高而 user time（us）很低，而且加上高频度的上下文切换（cs），说明正在运行的应用程序调用了大量的系统调用（system call）；
3. run queue（r）在14个线程以上，按照这个测试机器的硬件配置（四核），应该保持在12个以内。

## mpstat

mpstat 和 vmstat 类似，不同的是 mpstat 可以输出多个处理器的数据，下面的输出显示 CPU1 和 CPU2 基本上没有派上用场，系统有足够的能力处理更多的任务。

```
$ mpstat -P ALL 1
Linux 2.6.18-164.el5 (vpsee) 	11/13/2009

02:24:33 PM  CPU   %user   %nice    %sys %iowait    %irq   %soft  %steal   %idle    intr/s
02:24:34 PM  all    5.26    0.00    4.01   25.06    0.00    0.00    0.00   65.66   1446.00
02:24:34 PM    0    7.00    0.00    8.00    0.00    0.00    0.00    0.00   85.00   1001.00
02:24:34 PM    1   13.00    0.00    8.00    0.00    0.00    0.00    0.00   79.00    444.00
02:24:34 PM    2    0.00    0.00    0.00  100.00    0.00    0.00    0.00    0.00      0.00
02:24:34 PM    3    0.99    0.00    0.99    0.00    0.00    0.00    0.00   98.02      0.00
```

## ps

如何查看某个进程占用了多少 CPU 资源呢？下面是 Firefox 在一台服务器上的运行情况:

```
$ while :; do ps -eo pid,ni,pri,pcpu,psr,comm | grep 'firefox'; sleep 1; done

  PID  NI PRI %CPU PSR COMMAND
 7252   0  24  3.2   3 firefox
 9846   0  24  8.8   0 firefox
```

## 进程被调度到哪个CPU核（或 NUMA 节点）上运行?

这里有几种方法可以 找出哪个 CPU 内核被调度来运行指定的 Linux 进程或线程：

### taskset

> 如果一个进程使用 taskset 命令明确的被固定（pinned）到 CPU 的特定内核上，你可以使用 taskset 命令找出被固定的 CPU 内核。

例如, 对 PID 16880 这个进程有兴趣：

```
# taskset -c -p 16880
pid 16880's current affinity list: 0
```

输出显示这个过程被固定在 CPU 内核 0上。

但是，如果你没有明确固定进程到任何 CPU 内核，你会得到类似下面的亲和力列表。

```
pid 5357's current affinity list: 0-11
```

输出表明该进程可能会被安排在从0到11中的任何一个 CPU 内核。在这种情况下，taskset 不能识别该进程当前被分配给哪个 CPU 内核。

你应该使用如下所述的方法：

### ps 

命令可以告诉你每个进程/线程目前分配到的（在“PSR”列）CPU ID。

```
$ ps -o pid,psr,comm -p <pid> PID PSR COMMAND
   5357 10 prog
```
输出表示进程的 PID 为 5357（名为"prog"）目前在CPU 内核 10 上运行着。如果该过程没有被固定，PSR 列会根据内核可能调度该进程到不同内核而改变显示。

### top

命令也可以显示 CPU 被分配给哪个进程。首先，在top 命令中使用“P”选项。然后按“f”键，显示中会出现 "Last used CPU" 列。目前使用的 CPU 内核将出现在 “P”（或“PSR”）列下。

```
$ top -p 5357
```
相比于 ps 命令，使用 top 命令的好处是，你可以连续监视随着时间的改变， CPU 是如何分配的。
