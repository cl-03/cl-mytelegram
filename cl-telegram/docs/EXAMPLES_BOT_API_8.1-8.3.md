# Bot API 8.1-8.3 使用示例

**版本**: 0.24.0  
**更新日期**: 2026-04-20

本文档展示如何使用 cl-telegram v0.24.0 中新增的 Bot API 8.1-8.3 功能。

---

## 目录

1. [验证功能 (Bot API 8.2)](#1-验证功能)
2. [礼物功能 (Bot API 8.3)](#2-礼物功能)
3. [视频增强 (Bot API 8.3)](#3-视频增强)
4. [业务功能 (Bot API 8.1)](#4-业务功能)
5. [服务消息反应 (Bot API 8.3)](#5-服务消息反应)

---

## 1. 验证功能

Bot API 8.2 新增了对用户和聊天的验证功能（添加 V 标）。

### 1.1 验证用户

```lisp
(use-package :cl-telegram/api)

;; 验证用户（添加 V 标）
(let ((result (verify-user 123456 :custom-description "Official account")))
  (when (verification-success result)
    (format t "Verification successful!~%")
    (format t "Description: ~A~%" (verification-description result))
    (format t "Verified by: ~A~%" (verification-verified-by result))))
```

### 1.2 验证频道

```lisp
;; 验证频道
(let ((result (verify-chat -1001234567890 
                           :custom-description "Verified channel")))
  (when (verification-success result)
    (format t "Channel verified successfully!~%")))
```

### 1.3 移除验证

```lisp
;; 移除用户验证
(remove-user-verification user-id)

;; 移除频道验证
(remove-chat-verification chat-id)
```

### 1.4 完整示例：验证管理机器人

```lisp
(defpackage #:verification-bot
  (:use #:cl #:cl-telegram/api))

(in-package #:verification-bot)

(defcommand "/verify" (chat-id args)
  "Verify a user or channel"
  (let* ((target (first args))
         (description (second args))
         (is-channel (and (string-prefix-p "@" target) target)))
    
    (let ((result (if is-channel
                      (verify-chat (parse-chat-username target)
                                   :custom-description description)
                      (verify-user (parse-username target)
                                   :custom-description description))))
      (if (verification-success result)
          (send-message chat-id "✅ Verification successful!")
          (send-message chat-id "❌ Verification failed")))))

(defcommand "/unverify" (chat-id args)
  "Remove verification from a user or channel"
  (let* ((target (first args))
         (is-channel (and (string-prefix-p "@" target) target)))
    
    (let ((success (if is-channel
                       (remove-chat-verification (parse-chat-username target))
                       (remove-user-verification (parse-username target)))))
      (send-message chat-id (if success "✅ Verification removed" "❌ Failed"))))
```

---

## 2. 礼物功能

Bot API 8.3 新增了付费礼物系统，支持向用户和频道发送礼物。

### 2.1 获取可用礼物

```lisp
;; 获取可用礼物列表
(let ((gifts (get-available-gifts)))
  (when gifts
    (format t "Available Gifts:~%")
    (dolist (gift (gifts-list gifts))
      (format t "  ~A~%" (gift-name gift))
      (format t "    Description: ~A~%" (gift-description gift))
      (format t "    Upgrade Cost: ~A stars~%" (gift-upgrade-star-count gift))
      (format t "    Total: ~A, Owners: ~A~%" 
              (gift-total-count gift)
              (gift-owner-count gift))
      (when (gift-is-limited gift)
        (format t "    ⚠️ Limited Edition~%"))
      (when (gift-is-exclusive gift)
        (format t "    ⭐ Exclusive~%")))))
```

### 2.2 发送礼物给用户

```lisp
;; 发送礼物给用户
(send-gift nil 
           :user-id 123456
           :gift-id "gift_1"
           :text "Congratulations! 🎉")

;; 发送付费升级礼物
(send-gift nil
           :user-id 123456
           :gift-id "gift_premium"
           :text "Upgrade to Premium!"
           :pay-for-upgrade t)
```

### 2.3 发送礼物给频道（Bot API 8.3 新增）

```lisp
;; 发送礼物到频道聊天
(send-gift nil
           :chat-id -1001234567890
           :gift-id "gift_channel"
           :text "From the community"
           :pay-for-upgrade nil)
```

### 2.4 完整示例：礼物商店

```lisp
(defpackage #:gift-shop-bot
  (:use #:cl #:cl-telegram/api))

(in-package #:gift-shop-bot)

(defvar *user-gifts* (make-hash-table :test 'equal)
  "Track user's purchased gifts")

(defcommand "/gifts" (chat-id args)
  "Show available gifts"
  (let ((gifts (get-available-gifts t)))  ; Force refresh
    (if gifts
        (let ((message "🎁 Available Gifts:~%"))
          (dolist (gift (gifts-list gifts))
            (setf message (format nil "~A~%🎁 ~A~%   Cost: ~A stars~%   ~A~%~%"
                                  message
                                  (gift-name gift)
                                  (gift-upgrade-star-count gift)
                                  (gift-description gift))))
          (send-message chat-id message :parse-mode :markdown))
        (send-message chat-id "No gifts available"))))

(defcommand "/sendgift" (chat-id args)
  "Send a gift to a user"
  (destructuring-bind (user-id gift-id &optional message) args
    (let* ((user (parse-user-argument user-id))
           (success (send-gift nil
                               :user-id user
                               :gift-id gift-id
                               :text (or message "Here's a gift for you!"))))
      (if success
          (send-message chat-id "✅ Gift sent!")
          (send-message chat-id "❌ Failed to send gift")))))

(defcommand "/giftstats" (chat-id args)
  "Show gift statistics"
  (let ((gifts (get-available-gifts)))
    (when gifts
      (let ((total (gifts-total-count gifts))
            (limited (count-if #'gift-is-limited (gifts-list gifts)))
            (exclusive (count-if #'gift-is-exclusive (gifts-list gifts))))
        (send-message chat-id 
                      (format nil "🎁 Gift Statistics~%
                      Total Gifts: ~A~%
                      Limited Editions: ~A~%
                      Exclusives: ~A"
                              total limited exclusive))))))
```

---

## 3. 视频增强

Bot API 8.3 新增了视频封面和开始时间戳功能。

### 3.1 发送带封面的视频

```lisp
;; 发送视频并指定封面
(send-video chat-id "video.mp4"
            :cover "cover.jpg"           ; 封面图片
            :start-timestamp 30          ; 从 30 秒开始播放
            :caption "Check out this video!"
            :duration 120
            :width 1920
            :height 1080)
```

### 3.2 转发视频并修改开始时间

```lisp
;; 转发视频并设置新的开始时间
(forward-message-with-timestamp chat-id 
                                from-chat-id 
                                message-id
                                :video-start-timestamp 15)
```

### 3.3 复制视频并修改封面

```lisp
;; 复制视频消息
(copy-message-with-timestamp chat-id
                             from-chat-id
                             message-id
                             :video-start-timestamp 0
                             :caption "New caption for copied video")
```

### 3.4 完整示例：视频编辑器机器人

```lisp
(defpackage #:video-editor-bot
  (:use #:cl #:cl-telegram/api))

(in-package #:video-editor-bot)

(defvar *user-videos* (make-hash-table :test 'equal)
  "Store user's video processing jobs")

(defun handle-video-message (message)
  "Process incoming video messages"
  (let* ((chat-id (getf (getf message :chat) :id))
         (video (getf message :video))
         (file-id (getf video :file-id))
         (duration (getf video :duration)))
    
    ;; Store video info
    (setf (gethash chat-id *user-videos*)
          (list :file-id file-id
                :duration duration
                :received (get-universal-time)))
    
    ;; Send options
    (send-message chat-id 
                  (format nil "📹 Video received (~A seconds)~%
                  What would you like to do?~%
                  /trim - Trim video~%
                  /addcover - Add custom cover"
                          duration)
                  :parse-mode :markdown)))

(defcommand "/trim" (chat-id args)
  "Trim video to specified duration"
  (destructuring-bind (start-second duration) args
    (let* ((video-info (gethash chat-id *user-videos*))
           (file-id (getf video-info :file-id)))
      (when file-id
        ;; Send trimmed video
        (send-video chat-id file-id
                    :start-timestamp (parse-integer start-second)
                    :caption (format nil "Trimmed from ~As" start-second))
        (send-message chat-id "✅ Video trimmed successfully")))))

(defcommand "/addcover" (chat-id args)
  "Add custom cover to video"
  (let ((video-info (gethash chat-id *user-videos*)))
    (when video-info
      (send-message chat-id "Please send the cover image"))))
```

---

## 4. 业务功能

Bot API 8.1 增强了业务相关功能。

### 4.1 获取业务连接信息

```lisp
;; 获取业务连接
(let ((connection (get-business-connection "business_conn_123")))
  (when connection
    (format t "Business Connection:~%")
    (format t "  ID: ~A~%" (business-connection-id connection))
    (format t "  User: ~A~%" (business-connection-user-chat-id connection))
    (format t "  Username: ~A~%" (business-connection-user-username connection))
    (format t "  Can Reply: ~A~%" (business-connection-can-reply connection))
    (format t "  Enabled: ~A~%" (business-connection-is-enabled connection))))
```

### 4.2 获取业务介绍

```lisp
;; 获取用户的业务介绍
(let ((intro (get-business-intro user-id)))
  (when intro
    (format t "Business Intro:~%")
    (format t "  Title: ~A~%" (business-intro-title intro))
    (format t "  Message: ~A~%" (business-intro-message intro))
    (when (business-intro-sticker-id intro)
      (format t "  Sticker: ~A~%" (business-intro-sticker-id intro)))))
```

### 4.3 获取业务地址

```lisp
;; 获取业务地址
(let ((location (get-business-location user-id)))
  (when location
    (format t "Business Location:~%")
    (format t "  Name: ~A~%" (business-location-name location))
    (format t "  Address: ~A~%" (business-location-address location))
    (format t "  Coordinates: ~A, ~A~%" 
            (business-location-latitude location)
            (business-location-longitude location))))
```

### 4.4 获取营业时间

```lisp
;; 获取营业时间
(let ((hours (get-business-opening-hours user-id)))
  (when hours
    (format t "Business Hours:~%")
    (format t "  Schedule: ~A~%" (business-opening-hours-schedule hours))
    (format t "  Timezone: ~A~%" (business-opening-hours-timezone hours))
    (dolist (interval (business-opening-hours-intervals hours))
      (let ((start (business-interval-start-minute interval))
            (end (business-interval-end-minute interval)))
        (format t "  ~A:~A - ~A:~A~%" 
                (floor start 60) (mod start 60)
                (floor end 60) (mod end 60))))))
```

---

## 5. 服务消息反应

Bot API 8.3 允许对大多数服务消息类型添加反应。

### 5.1 对服务消息添加反应

```lisp
;; 对服务消息添加反应（Bot API 8.3+）
(send-service-message-reaction chat-id 
                               service-message-id 
                               "👍")

;; 添加大动画反应
(send-service-message-reaction chat-id
                               service-message-id
                               "🎉"
                               :is-big t)

;; 使用自定义 emoji
(send-service-message-reaction chat-id
                               service-message-id
                               (make-reaction-type-custom-emoji "custom_emoji_id"))
```

### 5.2 完整示例：欢迎机器人

```lisp
(defpackage #:welcome-bot
  (:use #:cl #:cl-telegram/api))

(in-package #:welcome-bot)

(defun handle-new-member (message)
  "Handle new member service messages"
  (let* ((chat-id (getf (getf message :chat) :id))
         (msg-id (getf message :id))
         (new-members (getf message :new-chat-members)))
    
    ;; Add reaction to new member message
    (send-service-message-reaction chat-id msg-id "👋")
    
    ;; Welcome each new member
    (dolist (member new-members)
      (let ((user-id (getf member :id))
            (username (getf member :username)))
        (send-message chat-id 
                      (format nil "Welcome @~A! 👋" 
                              (or username user-id)))))))

;; Register handler
(register-update-handler
  (lambda (update)
    (let ((message (getf update :message)))
      (when (and message (getf message :new-chat-members))
        (handle-new-member message)))))
```

---

## 6. 最佳实践

### 6.1 缓存管理

```lisp
;; 清除业务连接缓存
(clear-business-connection-cache)

;; 清除礼物缓存
(clear-gifts-cache)

;; 检查缓存状态
(when (business-connection-cached-p business-id)
  ;; Use cached data
  )
```

### 6.2 错误处理

```lisp
(handler-case
    (let ((result (verify-user user-id :custom-description "Official")))
      (if (verification-success result)
          (format t "Verified!~%")
          (format t "Verification failed: ~A~%" 
                  (verification-description result))))
  (condition (e)
    (log:error "Verification error: ~A" e)))
```

### 6.3 权限检查

```lisp
(defun can-verify-user-p (bot-user-id target-user-id)
  "Check if bot can verify target user"
  ;; Implementation depends on your bot's permission system
  t)

(defun before-verify (user-id)
  "Pre-verification check"
  (unless (can-verify-user-p *bot-id* user-id)
    (error "Insufficient permissions to verify this user")))
```

---

## 7. 参考资料

- [Bot API 8.1-8.3 实现计划](docs/BOT_API_UPDATES_8.1-8.3.md)
- [Bot API 官方更新日志](https://core.telegram.org/bots/api-changelog)
- [Bot API 8.0 示例](docs/EXAMPLES_BOT_API_8.md)
