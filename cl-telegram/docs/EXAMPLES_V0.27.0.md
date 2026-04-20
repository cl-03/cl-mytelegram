# v0.27.0 使用示例

本目录包含 cl-telegram v0.27.0 新增功能的使用示例。

## 目录

1. [自动删除消息](#1-自动删除消息)
2. [聊天备份导出](#2-聊天备份导出)
3. [全局搜索](#3-全局搜索)
4. [媒体库](#4-媒体库)
5. [个性化主题](#5-个性化主题)

---

## 1. 自动删除消息

### 1.1 基本用法

```lisp
;; 设置消息在 60 秒后自动删除
(set-message-timer chat-id message-id 60)

;; 取消消息定时器
(cancel-message-timer chat-id message-id)

;; 获取剩余时间（秒）
(get-message-timer-remaining chat-id message-id)
```

### 1.2 聊天默认定时器

```lisp
;; 设置聊天默认定时器（所有新消息自动 5 分钟后删除）
(set-chat-default-timer chat-id 300)

;; 获取聊天默认定时器
(get-chat-default-timer chat-id)

;; 清除聊天默认定时器
(clear-chat-default-timer chat-id)
```

### 1.3 发送带自动删除的消息

```lisp
;; 发送消息并设置 1 小时后删除
(send-message-with-auto-delete chat-id "这是一条会自动消失的消息"
                                :timer-seconds 3600)

;; 静默删除（不显示系统消息）
(send-message-with-auto-delete chat-id "秘密消息"
                                :timer-seconds 300
                                :silent t)
```

### 1.4 启动后台监控

```lisp
;; 启动自动删除监控线程（每分钟清理一次）
(start-auto-delete-monitor :cleanup-interval 60)

;; 停止监控
(stop-auto-delete-monitor)

;; 获取统计信息
(get-auto-delete-stats)
```

### 1.5 管理活动定时器

```lisp
;; 列出所有活动定时器
(list-active-timers)

;; 清理已过期的定时器
(cleanup-expired-timers)
```

---

## 2. 聊天备份导出

### 2.1 导出聊天记录

```lisp
;; 导出为 JSON 格式
(export-chat-history chat-id "/path/to/backup.json"
                     :format :json)

;; 导出为 HTML 格式（可在浏览器中查看）
(export-chat-history chat-id "/path/to/backup.html"
                     :format :html)

;; 导出时包含媒体文件
(export-chat-history chat-id "/path/to/backup.json"
                     :include-media t)

;; 按日期范围导出
(export-chat-history chat-id "/path/to/backup.json"
                     :date-from 1700000000
                     :date-to 1700100000)
```

### 2.2 导出所有聊天

```lisp
;; 导出所有聊天记录到目录
(export-all-chats "/path/to/backup/dir"
                  :format :json
                  :include-media nil)
```

### 2.3 导入聊天记录

```lisp
;; 从备份恢复（覆盖现有聊天）
(import-chat-history "/path/to/backup.json")

;; 从备份恢复（合并到现有聊天）
(import-chat-history "/path/to/backup.json"
                     :merge t)
```

### 2.4 增量备份

```lisp
;; 基于之前的备份创建增量备份
(create-incremental-backup chat-id
                           "/path/to/base-backup.json"
                           "/path/to/incremental-backup.json"
                           :format :json)
```

### 2.5 查看备份信息

```lisp
;; 获取备份文件信息
(get-backup-info "/path/to/backup.json")
;; 返回：(:backup-id "..." :chat-id 123 :message-count 1000 :export-date ... :format :json)
```

---

## 3. 全局搜索

### 3.1 基本搜索

```lisp
;; 跨所有聊天搜索
(global-search-messages "关键词")

;; 限制结果数量
(global-search-messages "关键词" :limit 100)
```

### 3.2 按条件过滤

```lisp
;; 按发送者搜索
(global-search-messages "关键词"
                        :sender-id 123456)

;; 按日期范围搜索
(global-search-messages "关键词"
                        :date-from 1700000000
                        :date-to 1700100000)

;; 在特定聊天中搜索
(global-search-messages "关键词"
                        :chat-ids '(123456 789012))

;; 按媒体类型过滤
(global-search-messages "关键词"
                        :media-type :photo)

;; 只搜索包含媒体的消息
(global-search-messages "关键词"
                        :has-media t)
```

### 3.3 聊天内搜索

```lisp
;; 在指定聊天中搜索
(search-in-chat chat-id "关键词"
                :limit 50)
```

### 3.4 搜索建议

```lisp
;; 获取搜索建议
(get-search-suggestions "hel"
                        :limit 5)
```

### 3.5 高亮搜索结果

```lisp
;; 高亮匹配文本
(highlight-search-result "Hello world" "hello")
;; 返回："**Hello** world"

;; 限制长度
(highlight-search-result "这是一段很长的文本" "文本"
                         :max-length 20)
```

### 3.6 按条件搜索

```lisp
;; 按发送者搜索
(search-messages-by-sender user-id
                           :chat-ids '(123456)
                           :limit 50)

;; 按日期范围搜索
(search-messages-by-date-range date-from date-to
                               :chat-ids '(123456)
                               :limit 50)

;; 按媒体类型搜索
(search-messages-by-media-type :video
                               :limit 50)
```

### 3.7 缓存管理

```lisp
;; 获取缓存统计
(get-search-cache-stats)

;; 清除搜索缓存
(clear-search-cache)

;; 设置缓存 TTL（秒）
(set-search-cache-ttl 600)

;; 搜索时不使用缓存
(global-search-messages "关键词"
                        :use-cache nil)
```

### 3.8 搜索历史

```lisp
;; 获取搜索历史
(get-search-history)

;; 清除搜索历史
(clear-search-history)
```

---

## 4. 媒体库

### 4.1 浏览媒体

```lisp
;; 获取所有照片
(get-all-photos :limit 100)

;; 获取所有视频
(get-all-videos :limit 50)

;; 获取所有文档
(get-all-documents :limit 100)

;; 获取所有音频文件
(get-all-audio :limit 100)

;; 获取所有文件
(get-all-files :limit 200)
```

### 4.2 按聊天过滤

```lisp
;; 获取特定聊天的照片
(get-all-photos :chat-id 123456 :limit 50)

;; 获取特定聊天的指定类型媒体
(get-chat-media :chat-id 123456
                :type :video
                :limit 50)
```

### 4.3 搜索文件

```lisp
;; 按文件名搜索
(search-files "report.pdf"
              :type :document
              :limit 20)

;; 按扩展名搜索
(search-files ".jpg"
              :limit 100)
```

### 4.4 批量操作

```lisp
;; 批量下载媒体
(download-media-batch '(media-id-1 media-id-2 media-id-3)
                      "/path/to/download/dir"
                      :overwrite nil)

;; 批量删除媒体
(delete-media-batch '(media-id-1 media-id-2 media-id-3))
```

### 4.5 媒体统计

```lisp
;; 获取总体统计
(get-media-statistics)
;; 返回：(:total-photos 1000 :total-videos 200 :total-documents 500 :total-audio 150)

;; 按聊天查看使用情况
(get-media-usage-by-chat :limit 10)

;; 按类型查看使用情况
(get-media-usage-by-type)
```

### 4.6 媒体排序和分组

```lisp
;; 按日期排序
(sort-media-by-date media-list
                    :descending t)  ; 降序

;; 按月份分组
(group-media-by-month media-list)
```

### 4.7 获取单个媒体

```lisp
;; 获取媒体项目详情
(get-media-item media-id)
```

### 4.8 缓存管理

```lisp
;; 获取缓存统计
(get-media-cache-stats)

;; 清除媒体缓存
(clear-media-cache)

;; 设置缓存 TTL
(set-media-cache-ttl 600)
```

### 4.9 工具函数

```lisp
;; 检测媒体类型
(detect-media-type "photo.jpg")  ; => :photo
(detect-media-type "video.mp4")  ; => :video

;; 获取文件扩展名
(get-file-extension "file.tar.gz")  ; => "gz"

;; 导出媒体列表
(export-media-list media-list "/path/to/export.json")
```

---

## 5. 个性化主题

### 5.1 管理主题

```lisp
;; 列出所有主题
(list-themes)
;; 返回："default" "dark" "midnight" "ocean" "forest" "sunset"

;; 获取主题详情
(get-theme "dark")

;; 创建新主题
(create-theme "my-theme"
              :base-theme :dark)

;; 删除主题
(delete-theme "my-theme")
```

### 5.2 自定义颜色

```lisp
;; 设置主题颜色
(set-theme-color "my-theme" :primary "#FF5500")
(set-theme-color "my-theme" :background "#1a1a1a")
(set-theme-color "my-theme" :text "#FFFFFF")

;; 获取主题所有颜色
(get-theme-colors "my-theme")
```

### 5.3 应用主题

```lisp
;; 应用主题
(apply-theme "midnight")

;; 应用预设主题
(apply-theme-preset "ocean")

;; 获取当前主题
(get-theme-stats)  ; 查看 :active-theme
```

### 5.4 聊天背景

```lisp
;; 设置聊天背景（颜色）
(set-chat-background chat-id "#FF5500"
                     :blur 10
                     :darken 0.3
                     :opacity 0.8)

;; 设置聊天背景（图片）
(set-chat-background chat-id "path/to/image.jpg"
                     :blur 5)

;; 获取聊天背景
(get-chat-background chat-id)

;; 重置聊天背景
(reset-chat-background chat-id)
```

### 5.5 字体和图标

```lisp
;; 设置字体大小
(set-font-size :large)  ; 可选：:small :normal :large :xl

;; 设置应用图标
(set-app-icon "custom-icon")
```

### 5.6 导入导出主题

```lisp
;; 导出主题
(export-theme "my-theme" "/path/to/theme.json")

;; 导入主题
(import-theme "/path/to/theme.json")
```

### 5.7 主题统计

```lisp
;; 获取主题统计
(get-theme-stats)
;; 返回：(:themes-count 8 :active-theme :midnight :font-size :large :app-icon "default")
```

---

## 6. 完整示例

### 6.1 隐私聊天清理

```lisp
;; 设置聊天自动删除
(defun setup-private-chat (chat-id)
  ;; 设置默认 5 分钟删除
  (set-chat-default-timer chat-id 300)

  ;; 应用深色主题
  (set-chat-background chat-id "#0a0a1a" :blur 10 :darken 0.5)

  (format t "私密聊天 ~A 已配置~%" chat-id))
```

### 6.2 聊天归档工作流

```lisp
(defun archive-chat (chat-id backup-dir)
  "归档聊天记录到本地"
  (let ((backup-path (format nil "~A/~A-~A.json"
                             backup-dir
                             chat-id
                             (get-universal-time))))
    ;; 导出聊天
    (export-chat-history chat-id backup-path
                         :format :json
                         :include-media nil)

    ;; 验证备份
    (let ((info (get-backup-info backup-path)))
      (format t "归档完成：~A 条消息~%"
              (getf info :message-count)))
    backup-path))
```

### 6.3 媒体清理工作流

```lisp
(defun cleanup-old-media (&key (days-old 30))
  "清理指定天数之前的媒体文件"
  (let* ((cutoff (- (get-universal-time) (* days-old 24 60 60)))
         (all-media (get-all-files :limit 1000))
         (old-media (remove-if-not
                     (lambda (m)
                       (and (media-date m)
                            (< (media-date m) cutoff)))
                     all-media)))
    (format t "发现 ~A 个过期媒体文件~%" (length old-media))
    (when (> (length old-media) 0)
      (delete-media-batch (mapcar #'media-id old-media))
      (format t "已删除 ~A 个文件~%" (length old-media)))))
```

---

## API 参考

完整 API 函数列表请参阅 `docs/API_REFERENCE_v0.27.0.md`。

## 测试

运行所有 v0.27.0 测试：

```lisp
;; 在 REPL 中
(asdf:load-system :cl-telegram/tests)
(in-package #:cl-telegram/tests)

;; 运行特定测试套件
(run! 'auto-delete-suite)
(run! 'chat-backup-suite)
(run! 'global-search-suite)
(run! 'media-library-suite)
(run! 'custom-themes-suite)
```
