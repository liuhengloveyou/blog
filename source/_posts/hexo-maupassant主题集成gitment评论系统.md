---
title: hexo maupassant主题集成gitment评论系统
date: 2017-10-13 11:58:25
time: 1507866356
tags:
	- hexo
	- maupassant
	- gitment
categories: hexo
comments: true
---

## 简介

本文介绍hexo [maupassant](https://github.com/tufu9441/maupassant-hexo.git)集成giment评论系统的过程。
gitment是把评论放到github的issues系统里，评论支持md，比较适合程序员。

### 注册OAuth Application
首先要有github账号。登录github以后点击https://github.com/settings/applications/new 注册。
- Application name 可以Blog的域名：www.sixianed.com
- Homepage URL 是Blog的主页地址：https://www.sixianed.com/
- Application description，Blog描述， 自己随便写。
- Authorization callback URL 也填自己Blog 的主页：https://www.sixianed.com 。

提交成功后， 会跳转到详情信息页。上面有 **Client ID** 和 **Client Secret**

### 修改 themes/maupassant/_config.yml
```yaml
gitment:
  enable: true ## 启用gitment
  owner: liuhengloveyou ## github账户
  repo: https://github.com/liuhengloveyou/export ## 用来存放评论的github 项目
  client_id: xxxxxx ## GitHub client ID, e.g. 75752dafe7907a897619
  client_secret: xxxxxx ## GitHub client secret, e.g. ec2fb9054972c891289640354993b662f4cccc50
```

搞定。maupassant不只简洁漂亮，还方便。