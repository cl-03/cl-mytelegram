# Bot API 8.0 和图像处理使用示例

本文件展示如何使用 cl-telegram v0.23.0 的 Bot API 8.0 功能和图像处理功能。

## 目录

1. [消息反应 (Message Reactions)](#1-消息反应)
2. [Emoji 状态](#2-emoji-状态)
3. [高级媒体编辑](#3-高级媒体编辑)
4. [Story Highlights](#4-story-highlights)
5. [消息翻译](#5-消息翻译)
6. [图像处理滤镜](#6-图像处理滤镜)
7. [综合示例：自动 moderation 机器人](#7-综合示例)

---

## 1. 消息反应

### 基础用法

```lisp
(use-package :cl-telegram/api)

;; 发送 emoji 反应
(send-message-reaction chat-id message-id "👍")

;; 发送多个反应
(send-message-reaction chat-id message-id "❤️" :is-big t)

;; 使用自定义 emoji 反应 (Premium)
(send-message-reaction chat-id message-id 
                       (make-reaction-type-custom-emoji "custom_emoji_id"))

;; 使用星形反应 (Premium)
(send-message-reaction chat-id message-id (make-reaction-type-star))
```

### 获取反应详情

```lisp
;; 获取消息的反应列表
(let ((reactions (get-message-reactions chat-id message-id)))
  (dolist (reaction reactions)
    (format t "Reaction: ~A, Count: ~A~%" 
            (reaction-count-reaction reaction)
            (reaction-count-count reaction))))

;; 移除某个反应
(remove-message-reaction chat-id message-id "👍")

;; 移除所有反应
(remove-message-reaction chat-id message-id)
```

### 注册反应更新处理器

```lisp
;; 注册全局反应更新处理器
(on-message-reaction 
  (lambda (chat-id msg-id old-reaction new-reaction)
    (format t "Reaction changed in chat ~A, message ~A~%" chat-id msg-id)
    (format t "  Old: ~A -> New: ~A~%" old-reaction new-reaction)))

;; 注册特定聊天处理
(on-message-reaction 
  (lambda (chat-id msg-id old new)
    (when (string= old "👍")
      (format t "Thumbs up reaction detected!~%")))
  -1001234567890)  ; 特定聊天 ID

;; 注销处理器
(unregister-reaction-handler handler-id)
```

---

## 2. Emoji 状态

### 设置用户状态

```lisp
;; 设置标准 emoji 状态
(set-emoji-status "🔥")

;; 设置自定义 emoji 状态 (Premium)
(set-emoji-status "custom_emoji_id")

;; 设置临时状态 (1 小时后清除)
(set-emoji-status "⭐" :duration-seconds 3600)

;; 设置状态 (24 小时)
(set-emoji-status "🌙" :duration-seconds 86400)
```

### 获取和清除状态

```lisp
;; 获取可用 emoji 状态
(let ((statuses (get-emoji-statuses)))
  (dolist (status statuses)
    (format t "Emoji: ~A, Premium: ~A~%" 
            (emoji-status-emoji status)
            (emoji-status-is-premium status))))

;; 获取特定用户状态
(get-user-emoji-status user-id)

;; 清除自己的状态
(clear-emoji-status)
```

---

## 3. 高级媒体编辑

### 裁剪和旋转

```lisp
(use-package :cl-telegram/image-processing)

;; 裁剪图片
(crop-media "photo.jpg" :x 100 :y 100 :width 500 :height 500)

;; 旋转图片 (90 度)
(rotate-media "photo.jpg" :angle 90)

;; 旋转 180 度
(rotate-media "photo.jpg" :angle 180)
```

### 应用滤镜

```lisp
;; 应用 Instagram 风格滤镜
(apply-media-filter "photo.jpg" "clarendon" :intensity 0.8)

;; 尝试不同滤镜
(dolist (filter '("ginger" "moon" "nashville" "perpetua"))
  (apply-media-filter "photo.jpg" filter :intensity 0.7))

;; 获取所有可用滤镜
(get-available-filters)
;; => ("clarendon" "ginger" "moon" "nashville" ...)
```

### 添加文本和 emoji

```lisp
;; 添加文本叠加
(add-text-overlay "meme.jpg" "TOP TEXT" 
                  :x 50 :y 20
                  :font-size 48
                  :color :white)

;; 添加底部文字
(add-text-overlay "meme.jpg" "BOTTOM TEXT"
                  :position :bottom
                  :font-size 48
                  :color :white
                  :background '(0 0 0))

;; 添加 emoji 贴纸
(add-emoji-sticker "photo.jpg" "😀"
                   :x 100 :y 100
                   :size 64
                   :opacity 0.9)

;; 添加水印
(add-watermark "photo.jpg" "© 2024 My Brand"
               :position :bottom-right
               :opacity 0.5
               :font-size 16)
```

### 编辑消息

```lisp
;; 编辑消息的媒体
(edit-message-media-advanced chat-id message-id "new_photo.jpg"
                             :options (make-instance 'media-edit-options
                                                     :caption "新标题"
                                                     :filter-type "clarendon"))

;; 仅编辑标题
(edit-message-caption chat-id message-id "Updated caption"
                      :parse-mode :html)

;; 带 HTML 格式的标题
(edit-message-caption chat-id message-id 
                      "<b>Bold text</b> and <i>italic text</i>"
                      :parse-mode :html)
```

---

## 4. Story Highlights

### 创建和管理 Highlights

```lisp
;; 创建 highlight
(create-highlight "Travel 2024"
                  :cover-media "cover.jpg"
                  :story-ids '(1 2 3 4)
                  :privacy :public)

;; 创建私密 highlight
(create-highlight "Family"
                  :cover-media "family_cover.jpg"
                  :story-ids '(10 11 12)
                  :privacy :contacts)

;; 创建 close friends highlight
(create-highlight "Close Friends Only"
                  :privacy :close-friends)
```

### 编辑 Highlights

```lisp
;; 编辑标题
(edit-highlight highlight-id :title "Updated Title")

;; 编辑封面
(edit-highlight-cover highlight-id "new_cover.jpg"
                      :filter "clarendon")

;; 添加更多 stories
(add-stories-to-highlight highlight-id '(5 6 7))

;; 重新排序
(reorder-highlights '(3 1 4 2))
```

### 获取和删除

```lisp
;; 获取自己的 highlights
(get-highlights)

;; 获取其他用户的 highlights
(get-highlights user-id)

;; 删除 highlight
(delete-highlight highlight-id)

;; 设置隐私
(set-highlight-privacy highlight-id :custom)
```

---

## 5. 消息翻译

### 翻译消息

```lisp
;; 翻译单条消息
(let ((result (translate-message chat-id message-id 
                                 :target-language "zh")))
  (when result
    (format t "Original: ~A~%" (translation-original-text result))
    (format t "Translated: ~A~%" (translation-translated-text result))
    (format t "Detected: ~A~%" (translation-source-language result))))
```

### 翻译文本

```lisp
;; 翻译任意文本
(translate-text "Hello, how are you?"
                :from-language "en"
                :to-language "zh")

;; 自动检测源语言
(translate-text "Bonjour tout le monde!"
                :to-language "en")
```

### 语言设置

```lisp
;; 设置聊天语言偏好
(set-chat-language chat-id "zh")

;; 启用自动翻译
(enable-auto-translation chat-id :target-language "en")

;; 禁用自动翻译
(disable-auto-translation chat-id)

;; 检查是否启用
(auto-translation-enabled-p chat-id)
```

### 支持的语言

```lisp
;; 获取支持的语言列表
(let ((languages (get-supported-languages)))
  (dolist (lang languages)
    (format t "~A: ~A~%" (car lang) (cdr lang))))

;; 输出:
;; af: Afrikaans
;; ar: Arabic
;; zh: Chinese
;; en: English
;; ...
```

---

## 6. 图像处理滤镜

### 基础滤镜

```lisp
(use-package :cl-telegram/image-processing)

;; 加载图片
(let ((image (load-image "photo.jpg")))
  (when image
    ;; 灰度
    (save-image (apply-grayscale image) "gray.jpg")
    
    ;; Sepia
    (save-image (apply-sepia image :intensity 0.8) "sepia.jpg")
    
    ;; 亮度调整
    (save-image (apply-brightness image 50) "brighter.jpg")
    
    ;; 对比度调整
    (save-image (apply-contrast image 30) "contrast.jpg")
    
    ;; 饱和度调整
    (save-image (apply-saturation image -20) "desaturated.jpg")))
```

### 艺术滤镜

```lisp
(let ((image (load-image "photo.jpg")))
  (when image
    ;; 模糊
    (save-image (apply-blur image :radius 3) "blurred.jpg")
    
    ;; 锐化
    (save-image (apply-sharpen image :amount 1.5) "sharpened.jpg")
    
    ;; 晕影
    (save-image (apply-vignette image :darkness 0.5) "vignette.jpg")
    
    ;; 噪点
    (save-image (apply-noise image :amount 15) "noisy.jpg")
    
    ;; 像素化
    (save-image (apply-pixelate image :pixel-size 8) "pixelated.jpg")))
```

### Instagram 滤镜

```lisp
(let ((image (load-image "portrait.jpg")))
  (when image
    ;; 批量应用滤镜
    (dolist (filter '("clarendon" "ginger" "moon" "nashville"
                      "perpetua" "aden" "reyes" "juno"))
      (let ((filtered (apply-filter-by-name image filter :intensity 0.8)))
        (save-image filtered (format nil "portrait.~A.jpg" filter))))))

;; 使用特定滤镜函数
(let ((image (load-image "photo.jpg")))
  (save-image (filter-clarendon image :intensity 1.0) "clarendon.jpg")
  (save-image (filter-moon image :intensity 1.0) "moon.jpg")
  (save-image (filter-vintage image :intensity 0.7) "vintage.jpg"))
```

### 缩略图生成

```lisp
;; 生成缩略图
(let ((image (load-image "large_photo.jpg")))
  (when image
    (generate-thumbnail image 150 150
                        :output-path "thumb.jpg")))

;; 批量生成缩略图
(dolist (file '("photo1.jpg" "photo2.jpg" "photo3.jpg"))
  (let ((image (load-image file)))
    (when image
      (generate-thumbnail image 200 200
                          :output-path (format nil "thumb_~A" file)))))
```

### 绘图原语

```lisp
(let ((image (make-instance 'opticl:rgba-image :width 200 :height 200)))
  ;; 填充白色背景
  (dotimes (y 200)
    (dotimes (x 200)
      (opticl:set-pixel image x y 255 255 255 255)))
  
  ;; 画红色矩形
  (draw-rectangle image 50 50 100 100 
                  :color '(255 0 0) 
                  :filled t)
  
  ;; 画绿色圆形
  (draw-circle image 100 100 50 
               :color '(0 255 0) 
               :filled t)
  
  (save-image image "drawing.png"))
```

---

## 7. 综合示例

### 示例 1: 自动 moderation 机器人

```lisp
(defpackage #:mybot
  (:use #:cl #:cl-telegram/api))

(in-package #:mybot)

;; 注册消息处理器
(register-update-handler
  (lambda (update)
    (let* ((message (getf update :message))
           (text (getf message :text))
           (chat-id (getf (getf message :chat) :id))
           (msg-id (getf message :id)))
      
      ;; 检测不当词汇
      (when (and text (find-if (lambda (word) (search word text ' :test 'string=))
                               '("spam" "scam" "fake")))
        ;; 添加警告反应
        (send-message-reaction chat-id msg-id "⚠️")
        
        ;; 翻译消息进行审核
        (let ((translation (translate-message chat-id msg-id 
                                              :target-language "en")))
          (when translation
            (send-message chat-id 
                          (format t "⚠️ Message flagged for review.~%Translation: ~A"
                                  (translation-translated-text translation)))))))))
```

### 示例 2: 图片滤镜机器人

```lisp
(in-package #:mybot)

(defvar *user-filters* (make-hash-table :test 'equal)
  "Store user's filter preferences")

(defun handle-photo-message (message)
  "Process incoming photo messages"
  (let* ((chat-id (getf (getf message :chat) :id))
         (msg-id (getf message :id))
         (photo (getf message :photo)))
    
    ;; 下载照片
    (let ((file-path (download-file photo)))
      (when file-path
        ;; 获取用户选择的滤镜
        (let ((filter (gethash chat-id *user-filters* "clarendon")))
          ;; 应用滤镜
          (let ((filtered (apply-media-filter file-path filter :intensity 0.8)))
            (when filtered
              ;; 发送处理后的照片
              (send-photo chat-id filtered)
              ;; 添加反应
              (send-message-reaction chat-id msg-id "✨"))))))))

;; 命令处理器
(setup-basic-commands)

(defcommand "/filter" (chat-id args)
  "Set filter for next photo"
  (let ((filter-name (first args)))
    (if (member filter-name (get-available-filters) :test #'string=)
        (progn
          (setf (gethash chat-id *user-filters*) filter-name)
          (send-message chat-id (format nil "Filter set to: ~A" filter-name)))
        (send-message chat-id 
                      (format nil "Available filters: ~{~A~^, ~}" 
                              (get-available-filters))))))

(defcommand "/filters" (chat-id args)
  "List available filters"
  (send-message chat-id 
                (format nil "Available filters:~%~{~A~%}" 
                        (get-available-filters))))
```

### 示例 3: 多语言聊天机器人

```lisp
(in-package #:mybot)

(defvar *chat-translations* (make-hash-table :test 'equal)
  "Track which chats have translation enabled")

(defun process-incoming-message (message)
  "Process incoming message with auto-translation"
  (let* ((chat-id (getf (getf message :chat) :id))
         (text (getf message :text))
         (target-lang (gethash chat-id *chat-translations*)))
    
    (when (and text target-lang)
      (let ((translation (translate-text text :to-language target-lang)))
        (when translation
          ;; 发送翻译后的消息
          (send-message chat-id 
                        (format nil "~A~%---~%[Translation: ~A]"
                                text
                                (translation-translated-text translation))))))))

;; 命令：启用翻译
(defcommand "/translate" (chat-id args)
  "Enable translation for this chat"
  (let ((lang (or (first args) "en")))
    (setf (gethash chat-id *chat-translations*) lang)
    (send-message chat-id 
                  (format nil "Translation enabled. Target: ~A" lang))))

;; 命令：禁用翻译
(defcommand "/notranslate" (chat-id args)
  "Disable translation for this chat"
  (remhash chat-id *chat-translations*)
  (send-message chat-id "Translation disabled."))

;; 命令：列出支持的语言
(defcommand "/languages" (chat-id args)
  "List supported languages"
  (let ((languages (get-supported-languages)))
    (send-message chat-id 
                  (format nil "Supported languages:~%~{~A: ~A~%~}" 
                          languages))))
```

### 示例 4: Story 管理器

```lisp
(in-package #:mybot)

(defun manage-story-highlights ()
  "Manage story highlights for the bot's account"
  
  ;; 创建旅行 highlight
  (let ((travel-highlight (create-highlight "✈️ Travel"
                                            :cover-media "travel_cover.jpg"
                                            :privacy :public)))
    (when travel-highlight
      ;; 添加 stories
      (add-stories-to-highlight (story-highlight-id travel-highlight)
                                '(1 2 3 4 5))))
  
  ;; 创建幕后 highlight
  (create-highlight "🎬 Behind the Scenes"
                    :privacy :contacts)
  
  ;; 获取并显示所有 highlights
  (let ((highlights (get-highlights)))
    (dolist (highlight highlights)
      (format t "Highlight: ~A~%" (story-highlight-title highlight))
      (format t "  Stories: ~A~%" (length (story-highlight-stories highlight)))
      (format t "  Privacy: ~A~%" (story-highlight-privacy highlight)))))
```

---

## 8. 最佳实践

### 错误处理

```lisp
(handler-case
    (let ((image (load-image "photo.jpg")))
      (if image
          (let ((filtered (filter-clarendon image)))
            (save-image filtered "output.jpg"))
          (format t "Failed to load image~%")))
  (condition (e)
    (log:error "Image processing error: ~A" e)))
```

### 性能优化

```lisp
;; 使用缓存避免重复处理
(defvar *filter-cache* (make-hash-table :test 'equal))

(defun get-filtered-image (image-path filter-name)
  (let ((cache-key (format nil "~A-~A" image-path filter-name)))
    (or (gethash cache-key *filter-cache*)
        (let* ((image (load-image image-path))
               (filtered (apply-filter-by-name image filter-name)))
          (setf (gethash cache-key *filter-cache*) filtered)
          filtered))))

;; 定期清理缓存
(defun cleanup-filter-cache ()
  (clr-hash *filter-cache*))
```

### 批量处理

```lisp
(defun batch-process-images (files filter-name output-dir)
  "Process multiple images with the same filter"
  (let ((count 0)
        (errors 0))
    (dolist (file files)
      (handler-case
          (let* ((image (load-image file))
                 (filtered (apply-filter-by-name image filter-name))
                 (output (merge-pathnames output-dir 
                                          (make-pathname :name (pathname-name file)
                                                         :type filter-name))))
            (save-image filtered output)
            (incf count))
        (condition (e)
          (log:error "Failed to process ~A: ~A" file e)
          (incf errors))))
    (format t "Processed ~A images, ~A errors~%" count errors)))
```

---

## 9. 故障排查

### 常见问题

**Q: 滤镜不生效？**
```lisp
;; 检查滤镜名称
(get-available-filters)  ; 确认滤镜存在

;; 检查图像加载
(let ((image (load-image "photo.jpg")))
  (if image
      (format t "Loaded: ~Ax~A~%" (image-width image) (image-height image))
      (format t "Failed to load~%")))
```

**Q: 文本叠加不显示？**
```lisp
;; 当前实现是 placeholder，需要集成 cl-freetype
;; 使用 Telegram 原生文本渲染作为替代
(add-text-overlay "image.jpg" "Test")  ; 会记录请求
```

**Q: 反应不显示？**
```lisp
;; 检查连接状态
(ensure-auth-connection)

;; 检查消息是否存在
(get-messages chat-id (list message-id))
```

---

## 10. 参考资料

- [Bot API 8.0 官方文档](https://core.telegram.org/bots/api-changelog)
- [Opticl 文档](https://github.com/rabbibotton/opticl)
- [cl-telegram API 参考](docs/API_REFERENCE.md)
- [发布说明](docs/RELEASE_NOTES_v0.23.0.md)
