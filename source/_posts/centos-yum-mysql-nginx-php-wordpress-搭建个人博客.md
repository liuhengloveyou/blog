---
title: centos yum mysql nginx php wordpress 搭建个人网站
date: 2017-10-13 01:02:00
time: 1507866354
tags: wordpress
categories: wordpress
comments: true
---

## 创建用户

为web服务创业一个单独的用户 www，是一个好习惯。不需要登录，不需要家目录。

```shell
# useradd -M -U -s /sbin/nologin www
```

## 安装MySQL

互联网行业服务器用CentOS的比较多， 我们也同样。MySQL官方有提供YUM源，这肯定是最方便的安装方式了。下面我演示CentOS 6的安装方式， CentOS 7也是一样的：


1. 下载开源版的MySQL Yum Repository：
```shell
# wget https://dev.mysql.com/get/mysql57-community-release-el6-11.noarch.rpm
```

2. 安装MySQL Yum Repository
```shell
# rpm -ivh mysql57-community-release-el6-11.noarch.rpm
```
3. 安装MySQL
```shell
先更新一下YUM源
# yum update

安装MySQL服务器
# yum -y install mysql-community-server
```

## 配置&启动MySQL

安装是很方便的， 一般像上面几像命令就搞定了。下面我们把MySQL启动起来：

```shell
# service mysqld start
Initializing MySQL database:                               [  OK  ]
Starting mysqld:                                           [  OK  ]	
# service mysqld status
mysqld (pid  23715) is running...
```

设置成开机启动：

```shell
CentOS 6:
# chkconfig --add mysqld
# chkconfig mysqld on

CentOS 7:
# systemctl enable mysqld
# systemctl daemon-reload	
```

MySQL 5.7安装完成之后，会在/var/log/mysqld.log文件中打印生成的root默认密码。我们需要找到它，然后登录MySQL修改：

```shell
# grep 'temporary password' /var/log/mysqld.log
2017-10-12T08:30:06.572027Z 1 [Note] A temporary password is generated for root@localhost: x,&X,8)dGSoM

# mysql -uroot -p
Enter password:
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 5
Server version: 5.7.19

Copyright (c) 2000, 2017, Oracle and/or its affiliates. All rights reserved.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql> ALTER USER 'root'@'localhost' IDENTIFIED BY '123456';
ERROR 1819 (HY000): Your password does not satisfy the current policy requirements
mysql>
```

我们发现在改密码出错了。

> 这是因为 MySQL5.7默认安装了密码安全检查插件，默认密码检查策略要求密码必须包含：大小写字母、数字和特殊符号，并且长度不能少于8位。

如果想修改密码策略，在/etc/my.cnf文件 [mysqld] 部分添加validate_password_policy配置：

```
[mysqld]

# 选择0（LOW），1（MEDIUM），2（STRONG）其中一种，选择2需要提供密码字典文件
validate_password_policy=0
```

配置默认编码为utf8；修改/etc/my.cnf配置文件，在[mysqld]下添加编码配置，如下所示：

```
[mysqld]
character_set_server=utf8
init_connect='SET NAMES utf8'
```

重新启动mysql服务使配置生效：

```shell
CentOS 6
# service mysqld restart

CentOS 7
# systemctl restart mysqld
Stopping mysqld:                                           [  OK  ]
Starting mysqld:                                           [  OK  ]
```

然后再改密码就可以了：

```mysql
# mysql> ALTER USER 'root'@'localhost' IDENTIFIED BY '123456';
Query OK, 0 rows affected (0.00 sec)
```



## 安装nginx

nginx我习惯自己编译安装，这样比较好控制。再加上lua模块， 方便写逻辑、调度之类的。

1. 安装lua-jit和nginx依赖包：

```shell
# yum install luajit luajit-devel -y
# yum install pcre-devel openssl-devel -y
```

2. 下载最新Stable版nginx, 现在是1.12.1。和lua模块依赖包：

```shell
# wget http://nginx.org/download/nginx-1.12.1.tar.gz
# tar xvf nginx-1.12.1.tar.gz

# wget https://github.com/simpl/ngx_devel_kit/archive/v0.3.0.tar.gz
# tar xvf v0.3.0.tar.gz

# wget https://github.com/openresty/lua-nginx-module/archive/v0.10.10.tar.gz
# tar xvf v0.10.10.tar.gz

# cd nginx-1.12.1
# ./configure --with-debug --with-threads --with-http_ssl_module --with-http_v2_module --with-http_mp4_module --with-http_flv_module --prefix=/opt/nginx --with-ld-opt=-Wl,-rpath,/usr/local/lib/ --add-module=../ngx_devel_kit-0.3.0/ --add-module=../lua-nginx-module-0.10.10/
# make -j 8
# make install
```

3. 没什么意外的话，nginx已经成功安装在了 /opt/nginx 目录下：

```shell
# cd /opt/nginx/
# ./sbin/nginx -t
nginx: the configuration file /opt/nginx/conf/nginx.conf syntax is ok
nginx: configuration file /opt/nginx/conf/nginx.conf test is successful
```

## 安装php

```shell
# yum install -y php php-dev php-fpm php-mysql php-gd php-imap php-ldap php-odbc php-pear php-xml php-xmlrpc
```

启动php-fpm：

```shell
CentOS 6
# service php-fpm start
Starting php-fpm:                                          [  OK  ]

CentOS 7
systemctl start php-fpm
```

## 测试php

修改nginx配置，添加处理php的location。完整的nginx配置如下：

```nginx
# cat /opt/nginx/conf/nginx.conf

user  www www;
worker_processes  4;
worker_rlimit_nofile 65535;

#error_log  logs/error.log;
#error_log  logs/error.log  notice;
#error_log  logs/error.log  info;

#pid        logs/nginx.pid;

events {
    use epoll;
    worker_connections  65535;
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    log_format  main  '$time_iso8601 $server_name $remote_addr "$request" '
                      '$status $body_bytes_sent $request_time "$http_referer" 
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  logs/access.log  main;

    aio                      threads;
    sendfile                 on;
    sendfile_max_chunk       512k;
    output_buffers           1 256k;
    tcp_nopush               on;
    tcp_nodelay              off;
    keepalive_timeout        75;
    server_tokens            off;
    client_max_body_size     0;
    client_body_buffer_size  100m;

    proxy_buffering          on;
    proxy_buffer_size        8k;
    proxy_buffers            8 8k;
    proxy_busy_buffers_size  32k;
    proxy_max_temp_file_size 0;

    proxy_http_version        1.1;
    proxy_redirect            off;
    proxy_force_ranges        on;
    proxy_next_upstream       error timeout http_500 http_502 http_503 http_504;
    proxy_next_upstream_tries 5;
    proxy_intercept_errors on;

    ssl_session_cache   shared:SSL:50m;
    ssl_session_timeout 10m;

    recursive_error_pages on;
    gzip  on;

    lua_package_path "/opt/nginx/lua/?.lua;./lua/?.lua;;";

    server {
		listen       80;
        server_name  www.sixianed.com sixianed.com;

		rewrite ^/(.*) https://$server_name/$1$is_args$args;
    }

    # HTTPS server
    server {
        listen       443 http2;
        server_name  www.sixianed.com sixianed.com;

		ssl on;
		ssl_certificate      cert/sixianed.com.pem;
		ssl_certificate_key  cert/sixianed.com.key;
		ssl_session_timeout 5m;
		ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4;
		ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
		ssl_prefer_server_ciphers on;

        proxy_http_version 1.1;

		location / {
            root   html/wordpress;
            index  index.html index.htm index.php;
        }

		location ~ \.php$ {
			root html/wordpress;

    		fastcgi_pass   127.0.0.1:9000;
    		fastcgi_index  index.php;
    		fastcgi_param  SCRIPT_FILENAME  $document_root$fastcgi_script_name;
    		include        fastcgi_params;
		}

		error_page   500 502 503 504  /50x.html;
      	location = /50x.html {
            root   html;
        }
    }
}
```

然后在 /opt/nginx/html/wordpress 目录下创建一个t.php文件：

```shell
# mkdir html/wordpress
# vim html/wordpress/t.php

内容为：
<?php
phpinfo();
```

重启nginx：

```shell
# ./sbin/nginx -s reload
```

访问http://127.0.0.1/t.php， 如果能看到php的信息页面。就说明php已经安装成功了。

## 安装WordPress

1. 下载WordPress中文版最新版：

```shell
# cd html/wordpress/
# wget https://cn.wordpress.org/wordpress-4.8.1-zh_CN.zip
```

2. 解压放到 /opt/nginx/html/wordpress 目录下：

```shell
# unzip wordpress-4.8.1-zh_CN.zip
# mv wordpress/* .
# rm wordpress* -rf
```

3. 创建WordPress数据库

```sql
# mysql -uroot -p
Enter password:
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 5
Server version: 5.7.19 MySQL Community Server (GPL)

Copyright (c) 2000, 2017, Oracle and/or its affiliates. All rights reserved.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql> CREATE DATABASE wordpress;
Query OK, 1 row affected (0.00 sec)

mysql> GRANT ALL PRIVILEGES ON wordpress.* TO "root"@"localhost" IDENTIFIED BY "123456";
Query OK, 0 rows affected, 1 warning (0.00 sec)

mysql> FLUSH PRIVILEGES;
Query OK, 0 rows affected (0.00 sec)

mysql> exit
Bye
#
```

4. 运行安装脚本

- 将WordPress文件放在根目路径的用户请访问：`http://127.0.0.1/wp-admin/install.php`
- 将WordPress文件放在非根路径下的（假设子路径为blog）下的用户请访问：`http://example.com/blog/wp-admin/install.php`

5. 安装配置文件

   WordPress无法查找到`wp-config.php`文件时会通知用户并试图自动创建并编辑wp-config.php文件。（用户可以在web浏览器中加载`wp-admin/setup-config.php`以新建wp-config.php文件）WordPress询问用户数据库的具体情况并将之写入新的`wp-config.php`文件。如果新文件创建成功，用户可以继续安装。

6. 完成安装

   WordPress配置成功以后， 会显示欢迎页面。并让输入站点名和用户信息。设置好这些，自己的BLOG就安装成功啦。。。
