---
title: hexo node-sass 问题解决
comments: true
date: 2017-10-24 14:28:39
time: 1507866357
tags:
	- hexo
	- next
	- sass
categories: hexo
---



hexo 换主题的时候， 经常会报sass的错误。 刚才想换next主题，又报下面这样的错误：

```
$ hexo s
Error: The module '/usr/local/lib/node_modules/hexo-cli/node_modules/dtrace-provider/build/Release/DTraceProviderBindings.node'
was compiled against a different Node.js version using
NODE_MODULE_VERSION 48. This version of Node.js requires
NODE_MODULE_VERSION 57. Please try re-compiling or re-installing
the module (for instance, using `npm rebuild` or `npm install`).
    at Object.Module._extensions..node (module.js:653:18)
    at Module.load (module.js:545:32)
    at tryModuleLoad (module.js:508:12)
    at Function.Module._load (module.js:500:3)
    at Module.require (module.js:568:17)
    at require (internal/module.js:11:18)
    at Object.<anonymous> (/usr/local/lib/node_modules/hexo-cli/node_modules/dtrace-provider/dtrace-provider.js:18:23)
    at Module._compile (module.js:624:30)
    at Object.Module._extensions..js (module.js:635:10)
    at Module.load (module.js:545:32)
    at tryModuleLoad (module.js:508:12)
    at Function.Module._load (module.js:500:3)
    at Module.require (module.js:568:17)
    at require (internal/module.js:11:18)
    at Object.<anonymous> (/usr/local/lib/node_modules/hexo-cli/node_modules/bunyan/lib/bunyan.js:79:18)
    at Module._compile (module.js:624:30)
Error: The module '/Users/liuheng/Documents/blog/node_modules/dtrace-provider/build/Release/DTraceProviderBindings.node'
was compiled against a different Node.js version using
NODE_MODULE_VERSION 48. This version of Node.js requires
NODE_MODULE_VERSION 57. Please try re-compiling or re-installing
the module (for instance, using `npm rebuild` or `npm install`).
    at Object.Module._extensions..node (module.js:653:18)
    at Module.load (module.js:545:32)
    at tryModuleLoad (module.js:508:12)
    at Function.Module._load (module.js:500:3)
    at Module.require (module.js:568:17)
    at require (internal/module.js:11:18)
    at Object.<anonymous> (/Users/liuheng/Documents/blog/node_modules/dtrace-provider/dtrace-provider.js:18:23)
    at Module._compile (module.js:624:30)
    at Object.Module._extensions..js (module.js:635:10)
    at Module.load (module.js:545:32)
    at tryModuleLoad (module.js:508:12)
    at Function.Module._load (module.js:500:3)
    at Module.require (module.js:568:17)
    at require (internal/module.js:11:18)
    at Object.<anonymous> (/Users/liuheng/Documents/blog/node_modules/bunyan/lib/bunyan.js:79:18)
    at Module._compile (module.js:624:30)
    at Object.Module._extensions..js (module.js:635:10)
    at Module.load (module.js:545:32)
    at tryModuleLoad (module.js:508:12)
    at Function.Module._load (module.js:500:3)
    at Module.require (module.js:568:17)
    at require (internal/module.js:11:18)
ERROR Plugin load failed: hexo-renderer-sass
Error: dlopen(/Users/liuheng/Documents/blog/node_modules/node-sass/vendor/darwin-x64-57/binding.node, 1): no suitable image found.  Did find:
	/Users/liuheng/Documents/blog/node_modules/node-sass/vendor/darwin-x64-57/binding.node: truncated mach-o error: segment __TEXT extends to 1458176 which is past end of file 1287728
	/Users/liuheng/Documents/blog/node_modules/node-sass/vendor/darwin-x64-57/binding.node: truncated mach-o error: segment __TEXT extends to 1458176 which is past end of file 1287728
    at Object.Module._extensions..node (module.js:653:18)
    at Module.load (module.js:545:32)
    at tryModuleLoad (module.js:508:12)
    at Function.Module._load (module.js:500:3)
    at Module.require (module.js:568:17)
    at require (internal/module.js:11:18)
    at module.exports (/Users/liuheng/Documents/blog/node_modules/node-sass/lib/binding.js:19:10)
    at Object.<anonymous> (/Users/liuheng/Documents/blog/node_modules/node-sass/lib/index.js:14:35)
    at Module._compile (module.js:624:30)
    at Object.Module._extensions..js (module.js:635:10)
    at Module.load (module.js:545:32)
    at tryModuleLoad (module.js:508:12)
    at Function.Module._load (module.js:500:3)
    at Module.require (module.js:568:17)
    at require (internal/module.js:11:18)
    at Object.<anonymous> (/Users/liuheng/Documents/blog/node_modules/hexo-renderer-sass/lib/renderer.js:4:12)
    at Module._compile (module.js:624:30)
    at Object.Module._extensions..js (module.js:635:10)
    at Module.load (module.js:545:32)
    at tryModuleLoad (module.js:508:12)
    at Function.Module._load (module.js:500:3)
    at Module.require (module.js:568:17)
INFO  Start processing

```
这现象主要是因为 [node-sass](https://github.com/sass/node-sass)没有安装好。

至于为什么node-sass会没有安装好呢？肯定是网络的问题。解决办法是换国内的镜像安装就可以了：

我们可以用[淘宝的npm镜像](https://npm.taobao.org/)来安装; 淘宝的npm镜像主页提供了两种使用方式，我推荐使用定制的 [cnpm](https://github.com/cnpm/cnpm) (gzip 压缩支持) 命令行工具代替默认的 `npm`:

```
$ npm install -g cnpm --registry=https://registry.npm.taobao.org
```

不推荐直接通过添加 `npm` 参数 `alias` 一个新命令的方式， 因为我用alias的方式没有成功。



然后，重新安装node-sass：

```
$ cnpm install  node-sass
✔ Installed 1 packages
✔ Linked 174 latest versions
Downloading binary from https://npm.taobao.org/mirrors/node-sass/v4.5.3/darwin-x64-57_binding.node
Download complete
Binary saved to /Users/liuheng/Documents/blog/node_modules/_node-sass@4.5.3@node-sass/vendor/darwin-x64-57/binding.node
Caching binary to /Users/liuheng/.npminstall_tarball/node-sass/4.5.3/darwin-x64-57_binding.node
Binary found at /Users/liuheng/Documents/blog/node_modules/_node-sass@4.5.3@node-sass/vendor/darwin-x64-57/binding.node
Testing binary
Binary is fine
✔ Run 1 scripts
Recently updated (since 2017-10-17): 1 packages (detail see file /Users/liuheng/Documents/blog/node_modules/.recently_updates.txt)
✔ All packages installed (179 packages installed from npm registry, used 9s, speed 349.47kB/s, json 175(278.14kB), tarball 2.83MB)
```



rebuild 博客：

```
$ cnpm rebuild

> hexo-util@0.6.1 postinstall /Users/liuheng/Documents/blog/node_modules/hexo-util
> npm run build:highlight


> hexo-util@0.6.1 build:highlight /Users/liuheng/Documents/blog/node_modules/hexo-util
> node scripts/build_highlight_alias.js > highlight_alias.json


> dtrace-provider@0.8.5 install /Users/liuheng/Documents/blog/node_modules/dtrace-provider
> node scripts/install.js

... ...
```



然后就可以了：

```
$ hexo s
INFO  Start processing
INFO  Hexo is running at http://localhost:4000/. Press Ctrl+C to stop.
```

