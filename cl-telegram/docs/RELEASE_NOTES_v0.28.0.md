# Release Notes - cl-telegram v0.28.0

**版本**: 0.28.0  
**发布日期**: 2026-04-20  
**主要特性**: Bot API 9.4-9.6 完整支持

---

## 新功能

### Bot API 9.4 支持

#### 自定义表情符号消息

完整的自定义表情符号（Custom Emoji）支持：

- **发送自定义表情符号消息** - 在私聊/群组中发送单独的自定义表情符号
- **表情符号包管理** - 创建、编辑、删除表情符号包
- **表情符号浏览** - 获取和浏览可用的表情符号包
- **缓存优化** - 高效的表情符号缓存机制

**新增函数**:
```lisp
;; 核心功能
(send-custom-emoji-message chat-id emoji-id)
(get-custom-emoji-sticker emoji-id)
(get-custom-emoji-pack pack-id)
(list-custom-emoji-packs)

;; 包管理
(create-custom-emoji-pack title :emojis emojis)
(add-custom-emoji-to-pack pack-id emoji-id)
(delete-custom-emoji pack-id emoji-id)

;; 缓存管理
(clear-custom-emoji-cache)
(get-custom-emoji-cache-stats)
```

#### 增强消息内容

支持互动内容和投票功能：

- **互动内容解析** - 解析消息中的互动元素
- **投票创建** - 创建标准投票和测验模式投票
- **投票结果** - 获取实时投票统计

**新增函数**:
```lisp
(get-enhanced-message-content chat-id message-id)
(create-interactive-poll chat-id question options)
(create-quiz-mode chat-id question options correct-option)
(get-poll-results chat-id message-id)
```

#### 动画表情符号

- **发送动画表情** - 发送带有动画效果的表情符号
- **表情状态** - 设置和获取用户表情状态
- **可用表情** - 获取可用的动画表情列表

**新增函数**:
```lisp
(send-animated-emoji chat-id emoji)
(get-available-emoji)
(get-emoji-status)
(set-emoji-status emoji)
```

---

### Bot API 9.5 支持

#### DateTime MessageEntity

日期时间实体支持，用于格式化的日期/时间显示：

- **创建日期时间实体** - 支持多种格式（ISO8601, RFC2822, 人类可读）
- **解析日期时间** - 从消息文本中解析日期时间实体
- **时区转换** - 支持时区感知和转换
- **格式化显示** - 多种显示格式选项

**新增类**:
```lisp
(datetime-entity
  :datetime      ; 日期时间值
  :timezone      ; 时区信息
  :format        ; 格式类型
  :display-text) ; 显示文本
```

**新增函数**:
```lisp
(make-datetime-entity datetime &key timezone format display-text)
(parse-datetime-entity text start end)
(format-datetime-display entity &key format timezone)
(get-timezone-aware-datetime datetime timezone)
(convert-datetime-timezone entity target-timezone)
```

#### 托管机器人（Managed Bots）

完整的组织级机器人管理功能：

- **机器人注册** - 将机器人注册为托管机器人
- **状态查询** - 获取机器人管理状态
- **凭证更新** - 安全地更新机器人令牌
- **变更通知** - 令牌变更通知和历史记录
- **事件处理** - 注册令牌变更事件处理器

**新增类**:
```lisp
(managed-bot-info
  :bot-id              ; 机器人 ID
  :organization-id     ; 组织 ID
  :status              ; 状态（active/suspended）
  :token-last-changed  ; 令牌最后变更时间
  :name                ; 机器人名称
  :username)           ; 机器人用户名

(token-change-notification
  :bot-id      ; 机器人 ID
  :change-type ; 变更类型
  :changed-at  ; 变更时间
  :changed-by  ; 变更执行者
  :reason)     ; 变更原因
```

**新增函数**:
```lisp
;; 注册和管理
(register-managed-bot bot-token :organization-id org-id)
(get-bot-management-status bot-id)
(unregister-managed-bot bot-id)

;; 凭证管理
(update-bot-credentials bot-id new-token :reason reason)
(get-token-change-history bot-id :limit limit)

;; 事件处理
(handle-token-change-notification notification-data)
(register-token-change-handler handler-id handler-fn)
(unregister-token-change-handler handler-id)
```

---

### Bot API 9.6 支持

#### Mini App 设备访问

设备硬件访问 API（通过 CLOG 集成）：

- **摄像头访问** - 请求和使用设备摄像头
- **麦克风访问** - 请求和使用设备麦克风
- **媒体捕获** - 拍摄照片和视频
- **媒体流** - 获取和释放媒体流
- **权限管理** - 查询设备权限和支持

**新增函数**:
```lisp
;; 设备访问
(request-camera-access)
(request-microphone-access)
(capture-photo :quality :high)
(capture-video :duration 30 :quality :high)
(get-media-stream :video t :audio t)
(release-media-stream stream-id)

;; 权限和支持
(get-device-permissions)
(check-device-support :camera)
```

#### Mini App 主题集成

与 Telegram 客户端主题同步：

- **主题同步** - 自动同步客户端主题
- **主题参数** - 获取和应用主题参数
- **自定义主题** - 应用自定义主题参数
- **主题事件** - 监听主题变更事件

**新增类**:
```lisp
(mini-app-theme
  :bg-color           ; 背景色
  :text-color         ; 文字色
  :hint-color         ; 提示色
  :link-color         ; 链接色
  :button-color       ; 按钮色
  :secondary-bg-color ; 次要背景色
  :header-bg-color    ; 头部背景色
  :is-dark)           ; 是否深色主题
```

**新增函数**:
```lisp
;; 主题管理
(get-mini-app-theme)
(sync-with-client-theme)
(apply-theme-parameters :bg-color "#1a1a1a")
(get-theme-parameters)
(set-theme-override :dark)

;; 事件处理
(on-theme-change handler-id handler-fn)
```

---

## 新增的类

### Bot API 9.4

| 类名 | 描述 |
|------|------|
| `custom-emoji-sticker` | 自定义表情符号贴纸 |
| `custom-emoji-pack` | 自定义表情符号包 |
| `interactive-content` | 互动内容基类 |
| `interactive-poll` | 互动投票 |
| `quiz-poll` | 测验模式投票 |

### Bot API 9.5

| 类名 | 描述 |
|------|------|
| `datetime-entity` | 日期时间消息实体 |
| `managed-bot-info` | 托管机器人信息 |
| `token-change-notification` | 令牌变更通知 |

### Bot API 9.6

| 类名 | 描述 |
|------|------|
| `mini-app-theme` | Mini App 主题 |

---

## 技术改进

### 缓存优化

- **表情符号缓存** - 两级缓存（贴纸和包）
- **自动失效** - 智能缓存失效机制
- **统计监控** - 缓存命中率监控

### 错误处理

- **异常日志** - 完整的异常日志记录
- **优雅降级** - 失败时的优雅降级处理
- **重试机制** - 关键操作的重试逻辑

### 性能优化

- **批量操作** - 支持批量获取数据
- **延迟加载** - 按需加载数据
- **内存管理** - 优化的内存使用

---

## 兼容性说明

### 向后兼容

- 完全兼容 Bot API 8.x 功能
- 现有代码无需修改
- 渐进式功能启用

### 系统依赖

```lisp
;; 核心依赖（已有）
:jonathan      ; JSON 序列化
:cl-ppcre       ; 正则表达式
:bordeaux-threads ; 线程支持
:clog           ; Web UI

;; 可选依赖（新功能）
:local-time     ; 时区处理（推荐用于 DateTime 功能）
```

### 浏览器要求（Mini App 功能）

Mini App 设备访问功能需要现代浏览器支持：

- Chrome 80+
- Firefox 75+
- Safari 13+
- Edge 80+

---

## 使用示例

### 发送自定义表情符号

```lisp
;; 发送单个自定义表情符号
(send-custom-emoji-message chat-id "AgADAgAT...")

;; 获取表情符号包信息
(let ((pack (get-custom-emoji-pack "57635243927555072")))
  (format t "包名：~A, 表情数：~D~%"
          (emoji-pack-title pack)
          (emoji-pack-sticker-count pack)))

;; 创建新的表情符号包
(create-custom-emoji-pack "My Emojis"
                          :emojis '("AgAD1..." "AgAD2...")
                          :is-official nil)
```

### 创建投票

```lisp
;; 创建标准投票
(create-interactive-poll chat-id
                         "你最喜欢的编程语言？"
                         '("Common Lisp" "Python" "Rust" "Go")
                         :allows-multiple nil)

;; 创建测验模式
(create-quiz-mode chat-id
                  "2+2 等于多少？"
                  '("3" "4" "5" "6")
                  1  ; 正确答案索引（0-based）
                  :explanation "2+2=4")

;; 获取投票结果
(let ((results (get-poll-results chat-id message-id)))
  (format t "总票数：~D~%" (getf results :total-voters)))
```

### 日期时间实体

```lisp
;; 创建日期时间实体
(let ((entity (make-datetime-entity (get-universal-time)
                                    :timezone "UTC"
                                    :format :iso8601)))
  (format t "~A~%" (datetime-display-text entity)))

;; 格式化显示
(format-datetime-display entity :format :human)
;; => "4/20/2026 3:30 PM"

;; 时区转换
(convert-datetime-timezone entity "Asia/Shanghai")
```

### 托管机器人

```lisp
;; 注册托管机器人
(register-managed-bot "123456:ABC-DEF..."
                      :organization-id "org_123"
                      :name "Support Bot")

;; 获取管理状态
(let ((status (get-bot-management-status "bot_123")))
  (when (eq (managed-bot-status status) :active)
    (format t "机器人正常运行~%")))

;; 注册令牌变更处理器
(register-token-change-handler
 'my-handler
 (lambda (notif)
   (format t "令牌变更：~A -> ~A~%"
           (token-change-type notif)
           (token-change-date notif))))
```

### Mini App 主题

```lisp
;; 同步客户端主题
(sync-with-client-theme)

;; 获取当前主题参数
(let ((params (get-theme-parameters)))
  (format t "背景色：~A~%" (getf params :bg-color)))

;; 应用自定义主题
(apply-theme-parameters :bg-color "#1a1a1a"
                        :text-color "#ffffff"
                        :button-color "#0088cc")

;; 监听主题变更
(on-theme-change 'ui-update
                 (lambda (theme)
                   (update-ui-with-theme theme)))
```

---

## 已知问题

1. **Mini App 设备访问** - 需要 CLOG Web UI 集成，纯 CLI 模式下不可用
2. **时区转换** - 完整时区支持需要 `local-time` 库
3. **视频捕获** - 浏览器兼容性可能有限制

---

## 升级指南

### 从 v0.27.0 升级

1. **更新 ASDF 配置** - 添加 `bot-api-9` 模块
2. **重新加载系统** - `(asdf:load-system :cl-telegram)`
3. **可选**: 导入新导出的函数

### 数据库迁移

不需要数据库迁移。

---

## 贡献者

- 开发团队：cl-telegram core team
- 特别感谢：Telegram Bot API 团队

---

## 相关链接

- [Bot API 9.4 官方更新日志](https://core.telegram.org/bots/api-changelog)
- [Bot API 9.5 官方更新日志](https://core.telegram.org/bots/api-changelog)
- [Bot API 9.6 官方更新日志](https://core.telegram.org/bots/api-changelog)
- [项目 GitHub](https://github.com/cl-telegram/cl-telegram)
- [完整 API 文档](docs/API_REFERENCE_v0.28.0.md)

---

**cl-telegram v0.28.0** - 2026-04-20
