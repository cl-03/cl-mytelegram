# Bot API 8.1-8.3 新增功能实现计划

**文档版本**: 1.0  
**更新日期**: 2026-04-20  
**目标版本**: cl-telegram v0.24.0

---

## 一、Bot API 版本概述

根据调研结果，Telegram Bot API 在 2025 年发布了以下版本：

| 版本 | 发布日期 | 主要功能 |
|------|----------|----------|
| 8.0 | 2024-11 | 消息反应、Emoji 状态、媒体编辑、Story Highlights、翻译 |
| 8.1 | 2024-12 | 业务功能增强 |
| 8.2 | 2025-01-01 | 用户验证、聊天验证、星星升级 |
| 8.3 | 2025-02-12 | 付费礼物、视频封面、服务消息反应 |

**注意**: Bot API 9.x 版本在 2025 年下半年发布，暂不在本次实现范围内。

---

## 二、Bot API 8.1 新增功能

### 2.1 业务功能增强

Bot API 8.1 主要增强了 Business 相关功能。

#### 新增方法

| 方法 | 描述 | 参数 |
|------|------|------|
| `getBusinessConnection` | 获取业务连接信息 | `business_connection_id` |
| `getBusinessIntro` | 获取业务介绍 | `user_id` |
| `getBusinessLocation` | 获取业务地址 | `user_id` |
| `getBusinessOpeningHours` | 获取业务营业时间 | `user_id` |

#### 新增类型

- `BusinessConnection` - 业务连接信息
- `BusinessIntro` - 业务介绍
- `BusinessLocation` - 业务地址
- `BusinessOpeningHours` - 营业时间

---

## 三、Bot API 8.2 新增功能

### 3.1 验证功能

#### 新增方法

| 方法 | 描述 | 参数 |
|------|------|------|
| `verifyUser` | 验证用户（加 V 标） | `user_id`, `custom_description` |
| `verifyChat` | 验证聊天/频道 | `chat_id`, `custom_description` |
| `removeUserVerification` | 移除用户验证 | `user_id` |
| `removeChatVerification` | 移除聊天验证 | `chat_id` |

**使用示例**:
```lisp
;; 验证用户
(verify-user user-id :custom-description "Official account")

;; 验证频道
(verify-chat channel-id :custom-description "Verified channel")

;; 移除验证
(remove-user-verification user-id)
(remove-chat-verification chat-id)
```

### 3.2 星星升级功能

#### 新增字段

- `Gift.upgrade_star_count` - 升级礼物所需的星星数量
- `sendGift.pay_for_upgrade` - 是否支付升级

---

## 四、Bot API 8.3 新增功能

### 4.1 付费礼物 (Paid Gifts)

#### 新增/修改方法

| 方法 | 变更 | 描述 |
|------|------|------|
| `sendGift` | 新增 `chat_id` 参数 | 允许 bot 向频道聊天发送礼物 |

#### 新增类型

- `Gift` - 礼物对象
- `Gifts` - 礼物列表
- `TransactionPartnerChat` - 与聊天的交易

#### 新增方法

| 方法 | 描述 | 参数 |
|------|------|------|
| `getAvailableGifts` | 获取可用礼物列表 | 无 |
| `sendGift` | 发送礼物 | `user_id`/`chat_id`, `gift_id`, `text`, `pay_for_upgrade` |

**使用示例**:
```lisp
;; 获取可用礼物
(let ((gifts (get-available-gifts)))
  (dolist (gift gifts)
    (format t "Gift: ~A, Cost: ~A stars~%"
            (gift-name gift)
            (gift-upgrade-star-count gift))))

;; 发送付费礼物给频道
(send-gift chat-id
           :gift-id "gift_123"
           :text "Congratulations!"
           :pay-for-upgrade t)
```

### 4.2 视频增强功能

#### 新增字段

- `Video.cover` - 消息特定的封面
- `Video.start_timestamp` - 视频开始时间戳

#### 新增/修改方法

| 方法 | 新增参数 | 描述 |
|------|----------|------|
| `sendVideo` | `cover`, `start_timestamp` | 发送视频时指定封面和开始时间 |
| `InputMediaVideo` | `cover`, `start_timestamp` | 媒体组中的视频 |
| `InputPaidMediaVideo` | `cover`, `start_timestamp` | 付费媒体视频 |
| `forwardMessage` | `video_start_timestamp` | 转发视频时修改开始时间 |
| `copyMessage` | `video_start_timestamp` | 复制视频时修改开始时间 |

**使用示例**:
```lisp
;; 发送带封面的视频
(send-video chat-id "video.mp4"
            :cover "cover.jpg"
            :start-timestamp 30)  ;; 从 30 秒开始

;; 转发视频并修改开始时间
(forward-message chat-id from-chat message-id
                 :video-start-timestamp 15)
```

### 4.3 服务消息反应

#### 变更

- 允许对大多数类型的服务消息添加反应
- 之前版本仅支持普通消息的反应

---

## 五、实现优先级

### P0 - 核心功能（必需）

1. **验证功能** (8.2)
   - `verifyUser` / `verifyChat`
   - `removeUserVerification` / `removeChatVerification`

2. **付费礼物** (8.3)
   - `getAvailableGifts`
   - `sendGift` (扩展 `chat_id` 参数)

3. **星星升级** (8.2)
   - `Gift` 类型扩展

### P1 - 媒体增强（重要）

1. **视频增强** (8.3)
   - `sendVideo` 扩展
   - `InputMediaVideo` 扩展
   - `forwardMessage` / `copyMessage` 扩展

### P2 - 业务功能（可选）

1. **业务信息** (8.1)
   - `getBusinessConnection`
   - `getBusinessIntro`
   - `getBusinessLocation`
   - `getBusinessOpeningHours`

---

## 六、代码结构

### 6.1 新增文件

```
src/api/
├── bot-api-8.lisp          ;; 已有 Bot API 8.0
├── bot-api-8-extensions.lisp  ;; 新增 8.1-8.3 扩展
```

### 6.2 新增类型

```lisp
;; 验证相关
(defclass verification-result ()
  ((success :initarg :success :reader verification-success)
   (description :initarg :description :reader verification-description)))

;; 礼物相关
(defclass gift ()
  ((id :initarg :id :reader gift-id)
   (name :initarg :name :reader gift-name)
   (upgrade-star-count :initarg :upgrade-star-count :reader gift-upgrade-star-count)
   ...))

(defclass gifts ()
  ((gifts :initarg :gifts :reader gifts-list)))

(defclass transaction-partner-chat ()
  ((chat :initarg :chat :reader transaction-partner-chat-chat)
   (amount :initarg :amount :reader transaction-partner-chat-amount)))
```

### 6.3 新增函数

```lisp
;; 验证功能
(defun verify-user (user-id &key custom-description) ...)
(defun verify-chat (chat-id &key custom-description) ...)
(defun remove-user-verification (user-id) ...)
(defun remove-chat-verification (chat-id) ...)

;; 礼物功能
(defun get-available-gifts () ...)
(defun send-gift (target-id &key user-id chat-id gift-id text pay-for-upgrade) ...)

;; 视频增强
(defun send-video (chat-id video &key cover start-timestamp caption ...) ...)
```

---

## 七、测试计划

### 7.1 单元测试

- 验证功能的权限检查
- 礼物发送的星星扣除
- 视频封面的生成和发送

### 7.2 集成测试

- 完整的验证流程
- 礼物发送和接收
- 视频带封面播放

---

## 八、依赖和限制

### 8.1 依赖

- 需要用户账号（非 Bot Token）进行验证操作
- 需要 Telegram Premium 用于某些礼物功能
- 星星支付系统需要配置

### 8.2 限制

- 验证功能需要组织权限
- 礼物发送有速率限制
- 视频封面有尺寸要求

---

## 九、参考资料

- [Telegram Bot API Changelog](https://core.telegram.org/bots/api-changelog)
- [Bot API 8.3 PR](https://github.com/eternnoir/pyTelegramBotAPI/pull/2453)
- [Bot API 8.2 PR](https://github.com/python-telegram-bot/python-telegram-bot/pull/4633)
- [Telegram Stars Gift Options](https://core.telegram.org/constructor/starsGiftOption)
