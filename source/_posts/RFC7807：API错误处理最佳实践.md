---
title: RFC7807：API错误处理最佳实践
comments: true
date: 2018-07-19 09:47:57
time: 1531964877
tags: API
categories: web
---



> **rfc7807详细地址，各位开发者可点击：https://tools.ietf.org/html/rfc7807**

**构建好的API的关键之一是错误处理与响应。**

每家互联网公司或研发部门都会自定义错误处理，“良好的错误编码”结构应该包含以下三个基本标准，才能让它能够真正对用户有用：

**1、使用HTTP状态码**

API的返回编码采用HTTP状态代码方案中的标准代码形式，通过使用这种非常通用的标准化来记录状态，不仅可以传达错误的类型，而且还可以告知错误发生的位置（5xx意味着它是服务器问题，而4xx意味着客户端出错了）。

2、内部参考ID，用于记录特定错误的符号。

3、如果你有HTTP状态码方案或类似的参考资料，也可以取代HTTP状态码。

**FHIR**

如果我们以医疗FHIR标准为例，那么错误就被定义为一个称为操作结果的FHIR资源。

下面是一个错误响应的JSON实例：

{

 "resourceType": "OperationOutcome",

 "id": "exception",

 "text": {

  "status": "additional",

  "div": "<div xmlns=\"http://www.w3.org/1999/xhtml\">\n<p>SQL Link Communication Error (dbx = 34234)</p>\n</div>"

 },

 "issue": [{

  "severity": "error",

  "code": "exception",

  "details": {

   "text": "SQL Link Communication Error (dbx = 34234)"

  }

 }]

}

这个产品的概念和界面都非常好，网址是https://www.hl7.org/fhir/operationoutcome.html，可以用于错误响应，当然也可以是响应成功的消息体。 如果想要使用它，需要了解A-Z的FHIR标准，可能对于某些人来说，FHIR概念可能有点设计过度。

**Google**

Google的API使用以下错误响应消息体：

{

 "error": {

  "errors": [{

   "domain": "global",

   "reason": "invalidParameter",

   "message": "Invalid string value: 'asdf'. Allowed values: [mostpopular]",

   "locationType": "parameter",

   "location": "chart"

  }],

  "code": 400,

  "message": "Invalid string value: 'asdf'. Allowed values: [mostpopular]"

 }

}

参考URL为：

https://developers.google.com/doubleclick-search/v2/standard-error-responses

其实我觉得Google的JSON结构有点奇怪：errors数组内包括着erros数组？

**Facebook**

对于Facebook，错误响应消息体也不相同：

{

 "error": {

  "message": "Message describing the error",

  "type": "OAuthException",

  "code": 190,

  "error_subcode": 460,

  "error_user_title": "A title",

  "error_user_msg": "A message",

  "fbtrace_id": "EJplcsCHuLu"

 }

}

**Spotify**

Spotify 返回的信息和Apache，Nginx的消息内容差不多：

{

 "error": {

  "status": 502,

  "message": "Bad gateway."

 }

}

**淘宝**

以下的是淘宝平台返回的消息，它是和XML相同的结构体：

<error_response>

   <code>11</code>

   <msg>Insufficient isv permissions</msg>

   <sub_code>isv.permission-api-package-empty</sub_code>

</error_response>

<!--top176185.cm3--> 

还有其它更多的例子，大家看到每家的错误代码和消息体都是千差万别的。 如何参考错误链接，生成的错误代码以及如何显示编码都会因不同的公司而异。

值得庆幸的是，标准化方法已经取得了进展：IETF组织最近发布了RFC 7807，其中描述了如何使用JSON对象作为在HTTP响应中对细节进行建模的方式。

**RFC 7807支持**

本文档定义了一个“问题详细信息”，作为在HTTP响应中移动设备可读的错误细节的一种方式，以避免为HTTP API定义各种新的错误响应格式。

通过提供具有错误响应的更具体的机器可读消息，API客户端可以更有效地对错误作出反应，并最终从REST API测试角度和客户端使API服务更加可靠。

一般来说，错误响应的目标是创建一个信息源，以便不仅向用户通知问题，而且还能够协助解决问题。简单地说出一个问题并不能解决问题 - API出错目前的状态也是如此。

RFC 7807提供了用于从HTTP API返回问题详细信息的标准格式。它规定了以下内容：

**错误响应必须使用400或500范围内的标准HTTP状态码来说明错误的类别。**

错误响应将是Content-Type应用程序/问题，附加json或xml：application/problem + json，application/problem + xml的序列化格式。

错误响应将具有以下键（Key）值：

1.细节（字符串） - 特定错误的可读描述。

2.类型（字符串） - 描述错误条件的文档的URL（可选，如果没有提供，则假定“about:blank”;应可被解析为可读文档）。

3.title（字符串） - 一般错误类型的简短易读的标题;对于给定的类型，标题不应改变。

4.状态（号码） - HTTP状态码;这是为了使所有信息都在一个地方，而且还要纠正由于使用代理服务器而导致的状态码变化。

5.实例（字符串） - 此可选键可以选填，具有特定错误的唯一URI;这通常会指向该特定响应的错误日志。

来看如下代码：

{

 "type": "https://example.net/validation-error",

 "title": "Your request parameters didn't validate.",

 "invalid-params": [{

  "name": "age",

  "reason": "must be a positive integer"

 }, {

  "name": "color",

  "reason": "must be 'green', 'red' or 'blue'"

 }]

}

API开发者可以提供额外的密钥，为消费者提供有关错误的更多信息，如果能够定义新问题详细信息，问题详细信息也可以进行扩展。

**新的消息类型定义：**

1、类型URI（通常使用“http”或“https”）

2、一个描述合适的标题

3、与其一起使用的HTTP状态代码。

比如，如果要将HTTP API发布到购物车，则可能需要指出该用户信用不足（上面的代码示例），因此无法进行购买。

需要确定问题详细信息的格式，如果API是基于JSON的，则为JSON格式;如果使用该格式，则为XML，以避免产生混乱。

还要确定适合用途的已定义的类型URI。如果有一个可用，可以重用URI。如果一个不可用，您可以创建并记录一个新的类型URI（它应该在开发者的控制之下随时间变得稳定），一个适当的标题和它将要使用的HTTP状态代码，以及它的含义以及告之别人如何处理。

请看如下代码：

{

 "type": "https://example.com/problems/request-parameters-missing",

 "title": "required parameters are missing",

 "detail": "The parameters: limit, date were not provided",

 "limit_parameter_format": "number",

 "date_parameter_format": "YYYY-mm-ddThh:mm-ss"

}

已经针对于某种语言的实现：

Java：https://github.com/zalando/problem-spring-web

Node.js：https://www.npmjs.com/package/problem-json

**小结**

下一步，使用RFC-7807-Problem Details的API规范将会越来越普遍，它具有非常好的灵活性和简单性。人们可以自定义错误类型，只要包括有他们要链接的描述即可。API开发者可以根据自己的需要提供尽可能少或更多的细节，甚至可以根据环境（例如，生产与开发）来决定公开哪些信息。

使用RFC-7807可以让API接口统一，使API更易于构建，测试与维护。越来越多的API开发者会应用这一标准。相信很快在客户端和服务器会统一标准，甚至AI处理常见的错误解决方案使用它也足够使用。