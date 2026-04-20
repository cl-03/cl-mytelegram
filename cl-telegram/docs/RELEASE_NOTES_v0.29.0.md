# Release Notes - cl-telegram v0.29.0

**版本**: 0.29.0  
**发布日期**: 2026-04-20  
**主要特性**: Mini App CLOG 完整集成

---

## 新功能

### Mini App CLOG 集成（Bot API 9.6）

完整的 Mini App 设备访问实现，通过 CLOG Web UI 集成：

#### 设备访问

完整的设备硬件访问 API：

- **摄像头访问** - 通过浏览器 getUserMedia API 请求和使用设备摄像头
- **麦克风访问** - 通过浏览器 getUserMedia API 请求和使用设备麦克风
- **照片捕获** - 使用 Canvas 捕获照片，支持多种质量设置
- **视频捕获** - 使用 MediaRecorder API 录制视频
- **媒体流管理** - 获取和释放媒体流，支持多路流
- **权限管理** - 查询和跟踪设备权限状态
- **功能检测** - 检查设备对摄像头、麦克风、位置、联系人的支持

**新增函数**:
```lisp
;; 初始化
(initialize-mini-app &optional port)
(shutdown-mini-app)

;; 设备访问
(request-camera-access)
(request-microphone-access)
(capture-photo &key quality width height)
(capture-video &key duration quality)
(get-media-stream &key video audio)
(release-media-stream stream-id)

;; 权限和支持
(get-device-permissions)
(check-device-support feature)

;; 统计和缓存
(get-mini-app-stats)
(clear-mini-app-cache)
```

#### 主题集成

与 Telegram 客户端主题完全同步：

- **自动同步** - 从 Telegram WebApp 获取当前主题参数
- **主题应用** - 将主题参数应用到 CLOG 窗口
- **事件处理** - 监听和处理主题变更事件
- **自定义主题** - 支持自定义主题参数覆盖

**新增函数**:
```lisp
;; 主题同步
(sync-with-client-theme)
(get-mini-app-theme)
(apply-theme-to-clog theme)
(apply-theme-parameters &key bg-color text-color button-color)
(get-theme-parameters)
(set-theme-override mode)

;; 事件处理
(on-theme-change handler-id handler-fn)
```

#### Mini App UI 组件

基础的 Mini App 用户界面组件：

- **按钮创建** - 创建带样式的按钮，支持点击处理
- **警告对话框** - 显示原生警告对话框
- **状态监控** - 获取连接和资源使用统计

**新增函数**:
```lisp
;; UI 组件
(create-mini-app-button text &key color on-click)
(show-mini-app-alert message &key title)

;; 状态
(get-mini-app-stats)
```

---

## 新增的类

### Mini App CLOG

| 类名 | 描述 |
|------|------|
| `mini-app-manager` | Mini App CLOG 管理器 |

### Mini App Theme（已在 v0.28.0 中定义）

v0.29.0 新增访问器函数：
- `mini-app-bg-color` - 背景色
- `mini-app-text-color` - 文字色
- `mini-app-hint-color` - 提示色
- `mini-app-link-color` - 链接色
- `mini-app-button-color` - 按钮色
- `mini-app-secondary-bg` - 次要背景色
- `mini-app-header-bg` - 头部背景色
- `mini-app-is-dark` - 是否深色主题

---

## 技术改进

### CLOG 浏览器集成

通过 CLOG 直接执行浏览器 JavaScript API：

```lisp
;; 摄像头访问实现
(clog:run-js window "
  navigator.mediaDevices.getUserMedia({ video: true, audio: false })
    .then(() => true)
    .catch((err) => false);
" :wait t)
```

### 媒体流管理

使用哈希表跟踪活动媒体流：

```lisp
(defvar *mini-app-streams* (make-hash-table :test 'equal))

(defun get-media-stream (&key video audio)
  (let ((stream-id (clog:run-js window "...")))
    (setf (gethash stream-id *mini-app-streams*)
          (list :active t :video video :audio audio :created (get-universal-time)))
    stream-id))
```

### 照片捕获

使用 Canvas + JPEG 编码：

```lisp
(defun capture-photo (&key (quality :high) (width 1920) (height 1080))
  (clog:run-js window (format nil "
    (async () => {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { width: ~D, height: ~D }
      });
      const video = document.createElement('video');
      video.srcObject = stream;
      await video.play();
      const canvas = document.createElement('canvas');
      canvas.width = ~D; canvas.height = ~D;
      const ctx = canvas.getContext('2d');
      ctx.drawImage(video, 0, 0, ~D, ~D);
      stream.getTracks().forEach(track => track.stop());
      return canvas.toDataURL('image/jpeg', ~:[0.5;0.8;0.95~]);
    })();
  " width height width height width height (eq quality :high)) :wait t))
```

### 主题同步

从 Telegram WebApp 获取主题参数：

```lisp
(defun sync-with-client-theme ()
  (let ((theme-data (clog:run-js window "
    Telegram.WebApp.themeParams || {
      bg_color: '#ffffff',
      text_color: '#000000',
      hint_color: '#999999',
      link_color: '#2481cc',
      button_color: '#2481cc',
      secondary_bg_color: '#f4f4f5',
      header_bg_color: '#ffffff',
      is_dark: false
    }
  " :wait t)))
    (parse-mini-app-theme theme-data)))
```

### 错误处理

所有函数都有完整的异常处理：

```lisp
(handler-case
    (let* ((window (mini-app-window manager))
           (result (clog:run-js window "...")))
      result)
  (t (e)
    (log:error "Exception in ~A: ~A" function-name e)
    nil))
```

---

## 兼容性说明

### 向后兼容

- 完全兼容 Bot API 9.x 和 8.x 功能
- 现有代码无需修改
- Mini App CLOG 功能是 v0.28.0 Mini App 占位实现的完整实现

### 系统依赖

```lisp
;; 核心依赖（已有）
:clog           ; Web UI（关键依赖）
:jonathan       ; JSON 序列化
:bordeaux-threads ; 线程支持
:cl-log         ; 日志记录
```

### 浏览器要求

Mini App 设备访问功能需要现代浏览器支持：

| 功能 | Chrome | Firefox | Safari | Edge |
|------|--------|---------|--------|------|
| getUserMedia | 80+ | 75+ | 13+ | 80+ |
| MediaRecorder | 80+ | 75+ | 部分 | 80+ |
| Telegram WebApp | Any | Any | Any | Any |

---

## 使用示例

### 初始化 Mini App

```lisp
;; 启动 Mini App 服务器（默认端口 8080）
(cl-telegram/api:initialize-mini-app)

;; 或指定端口
(cl-telegram/api:initialize-mini-app 9000)

;; 检查状态
(let ((stats (cl-telegram/api:get-mini-app-stats)))
  (format t "连接：~A~%" (getf stats :connected-p))
  (format t "活动流：~D~%" (getf stats :active-streams)))
```

### 摄像头使用

```lisp
;; 请求摄像头权限
(when (cl-telegram/api:request-camera-access)
  (format t "✓ 摄像头权限已授予~%")

  ;; 拍摄照片
  (let ((photo (cl-telegram/api:capture-photo :quality :high :width 1920 :height 1080)))
    (when photo
      (format t "✓ 照片已捕获 (~D 字符)~%" (length photo))
      ;; 处理照片数据...
      )))
```

### 视频捕获

```lisp
;; 录制 10 秒视频
(let ((video (cl-telegram/api:capture-video :duration 10 :quality :high)))
  (when video
    (format t "✓ 视频已录制 (~D 字符)~%" (length video))))
```

### 媒体流管理

```lisp
;; 获取视频 + 音频流
(let ((stream-id (cl-telegram/api:get-media-stream :video t :audio t)))
  (when stream-id
    (format t "✓ 流已创建：~A~%" stream-id)

    ;; ... 使用流 ...

    ;; 释放流
    (cl-telegram/api:release-media-stream stream-id)))
```

### 主题同步

```lisp
;; 同步客户端主题
(let ((theme (cl-telegram/api:sync-with-client-theme)))
  (when theme
    (format t "背景色：~A~%" (cl-telegram/api:mini-app-bg-color theme))
    (format t "文字色：~A~%" (cl-telegram/api:mini-app-text-color theme))
    (format t "深色模式：~A~%" (cl-telegram/api:mini-app-is-dark theme))))

;; 应用自定义主题
(cl-telegram/api:apply-theme-parameters
  :bg-color "#1a1a1a"
  :text-color "#ffffff"
  :button-color "#0088cc")
```

### 完整示例

```lisp
;; 完整使用示例
(defun mini-app-demo ()
  "Mini App 完整使用示例"
  ;; 1. 初始化
  (cl-telegram/api:initialize-mini-app 8080)

  ;; 2. 同步主题
  (let ((theme (cl-telegram/api:sync-with-client-theme)))
    (when theme
      (format t "主题：~A~%"
              (if (cl-telegram/api:mini-app-is-dark theme)
                  "深色" "浅色"))))

  ;; 3. 请求设备权限
  (let ((camera-granted (cl-telegram/api:request-camera-access))
        (mic-granted (cl-telegram/api:request-microphone-access)))
    (format t "摄像头：~A, 麦克风：~A~%"
            (if camera-granted "✓" "✗")
            (if mic-granted "✓" "✗")))

  ;; 4. 使用设备功能
  (when (cl-telegram/api:request-camera-access)
    (let ((photo (cl-telegram/api:capture-photo :quality :high)))
      (when photo
        (format t "✓ 拍摄照片：~D 字符~%" (length photo)))))

  ;; 5. 检查权限
  (let ((perms (cl-telegram/api:get-device-permissions)))
    (format t "权限：~A~%" perms))

  ;; 6. 清理
  (cl-telegram/api:clear-mini-app-cache)
  (cl-telegram/api:shutdown-mini-app)
  (format t "✓ 完成~%"))
```

---

## 已知问题

1. **Safari MediaRecorder 支持** - Safari 对 MediaRecorder API 的支持有限，可能需要用户启用实验性功能
2. **CLI 模式限制** - Mini App 功能需要 CLOG Web UI，纯 CLI 模式下不可用
3. **HTTPS 要求** - 生产环境部署需要 HTTPS 才能访问设备 API

---

## 升级指南

### 从 v0.28.0 升级

1. **更新 ASDF 配置** - 添加 `bot-api-9-mini-app` 模块
2. **重新加载系统** - `(asdf:load-system :cl-telegram)`
3. **导入新函数** - 14 个新的导出函数可用

### 数据库迁移

不需要数据库迁移。

---

## 贡献者

- 开发团队：cl-telegram core team
- 特别感谢：Telegram Bot API 团队、CLOG 项目

---

## 相关链接

- [Bot API 9.6 官方更新日志](https://core.telegram.org/bots/api-changelog)
- [Mini App 开发文档](https://core.telegram.org/bots/webapps)
- [CLOG 文档](https://rabbibotton.github.io/clog/)
- [项目 GitHub](https://github.com/cl-telegram/cl-telegram)
- [完整 API 文档](docs/API_REFERENCE_v0.29.0.md)

---

**cl-telegram v0.29.0** - 2026-04-20
