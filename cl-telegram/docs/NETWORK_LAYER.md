# 网络层实现文档

## 概述

网络层负责与 Telegram 服务器建立 TCP 连接、发送和接收 MTProto 消息。

## 架构

```
┌─────────────────────────────────────────┐
│           API Layer                     │
│        (auth-api, messages-api)         │
├─────────────────────────────────────────┤
│           RPC Layer                     │
│      (rpc-call, rpc-call-async)         │
├─────────────────────────────────────────┤
│        Connection Layer                 │
│   (session management, encryption)      │
├─────────────────────────────────────────┤
│        TCP Client Layer                 │
│   (cl-async async, usocket sync)        │
└─────────────────────────────────────────┘
```

## 组件

### 1. TCP 客户端 (`tcp-client.lisp`)

提供两种 TCP 客户端实现：

#### 异步客户端 (cl-async)

```lisp
(defclass tcp-client ()
  ((host ... :accessor client-host)
   (port ... :accessor client-port)
   (socket ... :accessor client-socket)
   (connected-p ... :accessor client-connected-p)
   (on-connect-cb ... :accessor client-on-connect)
   (on-data-cb ... :accessor client-on-data)
   (on-error-cb ... :accessor client-on-error)
   (on-disconnect-cb ... :accessor client-on-disconnect)))
```

**API:**
- `make-tcp-client` - 创建客户端
- `client-connect` - 异步连接
- `client-disconnect` - 断开连接
- `client-send` - 异步发送
- `client-send-sync` - 同步发送
- `client-receive` - 接收数据
- `client-start-receive` - 启动接收循环

#### 同步客户端 (usocket)

```lisp
(defclass sync-tcp-client ()
  ((host ... :accessor sync-client-host)
   (port ... :accessor sync-client-port)
   (socket ... :accessor sync-client-socket)
   (stream ... :accessor sync-client-stream)
   (connected-p ... :accessor sync-client-connected-p)))
```

**API:**
- `make-sync-tcp-client` - 创建客户端
- `sync-client-connect` - 阻塞连接
- `sync-client-send` - 阻塞发送
- `sync-client-receive` - 阻塞接收

### 2. 连接管理 (`connection.lisp`)

管理 MTProto 连接状态:

```lisp
(defclass connection ()
  ((session-id ... :accessor conn-session-id)       ; 8 字节会话 ID
   (seqno ... :accessor conn-seqno)                  ; 消息序列号
   (last-msg-id ... :accessor conn-last-msg-id)      ; 最后消息 ID
   (server-salt ... :accessor conn-server-salt)      ; 服务器盐值
   (auth-key ... :accessor conn-auth-key)            ; 授权密钥
   (auth-key-id ... :accessor conn-auth-key-id)      ; 密钥 ID
   (tcp-client ... :accessor conn-tcp-client)        ; TCP 客户端
   (pending-requests ... :accessor conn-pending-requests)
   (event-handlers ... :accessor conn-event-handlers)))
```

**API:**
- `make-connection` - 创建连接
- `connect` - 建立连接
- `disconnect` - 断开连接
- `connected-p` - 检查连接状态
- `reconnect` - 重新连接
- `connection-send` - 发送加密消息
- `connection-send-rpc` - 发送 RPC 请求并等待响应
- `generate-msg-id` - 生成消息 ID

### 3. RPC 调用 (`rpc.lisp`)

处理 RPC 请求和响应:

**API:**
- `rpc-call` - 同步 RPC 调用
- `rpc-call-async` - 异步 RPC 调用
- `rpc-call-with-retry` - 带重试的 RPC 调用
- `rpc-batch` - 批量 RPC 调用
- `wait-for-response` - 等待响应

**宏:**
- `with-rpc-call` - 执行 RPC 并绑定结果
- `rpc-handler-case` - 处理 RPC 错误

## 消息流程

### 发送消息

```
用户调用 (rpc-call conn request)
    ↓
生成 msg-id 和 seqno
    ↓
构建 RPC 请求 (make-rpc-request)
    ↓
加密消息 (encrypt-message)
    ↓
构建传输包 (make-transport-packet)
    ↓
通过 TCP 发送 (client-send)
    ↓
等待响应 (wait-for-response)
    ↓
返回响应或超时
```

### 接收消息

```
TCP 接收数据 (on-data-received)
    ↓
解析传输包 (parse-transport-packet)
    ↓
解密消息 (decrypt-message)
    ↓
解析消息头 (msg-id, seqno, length)
    ↓
根据 constructor 处理:
  - rpc_result#f35c6d01 → handle-rpc-result
  - rpc_error#2144ca19 → handle-rpc-error
  - msg_container#73f1f8dc → handle-msg-container
  - 其他 → handle-update
```

## 事件处理

```lisp
;; 注册事件处理器
(set-event-handler conn :update
  (lambda (data)
    (format t "收到更新：~A~%" data)))

(set-event-handler conn :error
  (lambda (err)
    (format t "错误：~A~%" err)))

;; 移除事件处理器
(remove-event-handler conn handler)
```

## 使用示例

### 异步客户端

```lisp
(use-package :cl-telegram/network)

;; 创建连接
(let ((conn (make-connection :host "149.154.167.51" :port 443)))
  ;; 注册事件处理器
  (set-event-handler conn :connected
    (lambda () (format t "已连接~%")))
  (set-event-handler conn :disconnected
    (lambda () (format t "已断开~%")))
  (set-event-handler conn :update
    (lambda (data) (handle-update data)))

  ;; 连接
  (connect conn)

  ;; 发送 RPC 请求
  (let ((result (rpc-call conn request-body :timeout 10000)))
    (format t "结果：~A~%" result))

  ;; 断开
  (disconnect conn)))
```

### 同步客户端

```lisp
(use-package :cl-telegram/network)

(let ((client (make-sync-tcp-client "149.154.167.51" 443)))
  (when (sync-client-connect client :timeout 10)
    ;; 发送数据
    (sync-client-send client #(1 2 3 4))

    ;; 接收数据
    (let ((data (sync-client-receive client 100)))
      (format t "收到：~A~%" data))

    ;; 断开
    (sync-client-disconnect client)))
```

## 错误处理

### 连接错误

```lisp
(handler-case
    (connect conn)
  (connection-error (e)
    (format t "连接失败：~A~%" e)))
```

### RPC 错误

```lisp
(rpc-handler-case (rpc-call conn request)
  ((:error code msg)
   (format t "RPC 错误 ~D: ~A~%" code msg))
  (result
   (format t "成功：~A~%" result)))
```

## 测试

```lisp
;; 运行网络层测试
(cl-telegram/tests:run-network-tests)
```

## 待完成工作

1. **连接池管理** - 支持多个 DC 连接
2. **自动重连** - 断线自动重连逻辑
3. **消息队列** - 消息优先级和批处理
4. **CDN 支持** - 媒体文件下载
5. **代理支持** - SOCKS5/HTTP 代理

## 参考资料

- [MTProto Transport](https://core.telegram.org/mtproto/description#encrypted-message)
- [cl-async 文档](https://orthecreedence.github.io/cl-async/)
- [usocket 文档](https://usocket.common-lisp.dev/)
