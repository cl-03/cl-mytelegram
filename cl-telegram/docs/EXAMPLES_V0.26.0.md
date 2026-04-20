# cl-telegram v0.26.0 使用示例

本文档提供 cl-telegram v0.26.0 新功能的完整使用示例。

## 目录

1. [群组视频通话](#1-群组视频通话)
2. [视频消息](#2-视频消息)
3. [媒体合集管理](#3-媒体合集管理)
4. [完整应用示例](#4-完整应用示例)

---

## 1. 群组视频通话

### 1.1 初始化和基本使用

```lisp
;; 加载系统
(asdf:load-system :cl-telegram)
(use-package :cl-telegram/api)

;; 初始化群组视频子系统
(init-group-video 
  :max-participants 10      ; 最多 10 人
  :default-quality :hd      ; 默认高清质量
  :recording-dir "~/telegram-recordings/")  ; 录制文件目录
```

### 1.2 开始视频通话

```lisp
;; 创建群组通话
(multiple-value-bind (call-info error)
    (create-group-call chat-id :is-video-chat t :title "团队会议")
  (if error
      (format t "创建通话失败：~A~%" error)
      (let ((group-call-id (getf call-info :group-call-id)))
        
        ;; 加入通话
        (join-group-call group-call-id)
        
        ;; 启动视频流
        (multiple-value-bind (stream-id err)
            (start-group-video-stream group-call-id 
                                      :resolution :hd 
                                      :fps 30)
          (if err
              (format t "启动视频失败：~A~%" err)
              (format t "视频流已启动：~A~%" stream-id)))
        
        group-call-id)))
```

### 1.3 屏幕共享

```lisp
;; 启用屏幕共享
(multiple-value-bind (stream-id error)
    (enable-screen-sharing group-call-id 
                           :quality :screen
                           :capture-window nil  ; nil = 全屏
                           :capture-monitor nil) ; nil = 主显示器
  (if error
      (format t "屏幕共享失败：~A~%" error)
      (format t "屏幕共享已启动：~A~%" stream-id)))

;; 停止屏幕共享
(disable-screen-sharing group-call-id)
```

### 1.4 视频质量调整

```lisp
;; 根据带宽自动调整
(set-video-quality group-call-id :auto)

;; 手动设置质量
(set-video-quality group-call-id :hd)  ; :ld :sd :hd :fhd

;; 获取当前质量
(let ((quality (get-video-quality group-call-id)))
  (format t "当前视频质量：~A~%" quality))
```

### 1.5 视频布局管理

```lisp
;; 获取当前布局
(let ((layout (get-group-video-layout group-call-id)))
  (format t "布局类型：~A~%" (getf layout :type))
  (format t "参与者：~A~%" (getf layout :participants))
  (format t "网格：~Dx~D~%" 
          (getf layout :columns)
          (getf layout :rows)))

;; 切换布局类型
(set-video-layout-type group-call-id :speaker)  ; :grid :speaker :spotlight

;; 固定参与者视频
(pin-participant-video group-call-id participant-id)

;; 取消固定
(unpin-participant-video group-call-id participant-id)
```

### 1.6 通话录制

```lisp
;; 开始录制
(multiple-value-bind (recording-path error)
    (toggle-group-call-recording group-call-id)
  (if error
      (format t "录制失败：~A~%" error)
      (format t "录制已开始：~A~%" recording-path)))

;; 停止录制
(multiple-value-bind (path duration error)
    (stop-group-call-recording group-call-id)
  (if error
      (format t "停止录制失败：~A~%" error)
      (format t "录制完成：~A (时长：~D秒)~%" path duration)))

;; 获取录制信息
(let ((recording (get-group-call-recording group-call-id)))
  (when recording
    (format t "录制路径：~A~%" (getf recording :path))
    (format t "是否正在录制：~A~%" (getf recording :active))))
```

### 1.7 AI 降噪

```lisp
;; 启用降噪
(enable-ai-noise-reduction group-call-id :level :auto)
;; 可用级别：:off :low :medium :high :auto

;; 禁用降噪
(disable-ai-noise-reduction group-call-id)
```

### 1.8 获取统计信息

```lisp
;; 获取通话统计
(let ((stats (get-group-video-stats group-call-id)))
  (format t "流数量：~D~%" (getf stats :stream-count))
  (format t "是否正在录制：~A~%" (getf stats :is-recording))
  
  ;; 遍历每个流的统计
  (dolist (stream-info (getf stats :streams))
    (format t "  流：~A~%" (getf stream-info :stream-id))
    (format t "    分辨率：~A, FPS: ~D~%" 
            (getf stream-info :resolution)
            (getf stream-info :fps))))

;; 获取特定参与者统计
(let ((p-stats (get-participant-video-stats group-call-id participant-id)))
  (when p-stats
    (format t "参与者 ~A 状态：~A~%" 
            participant-id 
            (getf p-stats :state))))
```

---

## 2. 视频消息

### 2.1 录制视频消息

```lisp
;; 开始录制
(start-video-message-recording 
  :duration-limit 60    ; 最长 60 秒
  :quality :medium      ; :low :medium :high :auto
  :device-id nil)       ; nil = 默认摄像头

;; 获取录制进度
(let ((progress (get-recording-progress)))
  (format t "状态：~A~%" (getf progress :state))
  (format t "已录制：~D秒~%" (getf progress :elapsed))
  (format t "剩余：~D秒~%" (getf progress :remaining))
  (format t "进度：~D%~%" (* 100 (getf progress :percentage))))

;; 暂停录制
(pause-video-message-recording)

;; 恢复录制
(resume-video-message-recording)

;; 停止录制
(multiple-value-bind (path duration error)
    (stop-video-message-recording)
  (if error
      (format t "停止录制失败：~A~%" error)
      (progn
        (format t "录制完成：~A~%" path)
        (format t "时长：~D秒~%" duration))))

;; 取消录制
(cancel-video-message-recording)
```

### 2.2 处理视频

```lisp
;; 处理录制的视频（自动裁剪为圆形并压缩）
(multiple-value-bind (success error)
    (process-video-message input-path output-path
                           :compress t
                           :crop-circular t
                           :quality :medium
                           :max-size 10485760)  ; 10MB
  (if error
      (format t "处理失败：~A~%" error)
      (format t "处理完成：~A~%" output-path)))

;; 单独裁剪为圆形
(crop-video-to-circle input-path output-path :size 640)

;; 单独压缩
(compress-video input-path output-path 
                :max-size 5242880  ; 5MB
                :quality :high
                :codec :h264)

;; 生成缩略图
(let ((thumb-path (generate-video-thumbnail video-path 
                                             :time-position 2
                                             :size 320)))
  (format t "缩略图：~A~%" thumb-path))
```

### 2.3 发送和接收

```lisp
;; 发送视频消息
(multiple-value-bind (message-id error)
    (send-video-message chat-id video-path 
                        :caption "看这个！"
                        :reply-to nil)
  (if error
      (format t "发送失败：~A~%" error)
      (format t "已发送：消息 ID ~A~%" message-id)))

;; 下载视频消息
(multiple-value-bind (file-path error)
    (download-video-message message-id 
                            :chat-id chat-id
                            :output-path nil)  ; nil = 自动生成路径
  (if error
      (format t "下载失败：~A~%" error)
      (format t "已下载到：~A~%" file-path)))

;; 解析视频消息
(let ((msg (get-message message-id chat-id)))
  (when msg
    (let ((video (parse-video-message msg)))
      (when video
        (format t "视频消息详情:~%")
        (format t "  时长：~D秒~%" (video-message-duration video))
        (format t "  尺寸：~Dx~D~%" 
                (video-message-width video)
                (video-message-height video))
        (format t "  文件大小：~D字节~%" (video-message-file-size video))
        (format t "  是否圆形：~A~%" (video-message-is-circular video))))))

;; 播放视频消息
(play-video-message video-path :fullscreen nil)
```

### 2.4 验证视频

```lisp
;; 验证视频消息格式
(multiple-value-bind (valid error)
    (is-valid-video-message video-path)
  (if valid
      (format t "视频格式有效~%")
      (format t "视频格式无效：~A~%" error)))

;; 获取视频元数据
(multiple-value-bind (duration width height file-size)
    (get-video-metadata video-path)
  (format t "时长：~D秒~%" duration)
  (format t "尺寸：~Dx~D~%" width height)
  (format t "文件大小：~D字节~%" file-size))
```

---

## 3. 媒体合集管理

### 3.1 创建和管理相册

```lisp
;; 创建相册
(multiple-value-bind (album-id error)
    (create-media-album "2024 年会" chat-id 
                        :description "公司年度聚会照片"
                        :cover-media-id nil)
  (if error
      (format t "创建相册失败：~A~%" error)
      (format t "相册已创建：~A~%" album-id)))

;; 编辑相册
(edit-media-album album-id 
                  :title "2024 年会 - 完整版"
                  :description "更新后的描述"
                  :cover-media-id cover-media-id)

;; 获取相册列表
(let ((albums (get-media-albums chat-id)))
  (format t "共有 ~D 个相册:~%" (length albums))
  (dolist (album-id albums)
    (let ((album (get-media-album album-id)))
      (when album
        (format t "  - ~A (~D 张照片)~%" 
                (getf album :title)
                (getf album :media-count))))))

;; 获取相册详情
(let ((album (get-media-album album-id)))
  (when album
    (format t "标题：~A~%" (getf album :title))
    (format t "描述：~A~%" (getf album :description))
    (format t "媒体数量：~D~%" (getf album :media-count))
    (format t "创建时间：~A~%" (getf album :created-date))))

;; 删除相册
(delete-media-album album-id)
```

### 3.2 管理媒体

```lisp
;; 添加媒体到相册
(add-media-to-album album-id '("media-1" "media-2" "media-3"))

;; 从相册移除媒体
(remove-media-from-album album-id '("media-2"))

;; 重新排序媒体
(reorder-album-media album-id '("media-3" "media-1" "media-2"))
```

### 3.3 智能相册

```lisp
;; 自动创建相册
(let ((created (auto-create-albums chat-id 
                                   :by-date t      ; 按日期分组
                                   :by-event t     ; 检测事件
                                   :min-items 3))) ; 最少 3 张照片
  (format t "自动创建了 ~D 个相册:~%" (length created))
  (dolist (album-id created)
    (let ((album (get-media-album album-id)))
      (when album
        (format t "  - ~A (~D 张)~%" 
                (getf album :title)
                (getf album :media-count))))))
```

### 3.4 标签系统

```lisp
;; 给媒体添加标签
(add-media-tags media-id '("旅行" "海滩" "日落"))

;; 移除标签
(remove-media-tags media-id '("日落"))

;; 按标签搜索
(let ((results (search-media-by-tags chat-id 
                                     '("旅行" "海滩")
                                     :match-all t))) ; 匹配所有标签
  (format t "找到 ~D 个匹配的媒体~%" (length results)))

;; 获取热门标签
(let ((popular (get-popular-tags chat-id :limit 10)))
  (format t "热门标签:~%")
  (dolist (tag-count popular)
    (format t "  ~A: ~D次~%" (car tag-count) (cdr tag-count))))
```

### 3.5 搜索和过滤

```lisp
;; 多条件搜索
(let ((results (search-media chat-id 
                             :type :photo           ; 类型
                             :date-from start-date  ; 开始日期
                             :date-to end-date      ; 结束日期
                             :tags '("旅行")        ; 标签
                             :query "海滩"          ; 文字搜索
                             :limit 50)))           ; 限制数量
  (format t "找到 ~D 个媒体~%" (length results)))

;; 按类型过滤
(photos := (filter-media-by-type chat-id :photo))
(videos := (filter-media-by-type chat-id :video))
(documents := (filter-media-by-type chat-id :document))

;; 获取时间线
(let ((timeline (get-media-timeline chat-id 
                                    :start-date nil
                                    :end-date nil)))
  (dolist (date-media timeline)
    (format t "~A: ~D个媒体~%" 
            (car date-media)
            (length (cdr date-media)))))
```

### 3.6 导出媒体

```lisp
;; 导出相册
(multiple-value-bind (count error)
    (export-media-album album-id "~/telegram-exports/album/"
                        :format nil)  ; nil = 原始格式
  (if error
      (format t "导出失败：~A~%" error)
      (format t "导出了 ~D 个文件~%" count)))

;; 导出聊天所有媒体
(multiple-value-bind (count error)
    (export-all-media chat-id "~/telegram-exports/chat/"
                      :format nil)
  (if error
      (format t "导出失败：~A~%" error)
      (format t "导出了 ~D 个文件~%" count)))
```

---

## 4. 完整应用示例

### 4.1 视频会议机器人

```lisp
(defpackage :meeting-bot
  (:use :cl :cl-telegram/api))

(in-package :meeting-bot)

(defvar *active-meetings* (make-hash-table :test 'equal)
  "活跃会议列表")

(defun start-meeting (chat-id title)
  "开始新会议"
  (multiple-value-bind (call-info error)
      (create-group-call chat-id :is-video-chat t :title title)
    (if error
        (format t "创建会议失败：~A~%" error)
        (let ((group-call-id (getf call-info :group-call-id)))
          ;; 初始化视频
          (init-group-video :max-participants 50)
          
          ;; 加入并启动视频
          (join-group-call group-call-id)
          (start-group-video-stream group-call-id :resolution :hd)
          
          ;; 启用降噪
          (enable-ai-noise-reduction group-call-id :level :high)
          
          ;; 开始录制
          (toggle-group-call-recording group-call-id)
          
          ;; 存储会议信息
          (setf (gethash group-call-id *active-meetings*) 
                (list :title title
                      :chat-id chat-id
                      :start-time (get-universal-time)))
          
          (format t "会议已开始：~A (ID: ~A)~%" title group-call-id)))))

(defun end-meeting (group-call-id)
  "结束会议"
  (let ((meeting (gethash group-call-id *active-meetings*)))
    (when meeting
      ;; 停止录制
      (multiple-value-bind (path duration)
          (stop-group-call-recording group-call-id)
        (format t "录制保存于：~A (时长：~D秒)~%" path duration))
      
      ;; 离开通话
      (leave-group-call group-call-id)
      
      ;; 移除会议信息
      (remhash group-call-id *active-meetings*)
      
      (format t "会议已结束：~A~%" (getf meeting :title)))))

;; 使用示例
;; (start-meeting 123456789 "周一例会")
;; (end-meeting group-call-id)
```

### 4.2 媒体管理工具

```lisp
(defpackage :media-manager
  (:use :cl :cl-telegram/api))

(in-package :media-manager)

(defun organize-chat-media (chat-id)
  "整理聊天媒体"
  (format t "开始整理聊天 ~A 的媒体...~%" chat-id)
  
  ;; 自动创建相册
  (let ((albums (auto-create-albums chat-id 
                                    :by-date t 
                                    :by-event t
                                    :min-items 5)))
    (format t "创建了 ~D 个相册~%" (length albums)))
  
  ;; 获取热门标签
  (let ((popular (get-popular-tags chat-id :limit 20)))
    (format t "热门标签:~%")
    (dolist (tag-count popular)
      (format t "  ~A: ~D次~%" (car tag-count) (cdr tag-count))))
  
  ;; 显示媒体统计
  (let* ((photos (filter-media-by-type chat-id :photo))
         (videos (filter-media-by-type chat-id :video))
         (documents (filter-media-by-type chat-id :document)))
    (format t "媒体统计:~%")
    (format t "  照片：~D张~%" (length photos))
    (format t "  视频：~D个~%" (length videos))
    (format t "  文件：~D个~%" (length documents))))

(defun backup-chat-media (chat-id backup-dir)
  "备份聊天媒体"
  (format t "开始备份聊天 ~A 到 ~A~%" chat-id backup-dir)
  
  (multiple-value-bind (count error)
      (export-all-media chat-id backup-dir)
    (if error
        (format t "备份失败：~A~%" error)
        (format t "备份完成：~D个文件~%" count))))

;; 使用示例
;; (organize-chat-media 123456789)
;; (backup-chat-media 123456789 "~/telegram-backup/")
```

### 4.3 视频消息记录器

```lisp
(defpackage :video-diary
  (:use :cl :cl-telegram/api))

(in-package :video-diary)

(defvar *diary-chat-id* nil
  "日记聊天 ID")

(defun record-diary-entry (title duration-seconds)
  "记录视频日记"
  (format t "开始记录视频日记：~A~%" title)
  
  ;; 开始录制
  (start-video-message-recording 
    :duration-limit duration-seconds
    :quality :high)
  
  ;; 显示进度
  (let ((finished nil))
    (unwind-protect
         (progn
           (loop until finished do
             (let ((progress (get-recording-progress)))
               (format t "~D% (~D/~D秒)~%" 
                       (* 100 (getf progress :percentage))
                       (getf progress :elapsed)
                       (getf progress :remaining))
               (when (>= (getf progress :percentage) 1.0)
                 (setf finished t))
               (sleep 1))))
      ;; 停止录制
      (multiple-value-bind (path duration error)
          (stop-video-message-recording)
        (if error
            (format t "录制失败：~A~%" error)
            (progn
              (format t "录制完成：~D秒~%" duration)
              
              ;; 发送到日记聊天
              (multiple-value-bind (msg-id send-error)
                  (send-video-message *diary-chat-id* path 
                                      :caption title)
                (if send-error
                    (format t "发送失败：~A~%" send-error)
                    (format t "日记已保存：消息 ID ~A~%" msg-id)))))))))

;; 使用示例
;; (setf video-diary::*diary-chat-id* 123456789)
;; (record-diary-entry "今天的工作总结" 60)
```

---

## 5. 错误处理

```lisp
;; 处理常见错误
(handler-case 
    (progn
      (init-group-video)
      (multiple-value-bind (stream-id error)
          (start-group-video-stream "call-1" :resolution :hd)
        (cond
          ((eql error :not-authenticated)
           (format t "请先登录~%"))
          ((eql error :max-participants-reached)
           (format t "参与者已达上限~%"))
          ((eql error :webrtc-init-failed)
           (format t "WebRTC 初始化失败~%"))
          (t
           (format t "启动视频成功：~A~%" stream-id)))))
  (error (e)
    (format t "发生错误：~A~%" e)))
```

---

## 6. 性能建议

### 6.1 视频质量选择

| 场景 | 推荐质量 | 带宽需求 |
|------|----------|----------|
| 移动网络 | :ld 或 :sd | 100-500 Kbps |
| WiFi 普通通话 | :hd | 2-3 Mbps |
| 高质量会议 | :fhd | 5+ Mbps |
| 屏幕共享 | :screen | 8+ Mbps |

### 6.2 内存管理

```lisp
;; 定期清理不再使用的资源
(defun cleanup-video-resources ()
  "清理视频资源"
  (shutdown-group-video)
  (init-group-video))

;; 限制录制文件数量
(defun cleanup-old-recordings (keep-days)
  "清理旧录制文件"
  (let* ((dir (video-manager-recording-dir *group-video-manager*))
         (cutoff (- (get-universal-time) (* keep-days 24 60 60))))
    (dolist (file (directory (merge-pathnames "*.mkv" dir)))
      (let ((mod-time (file-write-date file)))
        (when (< mod-time cutoff)
          (delete-file file)
          (format t "已删除：~A~%" file))))))
```

---

**文档版本**: v0.26.0  
**最后更新**: 2026-04-20
