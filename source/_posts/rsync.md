---
title: Linux shell 命令 rsync
comments: true
date: 2017-11-30 19:09:47
time: 1512040187
categories: shell
---

## 语法:

```
#rsysnc [options] source path destination path
```

## 示例1：启用压缩

```
[root@localhost /]# rsync -zvr /home/aloft/ /backuphomedirbuilding file list ... done.bash_logout.bash_profile.bashrcsent 472 bytes received 86 bytes 1116.00 bytes/sectotal size is 324 speedup is 0.58
```

上面的rsync命令使用了-z来启用压缩，-v是可视化，-r是递归。上面在本地的/home/aloft/和/backuphomedir之间同步。

## 示例2：保留文件和文件夹的属性

```
[root@localhost /]# rsync -azvr /home/aloft/ /backuphomedirbuilding file list ... done./.bash_logout.bash_profile.bashrc sent 514 bytes received 92 bytes 1212.00 bytes/sectotal size is 324 speedup is 0.53
```

上面我们使用了-a选项，它保留了所有人和所属组、时间戳、软链接、权限，并以递归模式运行。

## 示例3：同步本地到远程主机

```
root@localhost /]# rsync -avz /home/aloft/ azmath@192.168.1.4:192.168.1.4:/share/rsysnctest/Password: building file list ... done./.bash_logout.bash_profile.bashrcsent 514 bytes received 92 bytes 1212.00 bytes/sectotal size is 324 speedup is 0.53
```

上面的命令允许你在本地和远程机器之间同步。你可以看到，在同步文件到另一个系统时提示你输入密码。在做远程同步时，你需要指定远程系统的用户名和IP或者主机名。

## 示例4：远程同步到本地

```
[root@localhost /]# rsync -avz root@192.168.1.4:/rsysnc/ /home/share/
Password:
building file list ... done./.bash_logout.bash_profile.bashrcsent 514 bytes received 92 bytes 1212.00 bytes/sectotal size is 324 speedup is 0.53
```

上面的命令同步远程文件到本地。

## 示例5：找出文件间的不同

```
[root@localhost backuphomedir]# rsync -avzi /backuphomedir /home/aloft/building file list ... donecd+++++++ backuphomedir/>f+++++++ backuphomedir/.bash_logout>f+++++++ backuphomedir/.bash_profile>f+++++++ backuphomedir/.bashrc>f+++++++ backuphomedir/abc>f+++++++ backuphomedir/xyz sent 650 bytes received 136 bytes 1572.00 bytes/sectotal size is 324 speedup is 0.41
```

上面的命令帮助你找出源地址和目标地址之间文件或者目录的不同。

## 示例6: 备份

rsync命令可以用来备份linux。

你可以在cron中使用rsync安排备份。

```
0 0 * * * /usr/local/sbin/bkpscript &> /dev/null
```

------

```
vi /usr/local/sbin/bkpscript rsync -avz -e ‘ssh -p2093′ /home/test/ root@192.168.1.150:/oracle/data/
```