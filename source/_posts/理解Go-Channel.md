---
title: 理解Go Channel
comments: true
date: 2018-06-14 08:14:30
time: 1528935270
tags:
categories: golang
---



Golang使用Groutine和Channel实现了CSP(Communicating Sequential Processes)模型。本文分析一下go channels的原理。

以一个简单的channel应用开始，使用goroutine和channel实现一个任务队列，并行处理多个任务。

```
func main(){
    //带缓冲的channel
    ch := make(chan Task, 3)

    //启动固定数量的worker
    for i := 0; i< numWorkers; i++ {
        go worker(ch)
    }

    //发送任务给worker
    hellaTasks := getTaks()

    for _, task := range hellaTasks {
        ch <- task
    }

    ...
}

func worker(ch chan Task){
    for {
       //接受任务
       task := <- ch
       process(task)
    }
}1234567891011121314151617181920212223242526
```

从上面的代码可以看出，使用golang的goroutine和channel可以很容易的实现一个生产者-消费者模式的任务队列，相比java, c++简洁了很多。channel可以天然的实现了下面四个特性： 
\- goroutine安全 
\- 在不同的goroutine之间存储和传输值 
\- 提供FIFO语义(buffered channel提供) 
\- 可以让goroutine block/unblock

那么channel是怎么实现这些特性的呢？下面我们看看当我们调用make来生成一个channel的时候都做了些什么。

## make chan

上述任务队列的例子第三行，使用make创建了一个长度为3的带缓冲的channel，channel在底层是一个hchan结构体，位于`src/runtime/chan.go`里。其定义如下:

```
type hchan struct {
    qcount   uint           // total data in the queue
    dataqsiz uint           // size of the circular queue
    buf      unsafe.Pointer // points to an array of dataqsiz elements
    elemsize uint16
    closed   uint32
    elemtype *_type // element type
    sendx    uint   // send index
    recvx    uint   // receive index
    recvq    waitq  // list of recv waiters
    sendq    waitq  // list of send waiters

    // lock protects all fields in hchan, as well as several
    // fields in sudogs blocked on this channel.
    //
    // Do not change another G's status while holding this lock
    // (in particular, do not ready a G), as this can deadlock
    // with stack shrinking.
    lock mutex
}1234567891011121314151617181920
```

make函数在创建channel的时候会在该进程的heap区申请一块内存，创建一个hchan结构体，返回执行该内存的指针，所以获取的的ch变量本身就是一个指针，在函数之间传递的时候是同一个channel。

hchan结构体使**用一个环形队列**来保存groutine之间传递的数据(如果是缓存channel的话)，使用**两个list**保存像该chan发送和从改chan接收数据的goroutine，还有一个mutex来保证操作这些结构的安全。

### 发送和接收

向channel发送和从channel接收数据主要涉及hchan里的四个成员变量，借用Kavya ppt里的图示，来分析发送和接收的过程。 
![hchan white ](http://7sbpmg.com1.z0.glb.clouddn.com/blog/images/hchan_white_gif.gif?imageView/0/w/600/) 
还是以前面的任务队列为例:

```
//G1
func main(){
    ...

    for _, task := range hellaTasks {
        ch <- task    //sender
    }

    ...
}

//G2
func worker(ch chan Task){
    for {
       //接受任务
       task := <- ch  //recevier
       process(task)
    }
}12345678910111213141516171819
```

其中G1是发送者，G2是接收，因为ch是长度为3的带缓冲channel，初始的时候hchan结构体的buf为空，sendx和recvx都为0，当G1向ch里发送数据的时候，会首先对buf加锁，然后将要发送的**数据copy到buf里**，并增加sendx的值，最后释放buf的锁。然后G2消费的时候首先对buf加锁，然后将buf里的**数据copy到task变量对应的内存里**，增加recvx，最后释放锁。整个过程，G1和G2没有共享的内存，底层通过hchan结构体的buf，使用copy内存的方式进行通信，最后达到了共享内存的目的，这完全符合CSP的设计理念

> Do not comminute by sharing memory;instead, share memory by communicating

一般情况下，G2的消费速度应该是慢于G1的，所以buf的数据会越来越多，这个时候G1再向ch里发送数据，这个时候G1就会阻塞，那么阻塞到底是发生了什么呢？

#### Goroutine Pause/Resume

goroutine是Golang实现的用户空间的轻量级的线程，有runtime调度器调度，与操作系统的thread有多对一的关系，相关的数据结构如下图: 
![img](http://7sbpmg.com1.z0.glb.clouddn.com/blog/images/schedule.png?imageView/0/w/600/)

其中M是操作系统的线程，G是用户启动的goroutine，P是与调度相关的context，每个M都拥有一个P，P维护了一个能够运行的goutine队列，用于该线程执行。

当G1向buf已经满了的ch发送数据的时候，当runtine检测到对应的hchan的buf已经满了，会通知调度器，调度器会将G1的状态设置为waiting, 移除与线程M的联系，然后从P的runqueue中选择一个goroutine在线程M中执行，此时G1就是阻塞状态，但是不是操作系统的线程阻塞，所以这个时候只用消耗少量的资源。

那么G1设置为waiting状态后去哪了？怎们去resume呢？我们再回到hchan结构体，注意到hchan有个sendq的成员，其类型是waitq，查看源码如下： 
`Go type hchan struct { ... recvq waitq // list of recv waiters sendq waitq // list of send waiters ... } // type waitq struct { first *sudog last *sudog } `

实际上，当G1变为waiting状态后，会创建一个代表自己的sudog的结构，然后放到sendq这个list中，sudog结构中保存了channel相关的变量的指针(如果该Goroutine是sender，那么保存的是待发送数据的变量的地址，如果是receiver则为接收数据的变量的地址，之所以是地址，前面我们提到在传输数据的时候使用的是copy的方式) 
![img](http://7sbpmg.com1.z0.glb.clouddn.com/blog/images/sendq.png?imageView/0/w/600/)

当G2从ch中接收一个数据时，会通知调度器，设置G1的状态为runnable，然后将加入P的runqueue里，等待线程执行. 
![img](http://7sbpmg.com1.z0.glb.clouddn.com/blog/images/G12Runnable.png?imageView/0/w/600/)

\### wait empty channel 
前面我们是假设G1先运行，如果G2先运行会怎么样呢？如果G2先运行，那么G2会从一个empty的channel里取数据，这个时候G2就会阻塞，和前面介绍的G1阻塞一样，G2也会创建一个sudog结构体，保存接收数据的变量的地址，但是该sudog结构体是放到了recvq列表里，当G1向ch发送数据的时候，**runtime并没有对hchan结构体题的buf进行加锁，而是直接将G1里的发送到ch的数据copy到了G2 sudog里对应的elem指向的内存地址！** 
![img](http://7sbpmg.com1.z0.glb.clouddn.com/blog/images/G2%20wait.png?imageView/0/w/600/)

------

### 参考资料

1. <https://speakerdeck.com/kavya719/understanding-channels>
2. <https://about.sourcegraph.com/go/understanding-channels-kavya-joshi>
3. <https://github.com/golang/go/blob/master/src/runtime/chan.go>
4. <https://github.com/golang/go/blob/master/src/runtime/runtime2.go>