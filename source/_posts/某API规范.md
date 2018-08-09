---
title: 某API规范
comments: true
date: 2018-07-25 17:18:10
time: 1532510290
tags: api
categories: web
---


### 一. 基本原则

1. 接口设计需要做到无状态。
2. 接口设计需要做到幂等。
3. 命令表达语义。



### 二. 概要

1. 所有接入服务开放给客户端的API，都基于HTTPs协议；统一域名为gateway.0x7c00.net。
2. 内部调用API走RPC协议。
3. 读写数据用JSON格式，UTF-8编码，嵌套最深4层。特殊场景需要申请、评审。
4. 数据压缩算法默认gzip；用其它压缩算法需要申请、评审。



### 三. URI规则&版本号

1. URL只能包含“api”(固定不变字符)，服务名，接口名，接口版本 4个必填字段。不能再出现其它字段。
2. URI字段只能用小写字母，数字，下划线，英文点号；服务名只能包含小写字母，数字，英文点号。接口名只能包含小写字母，数字，下划线。
3. 版本号作用于接口粒度，不作用于服务。格式为`v123`(小写v跟正整数)，每次发布递增1。不允许发布没有版本号的API。
4. 请求URL要做urlencode。

GET请求如下：

```
GET https://gateway.0x7c00.net/api/<服务名>/<接口名>/<版本号>?xx=xxx&...
```

POST请求支持JSON体和form表单两种格式：

- JSON体格式：

```json
POST gateway.0x7c00.net/api/user/update/v2
HEAD:
	Content-Type: application/json;charset=utf-8
BODY:
	{
		"name":"tom",
		"age":18
	}
```

- Form表单(默认不支持，需要申请)：

```
POST gateway.0x7c00.net/api/user/update/v1
HEAD:
	Content-Type: application/x-www-form-urlencoded;charset=utf-8
BODY:
	name=tom&age=18
```



### 四. HTTP动词

要为每个API使用适当的HTTP动词。

| 动词   | 描述                             |
| ------ | -------------------------------- |
| HEAD   | 可以针对任何资源，获取HTTP头信息 |
| GET    | 用于检索资源                     |
| POST   | 用于创建资源                     |
| PUT    | 用于更新资源                     |
| DELETE | 用于删除资源                     |



### 五. 应答&错误处理

正确使用HTTP状态码，不要修改含义或自定义状态码。

**2xx**:

| 状态码 | 含意         |
| ------ | ------------ |
| 200    | 正确请求     |
| 206    | 应答部分内容 |



返回200表示请求成功，并且接口没有错误。应答体应该是业务数据。

```json
GET user/info HTTP/1.1

Statuscode: 200
Body:
{
    "errcode": 0,
    "errmsg": "",
    "data": {
        "string": "xxx",
        "int": 123,
        "Bool": True
    }
}
```



返回206表示请求成功，应答体是部分数据。请求静态资源时使用。

```json
GET test.mp3 HTTP/1.1
Range: bytes=0-1000

Statuscode: 206
HTTP/1.1 206 OK
Content-Type:  application/octet-stream
Content-Range:  bytes  0-1000/2350
Accept-Ranges: bytes
ETag: "d67a4bc5190c91:512"
```



**3xx**:

返回301、302表示请求被重定向，客户端需要foolw请求。

| 状态码 | 含意                                                         |
| ------ | ------------------------------------------------------------ |
| 301    | 永久重写向；用于表示所请求的URI已经被`Location`头指定的URI所取代。该资源将来所有的请求都应请求到新的URI。 |
| 302    | 临时重定向；用于表示请求应跟踪到`Location`头指定的URI。但是将来对该资源的请求应该继续使用原始的URI。 |
| 304    | 资源没有更新过。                                             |



**4xx**:

| 状态码 | 含意           |
| ------ | -------------- |
| 403    | 请求被拒绝     |
| 404    | 请求资源不存在 |



**5xx**:

| 状态码 | 含意       |
| ------ | ---------- |
| 500    | 服务端错误 |

```
{
	"errcode": 50000,
	"errmsg": "service error."
}
```



### 六. 数据格式

1. GET请求参数只能使用小写字母、数字、下划线、英文点号。
2. POST请求和应答体都遵循标准Json格式，Json字段名遵循驼峰命令法。
3. 时间格式使用：`2018-03-05 15:05:06 `
4. POST请求体最在8M。



### 七. 身份验证

需要用户身份认证的接口，有如下两种认证方式：

1. HTTP cookie中传token

   ```
   $ curl -v -H "access_token=xxx-xxx-xxx-xxx" https://gateway.0x7c00.com/user/info/v2
     > GET /v1/user/info HTTP/1.1
     > Host: gateway.kugou.com
     > User-Agent: curl/7.54.0
     > Accept: */*;v=v1
     > Access_token: xxx-xxx-xxx-xxx
   ```
   末通过验证，需要返回`401`状态码，并在Body中说明具体错误信息：

   ```
   $ curl -i https://gateway.0x7c00.com/user/v1/info?access_token=xxx-xxx-xxx-xxx
     
   HTTP/1.1 403 Forbidden
   {
   	&quot;errcode&quot;: 4001,
   	&quot;errmsg&quot;: &quot;􏰯􏱻􏲎􏴩􏴪err massge.&quot;
   }
   ```

   末被授权访问的资源，需要返回`403`,并在Body中说明具体错误信息：

   ```
   $ curl -i https://gateway.kugou.com/user/info/v1?access_token=xxx-xxx-xxx-xxx&uid=123
   HTTP/1.1 403 Forbidden
   {
   	"errcode": 4003,
   	"errmsg": “您没有权限。”
    }
   ```

   

### 八. 文档

新增业务接口，必须在接口管理平台注册，并要有相关用户认可的清楚文档。



### 九. 安全性

为了保证API调用的唯一性，防止调用过程中被恶意篡改，调用任何一个API都需要携带请求ID和签名。接入层会对签名进行验证，签名不合法的请求将被拒绝服务。

主要围绕**rid**和**sign**展开：

1. **rid**：客户端每次请求都带上一个唯一标识rid，格式为：`timestamp-uuid`。服务端首先比对时间戳，如果时间差大于10分钟则认为请求无效。
2. **sign**: 按下面的**sign生成算法**，加密串就是本次请求的签名sign。服务端以同样的算法得到签名，如果不一样说明请求被篡改过，拒绝访问。

sign生成算法：

1. 客户端发版时申请验证密钥--salt，加密保存在客户端。
2. 将所有请求参数(除去sign参数和byte[]类型的参数)，按参数字母升序排序拼接成一个串；如：foo:1,bar:2,rid=123排序后是：bar:2,foo:1,rid:123。
3. 将排序好的串拼装在一起，不要有换行和空格。拼在EscapedPath后面:`/demobar2foo1rid123`
4. 把拼装好的字符串采用utf-8编码，在拼装串前后加上salt。然后使用MD5算法加密：`MD5(salt+/demobar2foo1rid123+salt)`。
5. 将加密得到的字节流使用16进制表示: `fmt.Sprintf("%x", md5.Sum([]byte(s))) // 51f7fc03841c57ea19e2f44ab92e5aff`

```go
package main

import (
	"crypto/md5"
	"fmt"
	"net/url"
	"sort"
)

const SAlT = "客户端发版前申请验证密钥salt加密保存保证不会被破解"

func main() {
	fmt.Println(sign("http://aaa.com/demo?foo=1&bar=2&rid=123"))

	return
}

func sign(rawurl string) (sign string, e error) {
	var u *url.URL

	if u, e = url.Parse(rawurl); e != nil {
		return
	}

	var keys []string
	for k := range u.Query() {
		keys = append(keys, k)
	}
	sort.Strings(keys)

	s := u.EscapedPath()
	for _, k := range keys {
		s = s + k + u.Query().Get(k)
	}
	s = SAlT + s + SAlT

	return fmt.Sprintf("%x", md5.Sum([]byte(s))), nil
}
```





### 十. HTTP请求头

1. 所有请求必须包含一个有效的User-Agent头。不包含的请求会被拒绝。每个客户端有自己的格式，如：

   ```
   User-Agent:Macintosh/Intel Mac OS X 10_13_3;AppleWebKit/537.36(KHTML, like Gecko);Chrome/64.0.3282.186
   ```

2. 所有请求必须包含一个有效的referer头。不包含的请求会被拒绝。其值为上次请求的**rid**，如果是首次请求，值与**rid**相同。

3. Content-Type默认为application/json;charset=utf-8。

4. 所有请求必须饮食一个有效的X-Forwarded-For，值为客户端IP。



### 十一. 限流

API接入层配置每个接口的限流规则。比如按IP每分钟30次。对超过流量限制的请求返回`429`，并不需要提示信息。



### 十二. 约定请求参数

|参数名  |类型   |说明             |
| ---------- | ------ | ---------------- |
| mid        | String |机器唯一码  |
| client_ver | String |客户端版本 |
| sign       | String |请求签名     |
| rid        | String |请求标识   |















