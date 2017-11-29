---
title: nginx 数据结构
date: 2017-10-13 12:17:44
time: 1507866367
tags: nginx
categories: nginx
comments: true
---

## ngx_buf_t

```c
typedef struct ngx_buf_s    ngx_buf_t;
typedef void  *ngx_buf_tag_t;
struct ngx_buf_s {
    /*
     * pos通常是用来告诉使用者本次应该从pos这个位置开始处理内存中的数据，这样设置是因为同一个
     * ngx_buf_t可能被多次反复处理。当然，pos的含义是由使用它的模板定义的
     */
    u_char  *pos;
                               
    /* last通常表示有效的内容到此为止，注意，pos与last之间的内存是希望nginx处理的内容 */
    u_char  *last;
                               
    /*
     * 处理文件时，file_pos与file_last的含义与处理内存时的pos与last相同，
     * file_pos表示将要处理的文件位置，file_last表示截至的文件位置。
     */
    off_t   file_pos;
    off_t   file_last;
                               
    /* 如果ngx_buf_t缓冲区用于内存，那么start指向这段内存的起始地址 */
    u_char  *start;
                               
    /* 与start成员对应，指向缓冲区内存的末尾 */
    u_char  *end;
                               
    /* 表示当前缓冲区的类型，例如由哪个模块使用就指向这个模块ngx_module_t变量的地址*/
    ngx_buf_tag_t  tag;
                               
    /* 引用的文件 */
    ngx_file_t  *file;
                               
    /*
     * 当前缓冲区的影子缓冲区，该成员很少用到。当缓冲区转发上游服务器的响应时才使用了shadow成员，
     * 这是因为nginx太节约内存了，分配一块内存并使用ngx_buf_t表示接收到的上游服务器响应后，
     * 在向下游客户端转发时可能会把这块内存存储到文件中，也可能直接向下游发送，此时nginx绝对不会
     * 重新复制一份内存用于新的目的，而是再次建立一个ngx_buf_t结构体指向原内存，这样多个ngx_buf_t
     * 结构体指向了同一份内存，它们之间的关系就通过shadow成员来引用，一般不建议使用。
     */
    ngx_buf_t   *shadow;
                               
    /* 临时内存标志位，为1时表示数据在内存中且这段内存可以修改 */
    unsigned    temporay:1;
                               
    /* 标志位，为1时表示数据在内存中且这段内存不可以修改 */
    unsigned    memory:1;
                               
    /* 标志位，为1时表示这段内存是用nmap系统调用映射过来的，不可以修改 */
    unsigned    mmap:1;
                               
    /* 标志位，为1时表示可回收 */
    unsigned    recycled:1;
                               
    /* 标志位，为1时表示这段缓冲区处理的是文件而不是内存 */
    unsigned    in_file:1;
                               
    /* 标志位，为1时表示需要执行flush操作 */
    unsigned    flush:1;
                               
    /*
     * 标志位，对于操作这块缓冲区时是否使用同步方式，需谨慎考虑，这可能会阻塞nginx进程，nginx中所有
     * 操作几乎都是异步的，这是它支持高并发的关键。有些框架代码在sync为1时可能会有阻塞的方式进行I/O
     * 操作，它的意义视使用它的nginx模块而定。
     */
    unsigned    sync:1;
                               
    /*
     * 标志位，表示是否是最后一块缓冲区，因为ngx_buf_t可以由ngx_chain_t链表串联起来，因此为1时，
     * 表示当前是最后一块待处理的缓冲区。   
     */
    unsigned    last_buf:1;
                               
    /* 标志位，表示是否是ngx_chain_t中的最后一块缓冲区 */
    unsigned    last_in_chain:1;
                               
    /* 标志位，表示是否是最后一个影子缓冲区，与shadow域配合使用。通常不建议使用它 */
    unsigned    last_shadow:1;
                               
    /* 标志位，表示当前缓冲区是否属于临时文件 */
    unsigned    temp_file:1;
}
```

