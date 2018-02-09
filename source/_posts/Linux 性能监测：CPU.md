---
title: Linux 性能监测：CPU
date: 2017-10-13 11:45:45
time: 1507866362
tags:
	- linux
	- CPU
categories: 性能调优
comments: true
---

## 理解CPU性能

CPU 的占用主要取决于什么样的资源正在 CPU 上面运行，比如拷贝一个文件通常占用较少 CPU，因为大部分工作是由 DMA（Direct Memory Access）完成，只是在完成拷贝以后给一个中断让 CPU 知道拷贝已经完成；科学计算通常占用较多的 CPU，大部分计算工作都需要在 CPU 上完成，内存、硬盘等子系统只做暂时的数据存储工作。

要想监测和理解 CPU 的性能需要理解Linux内核是怎样工作的，每个CPU相关的指标代表什么意义。比如：中断、进程调度、进程上下文切换、可运行队列等。

CPU 每时每刻都有工作在做（进程、线程）并且自己有一张工作清单（可运行队列），由linux（进程调度）来决定他该干什么，它需要及时调整自己的工作（上下文切换），部分工作做完以后还需要汇报（中断），所以CPU除了做自己该做的工作以外，还有大量时间和精力花在上下文切换和中断上。

CPU 也是一种硬件资源，和任何其他硬件设备一样也需要驱动和管理程序才能使用，我们可以把内核的进程调度看作是 CPU 的管理程序，用来管理和分配 CPU 资源，合理安排进程抢占 CPU，并决定哪个进程该使用 CPU、哪个进程该等待。

操作系统内核里的进程调度主要用来调度两类资源：进程（或线程）和中断，进程调度给不同的资源分配了不同的优先级，优先级最高的是硬件中断，其次是内核（系统）进程，最后是用户进程。每个 CPU 都维护着一个可运行队列，用来存放那些可运行的线程。线程要么在睡眠状态（blocked 正在等待 IO）要么在可运行状态，如果 CPU 当前负载太高而新的请求不断，就会出现进程调度暂时应付不过来的情况，这个时候就不得不把线程暂时放到可运行队列里。

我们一般会通过以下这些信息来判断CPU工作是否饱和：

- CPU完成多少任务并汇报（中断）。
- CPU和内核沟通、协商每项工作的工作进度（上下文切换）。
- CPU工作列表是不是排满（可运行队列）。
- CPU工作效率如何，是否饱和（CPU 利用率）。

现在我们看一下每一项指标的具体意义：

- **Load average**
  Load average不是CPU百分比，它是以下数值加和的平均值：

  - CPU运行队列中等待执行的进程数
  - 等待不可中断任务执行完成的进程数

  也就是TASK_RUNNING和TASK_UNINTERRUPTIBLE之和的平均值。如果请求CPU处理的进程发生阻塞(意味着CPU没有空闲时间去执行该进程)，Load average将会上升。相反如果每个进程都可以立即执行，而且没有空转的CPU周期，那Load average将会降低。

- **CPU Utilisation**

  即CPU使用率；又包括：

  - User Time - 用户时间。描述CPU耗费在用户进程上的百分比，包括Nice time。如果User Time值很高，则表明系统正在执行实际的工作。

    - System Time - 系统时间。描述CPU耗费在内核操作上的CPU百分比，包括硬中断(IRQ)和软中断(SoftIRQ)。System Time值持续很高表明网络或驱动程序栈可能存在瓶颈。性能良好的系统应当耗费尽量少的时间在内核操作上。
    - Waiting - 等待时间。描述CPU在等待I/O操作所耗费的时间总和，与阻塞(Blocked)指标相似，系统不应该耗费太多的时间在等待I/O操作；否则你应该检查一下各个I/O子系统的性能。
    - Idle time - 空闲时间。描述CPU等待任务到达的时间百分比，即CPU空闲时间。
    - Nice time - Nice时间。描述CPU耗费在进程re-nicing的百分比，re-nicing指的是改变进程的执行顺序和优先级。



- **Run Queue**

  每个CPU核有一个运行时队列，在CPU为进程提供服务时，进程需要首先进入运行时队列等待CPU分配CPU时间。运行队列里包括可运行的进程(Runnable process)和被阻挡的进程(Blocked process)。Linux的scheduler根据进程的优先级决定哪个Runnable process运行。Blocked process不会竞争CPU时间。

  对应 vmstat的r 和  b列：

  ```shell
  # vmstat
  procs -----------memory---------- ---swap-- -----io---- --system-- -----cpu-----
   r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
   0  0 146112 5629756 233504 1147752    0    0     0     1    0    0  0  0 100  0  0
  ```

  - Runable processes 描述准备执行的进程数。在一段持续的时间内Runable processes不应该超过CPU数量的10倍，否则CPU可能存在性能瓶颈。

  - Blocked process 描述因等待I/O操作完成而挂起的进程数，Blocked指标往往意味着I/O存在性能瓶颈。

- **Process Switches**

  在多任务操作系统中，Linux内核不断在不同进程之间进行上下文切换，这种上下文切换需要CPU保存旧进程的上下文信息以及检索上下文信息给新进程，因此上下文切换对CPU的性能代价是很高的。减少上下文切换带来的性能问题最好的方法是减少上下文切换的次数，在多核CPU架构中可以实现，但是需要确保进程被锁定在指定CPU核上来阻止上下文切换。

  Linux进程调度器并不是进程发生上下文切换的唯一原因。另一个导致上下文切换发生的原因是硬件中断(hardware interrupts)。进程调度器使用时钟中断(timer interrupt)保证每个进程能获取公平的CPU时间。正常情况下上下文切换的次数应该小于时钟中断的次数，如果发现上下文切换次数比时钟中断次数多，这种负载可能是由系统需要处理很多I/O或者长时间高强度系统调用引起。

  因此了解时钟中断和上下文切换的关系对找到引起系统性能问题的原因提供线索。使用`vmstat -s`可以查看系统上下文切换和时钟中断次数:

  ```shell
  # vmstat -s
        8019652  total memory
        2390456  used memory
         753284  active memory
        1298864  inactive memory
        5629196  free memory
         233972  buffer memory
        1147932  swap cache
        8388600  total swap
         146112  used swap
        8242488  free swap
       15527099 non-nice user cpu ticks
           4099 nice user cpu ticks
       11994039 system cpu ticks
    25334146104 idle cpu ticks
       16419603 IO-wait cpu ticks
             82 IRQ cpu ticks
         191529 softirq cpu ticks
              0 stolen cpu ticks
         709480 pages paged in
      283599448 pages paged out
           2255 pages swapped in
          41291 pages swapped out
      210312138 interrupts
     3961975132 CPU context switches
     1484542215 boot time
      175248677 forks
  ```

- **Interrupts**
  Interrupts包括硬中断(hard interrupts)和软中断(soft interrupts)。hard interrupts会对系统性能产生非常不利的影响。Interrupts过高意味着应用程序存在性能瓶颈，可能在内核或者驱动中。 Interrupts也包括CPU时钟产生的中断。

## 底线

监测 CPU 性能的底线是什么呢？通常我们期望我们的系统能到达以下目标：

- CPU 利用率；如果 CPU 有 100％ 利用率，那么应该到达这样一个平衡：

  65％－70％ User Time，30％－35％ System Time，0％－5％ Idle Time；

- 上下文切换；上下文切换应该和 CPU 利用率联系起来看，如果能保持上面的 CPU 利用率平衡，大量的上下文切换是可以接受的；

- 可运行队列；每个可运行队列不应该超过3个线程（每处理器），比如：双处理器系统的可运行队列里不应该超过6个线程。

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

## vmstat

vmstat 是个查看系统整体性能的小工具，小巧、即使在很 heavy 的情况下也运行良好，并且可以用时间间隔采集得到连续的性能数据。

```shell

```

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

```