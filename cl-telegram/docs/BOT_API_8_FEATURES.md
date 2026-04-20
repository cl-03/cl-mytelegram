# Bot API 8.0 功能实现文档

**版本**: v0.23.0  
**实现日期**: 2026-04-20  
**参考**: [Telegram Bot API Changelog](https://core.telegram.org/bots/api-changelog)

---

## 概述

本次更新实现了 Telegram Bot API 8.0（2024 年 11 月发布）的主要新功能：

1. **消息反应 (Message Reactions)** - 完整的 emoji 和自定义表情反应支持
2. **表情状态 (Emoji Status)** - Premium 用户的表情状态管理
3. **高级媒体编辑 (Advanced Media Editing)** - 媒体编辑增强功能
4. **Story Highlights 管理** - 故事亮点创建和管理
5. **消息翻译 (Message Translation)** - 多语言翻译支持

---

## 1. 消息反应功能

### 类型定义

```lisp
;; 反应类型
reaction-type
  - type: :emoji | :custom-emoji | :star
  - emoji: 表情字符
  - custom-emoji-id: 自定义表情 ID

;; 反应计数
reaction-count
  - reaction: 反应类型
  - count: 数量
  - is-selected: 用户是否已选择

;; 反应更新
message-reaction-update
  - chat-id: 聊天 ID
  - message-id: 消息 ID
  - date: 时间戳
  - old-reaction: 旧反应
  - new-reaction: 新反应
```

### API 函数

#### 发送反应

```lisp
(send-message-reaction chat-id message-id reaction &key is-big)
```

**参数**:
- `chat-id`: 聊天标识符
- `message-id`: 消息标识符
- `reaction`: 反应类型对象或 emoji 字符串
- `is-big`: 是否发送大动画（默认 NIL）

**示例**:
```lisp
;; 发送 emoji 反应
(send-message-reaction 123 456 "👍")

;; 发送自定义表情反应
(send-message-reaction 123 456 
  (make-reaction-type-custom-emoji "sticker_id"))

;; 发送星级反应（Premium）
(send-message-reaction 123 456 
  (make-reaction-type-star))

;; 发送大动画反应
(send-message-reaction 123 456 "❤️" :is-big t)
```

#### 获取反应详情

```lisp
(get-message-reactions chat-id message-id)
```

返回消息的所有反应详情，包括每种反应的数量和最近反应的用户。

#### 移除反应

```lisp
(remove-message-reaction chat-id message-id &optional reaction)
```

#### 获取可用反应

```lisp
(get-available-reactions)
```

返回当前用户可用的所有反应类型列表。

### 反应更新处理器

#### 注册处理器

```lisp
(on-message-reaction handler-fn &optional chat-id)
```

**示例**:
```lisp
(on-message-reaction 
  (lambda (chat-id msg-id old new)
    (format t "反应变化：~A -> ~A~%" old new)))
```

#### 注销处理器

```lisp
(unregister-reaction-handler handler-id)
```

---

## 2. 表情状态功能

### 类型定义

```lisp
emoji-status
  - document-id: 自定义表情文档 ID
  - emoji: 标准 emoji 字符
  - is-premium: 是否 Premium 专用
  - is-active: 是否激活
```

### API 函数

#### 设置表情状态

```lisp
(set-emoji-status status &key duration-seconds)
```

**参数**:
- `status`: emoji 字符串或自定义表情 ID
- `duration-seconds`: 可选的持续时间（秒）

**示例**:
```lisp
;; 设置标准 emoji 状态
(set-emoji-status "🔥")

;; 设置自定义表情状态
(set-emoji-status "custom_emoji_id")

;; 设置临时状态（1 小时）
(set-emoji-status "⭐" :duration-seconds 3600)
```

#### 清除表情状态

```lisp
(clear-emoji-status)
```

#### 获取可用状态

```lisp
(get-emoji-statuses &optional include-premium)
```

#### 获取用户状态

```lisp
(get-user-emoji-status user-id)
```

---

## 3. 高级媒体编辑功能

### 类型定义

```lisp
media-edit-options
  - crop-rectangle: 裁剪区域 (x y width height)
  - rotation-angle: 旋转角度
  - filter-type: 滤镜类型
  - overlay-text: 叠加文本
  - overlay-emoji: 叠加 emoji
  - caption: 标题
  - parse-mode: 解析模式
```

### 可用滤镜

```lisp
cl-telegram/api:+available-media-filters+
;; 包含：clarendon, ginger, moon, nashville, perpetua, 
;; x-pro-ii, adena, reyes, juno, slumber, crema, ludwig,
;; inkwell, haze, brightness, contrast, saturation,
;; warmth, vignette, blur, sharpen, noise, pixelate,
;; vintage, drama, grayscale, sepia
```

### API 函数

#### 高级媒体编辑

```lisp
(edit-message-media-advanced chat-id message-id media-file &key options)
```

**示例**:
```lisp
(let ((options (make-instance 'media-edit-options
                               :caption "新标题"
                               :parse-mode :html)))
  (edit-message-media-advanced 123 456 "new_photo.jpg" 
                               :options options))
```

#### 裁剪媒体

```lisp
(crop-media media-file &key x y width height)
```

#### 旋转媒体

```lisp
(rotate-media media-file &key angle)
```

#### 应用滤镜

```lisp
(apply-media-filter media-file filter-type &key intensity)
```

**示例**:
```lisp
(apply-media-filter "photo.jpg" "clarendon" :intensity 0.8)
```

#### 添加文本叠加

```lisp
(add-text-overlay media-file text &key position font-size color background)
```

#### 添加 Emoji 贴纸

```lisp
(add-emoji-sticker media-file emoji-id &key position size opacity)
```

#### 编辑标题

```lisp
(edit-message-caption chat-id message-id caption &key parse-mode entities)
```

---

## 4. Story Highlights 管理

### 类型定义

```lisp
story-highlight
  - id: 亮点 ID
  - title: 标题
  - cover-media: 封面媒体
  - stories: 故事 ID 列表
  - date-created: 创建时间
  - is-hidden: 是否隐藏
  - privacy-type: 隐私设置

highlight-cover
  - media-id: 媒体 ID
  - crop-area: 裁剪区域
  - filter: 滤镜
```

### API 函数

#### 创建亮点

```lisp
(create-highlight title &key cover-media story-ids privacy)
```

**示例**:
```lisp
(create-highlight "旅行回忆" 
                  :cover-media "cover.jpg"
                  :story-ids '(1 2 3)
                  :privacy :public)
```

#### 编辑亮点

```lisp
(edit-highlight highlight-id &key title cover-media story-ids)
```

#### 编辑封面

```lisp
(edit-highlight-cover highlight-id cover-media &key crop-area filter)
```

#### 重排序

```lisp
(reorder-highlights highlight-ids)
```

**示例**:
```lisp
(reorder-highlights '(3 1 2)) ; 重新排列亮点顺序
```

#### 获取亮点

```lisp
(get-highlights &optional user-id)
```

#### 删除亮点

```lisp
(delete-highlight highlight-id)
```

#### 设置隐私

```lisp
(set-highlight-privacy highlight-id privacy-type)
```

隐私选项：
- `:public` - 公开
- `:contacts` - 仅联系人
- `:close-friends` - 密友
- `:custom` - 自定义

#### 添加故事到亮点

```lisp
(add-stories-to-highlight highlight-id story-ids)
```

---

## 5. 消息翻译功能

### 类型定义

```lisp
translation-result
  - original-text: 原文本
  - translated-text: 翻译文本
  - source-language: 源语言
  - target-language: 目标语言
  - was-auto-detected: 是否自动检测
```

### 支持的语言

超过 60 种语言支持，包括：
- en - English
- zh, zh-cn, zh-tw - Chinese (Simplified/Traditional)
- ja - Japanese
- ko - Korean
- ru - Russian
- es - Spanish
- fr - French
- de - German
- it - Italian
- pt - Portuguese
- ar - Arabic
- hi - Hindi
- 等等...

### API 函数

#### 翻译消息

```lisp
(translate-message chat-id message-id &key target-language)
```

**示例**:
```lisp
;; 翻译消息到英文
(translate-message 123 456 :target-language "en")

;; 翻译到中文
(translate-message 123 456 :target-language "zh")
```

#### 翻译文本

```lisp
(translate-text text &key from-language to-language)
```

**示例**:
```lisp
(translate-text "Hello, World!" 
                :from-language "en" 
                :to-language "zh")
```

#### 设置聊天语言

```lisp
(set-chat-language chat-id language-code)
```

**示例**:
```lisp
(set-chat-language 123 "zh") ; 设置中文偏好
```

#### 获取支持的语言

```lisp
(get-supported-languages)
```

返回 `(code . name)`  cons 单元列表。

#### 自动翻译

```lisp
;; 启用自动翻译
(enable-auto-translation chat-id &key target-language)

;; 禁用自动翻译
(disable-auto-translation chat-id)

;; 检查是否启用
(auto-translation-enabled-p chat-id)
```

**示例**:
```lisp
;; 为聊天启用自动翻译到英文
(enable-auto-translation 123 :target-language "en")
```

#### 翻译缓存

```lisp
;; 清除缓存
(clear-translation-cache)

;; 获取历史记录
(get-translation-history &optional limit)
```

---

## 使用示例

### 综合示例：反应监控机器人

```lisp
(in-package #:cl-telegram/api)

;; 注册反应变化处理器
(on-message-reaction 
  (lambda (chat-id msg-id old new)
    (cond
      ;; 记录所有反应变化
      (t (format t "[~A] 消息 ~A: ~A -> ~A~%" 
                 chat-id msg-id old new))
      ;; 特定反应触发操作
      ((string= new "🔥") 
       (send-message chat-id "🔥 火焰反应！")))))

;; 启动机器人
(run-bot)
```

### 综合示例：多语言聊天室

```lisp
(in-package #:cl-telegram/api)

;; 设置聊天语言偏好
(set-chat-language -1001234567890 "zh")  ; 群组 ID

;; 启用自动翻译
(enable-auto-translation -1001234567890 :target-language "zh")

;; 翻译特定消息
(let ((result (translate-message -1001234567890 123 
                                  :target-language "zh")))
  (when result
    (format t "原文：~A~%" (translation-original-text result))
    (format t "翻译：~A~%" (translation-translated-text result))))
```

### 综合示例：故事亮点管理

```lisp
(in-package #:cl-telegram/api)

;; 创建新亮点
(let ((highlight (create-highlight "2024 旅行"
                                   :cover-media "cover.jpg"
                                   :story-ids '(100 101 102)
                                   :privacy :public)))
  (when highlight
    (format t "创建亮点：~A~%" 
            (story-highlight-title highlight))))

;; 获取所有亮点
(let ((highlights (get-highlights)))
  (dolist (h highlights)
    (format t "~A: ~A 个故事~%" 
            (story-highlight-title h)
            (length (story-highlight-stories h)))))

;; 重排序亮点
(reorder-highlights '(3 1 2))

;; 编辑封面
(edit-highlight-cover 1 "new_cover.jpg" 
                      :filter "clarendon")
```

---

## 测试

运行 Bot API 8.0 测试：

```lisp
(asdf:load-system :cl-telegram/tests)

;; 运行所有 Bot API 8.0 测试
(cl-telegram/tests:run-bot-api-8-tests)

;; 运行特定测试套件
(fiveam:run! 'bot-api-8-reaction-tests)
(fiveam:run! 'bot-api-8-emoji-status-tests)
(fiveam:run! 'bot-api-8-media-editing-tests)
(fiveam:run! 'bot-api-8-story-highlights-tests)
(fiveam:run! 'bot-api-8-translation-tests)
```

---

## 文件结构

```
cl-telegram/
├── src/
│   └── api/
│       ├── bot-api-8.lisp          # Bot API 8.0 实现
│       └── api-package.lisp        # 包导出（已更新）
├── tests/
│   └── bot-api-8-tests.lisp        # Bot API 8.0 测试
└── docs/
    └── BOT_API_8_FEATURES.md       # 本文档
```

---

## 注意事项

### 1. Premium 功能

以下功能需要 Telegram Premium 订阅：
- 星级反应 (star reactions)
- 自定义表情状态
- 部分高级媒体滤镜
- 扩展的翻译配额

### 2. 图像 processing

当前实现中，媒体编辑函数（`crop-media`, `rotate-media`, `apply-media-filter` 等）是存根实现。要启用实际功能，需要集成 Common Lisp 图像处理库，如：
- `lispkit` (基于 ImageMagick)
- `cl-bmp`, `cl-jpeg`, `cl-png` 直接操作

### 3. 翻译服务

当前翻译功能使用 Telegram 内置翻译 API。需要确保：
- 用户具有翻译权限（Premium 用户有更高配额）
- 网络连接稳定

### 4. 缓存管理

所有功能都实现了缓存机制：
- 反应缓存：`*available-reaction-types*`
- 亮点缓存：`*highlights-cache*`
- 翻译缓存：`*translation-cache*`

定期清理缓存以避免内存泄漏：
```lisp
(clear-translation-cache)
(clear-story-thumbnail-cache)
```

---

## 参考资料

- [Bot API Changelog](https://core.telegram.org/bots/api-changelog)
- [Message Reactions API](https://core.telegram.org/api/reactions)
- [Translation API](https://core.telegram.org/api/translation)
- [Telegram Blog - AI Editor and More](https://telegram.org/blog/ai-editor-mighty-polls-and-more)

---

## 版本历史

### v0.23.0 (2026-04-20)
- 初始 Bot API 8.0 实现
- 消息反应完整支持
- 表情状态管理
- 高级媒体编辑框架
- Story Highlights 管理
- 消息翻译支持
