---
title: hexo url中文问题
comments: true
date: 2017-10-24 18:01:22
time: 1507866358
tags:
	- seo
	- hexo
categories: hexo
---



URL中包含中文， 不利于百度收录。百度不收录，那文章就会少人看到。写了文章当然还是希望有人看到，并有所帮助的。

hexo默认的配置， 文章的URL像是这样的：

```
https://www.sixianed.com/2017/10/24/hexo-node-sass问题解决/
```

因为它用了文章的title。作为中国人写文章， 标题里有中文再正常不过了。

如果想URL里没有中文， 可以如下配置：

```yaml
# URL
## If your site is put in a subdirectory, set url as 'http://yoursite.com/child' and root as '/child/'
url: https://www.sixianed.com
root: /
permalink: :year/:month/:day/:id.html
permalink_defaults: en
```


PS: 其实这也不是最好的办法。。。本BLOG最终也没用这个配置。