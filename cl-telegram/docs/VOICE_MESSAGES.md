# 语音消息功能文档

**版本**: v0.17.0  
**完成日期**: 2026-04-19

---

## 概述

cl-telegram v0.17.0 完成了语音消息功能的完整实现，包括：

- 语音消息发送和接收
- 语音消息录制和播放
- 波形生成和可视化
- 语音转写服务
- 音频文件发送
- 视频消息（圆形视频）
- 群组语音聊天

---

## API 参考

### 语音消息发送

#### `send-voice-message`

发送语音消息到聊天。

```lisp
(send-voice-message chat-id file-id
                    &key duration waveform reply-to-message-id reply-markup caption)
```

**参数**:
- `chat-id`: 聊天 ID
- `file-id`: 语音文件 ID（已上传）
- `duration`: 时长（秒）
- `waveform`: 波形数据列表 (0-255)
- `reply-to-message-id`: 可选的回复消息 ID
- `reply-markup`: 可选的回复键盘
- `caption`: 可选的标题

**返回值**: 成功返回消息对象，失败返回 `(nil error-keyword)`

**示例**:
```lisp
(multiple-value-bind (message error)
    (send-voice-message 123456 "file-id-123"
                        :duration 30
                        :waveform '(100 150 200 180 120)
                        :caption "Voice message")
  (if error
      (format t "Error: ~A~%" error)
      (format t "Sent: ~A~%" message)))
```

#### `send-voice-file`

发送音频文件作为语音消息。

```lisp
(send-voice-file chat-id file-path
                 &key duration title performer thumbnail reply-to-message-id caption)
```

**参数**:
- `chat-id`: 聊天 ID
- `file-path`: 音频文件路径（支持 OGG、MP3、M4A）
- `duration`: 时长（秒，0 表示自动检测）
- `title`: 可选的曲目标题
- `performer`: 可选的演奏者名称
- `thumbnail`: 可选的缩略图路径
- `caption`: 可选的标题

**示例**:
```lisp
(send-voice-file 123456 "/path/to/voice.ogg"
                 :caption "Check this out!")
```

---

### 语音消息录制

#### `record-voice-message`

开始录制语音消息。

```lisp
(record-voice-message chat-id &key max-duration on-complete on-cancel)
```

**参数**:
- `chat-id`: 聊天 ID
- `max-duration`: 最大录制时长（秒）
- `on-complete`: 录制完成时的回调（接收 file-id 和 duration）
- `on-cancel`: 取消录制时的回调

**示例**:
```lisp
(record-voice-message 123456
                      :max-duration 60
                      :on-complete (lambda (file-id duration waveform)
                                     (format t "Recorded: ~A seconds~%" duration))
                      :on-cancel (lambda ()
                                   (format t "Cancelled~%")))
```

#### `cancel-voice-recording`

取消当前语音录制。

```lisp
(cancel-voice-recording)  ; => T
```

#### `finish-voice-recording`

完成当前语音录制并获取文件 ID。

```lisp
(finish-voice-recording)  ; => (values file-id nil)
```

---

### 语音消息播放

#### `play-voice-message`

播放语音消息。

```lisp
(play-voice-message file-id &key on-complete volume)
```

**参数**:
- `file-id`: 语音文件 ID
- `on-complete`: 播放完成时的回调
- `volume`: 播放音量 (0.0-1.0)

**示例**:
```lisp
(play-voice-message "file-id-123"
                    :on-complete (lambda (fid)
                                   (format t "Played: ~A~%" fid))
                    :volume 0.8)
```

#### `stop-voice-playback`

停止当前语音播放。

```lisp
(stop-voice-playback)  ; => T
```

#### `pause-voice-playback`

暂停当前语音播放。

```lisp
(pause-voice-playback)  ; => T
```

#### `resume-voice-playback`

恢复暂停的语音播放。

```lisp
(resume-voice-playback)  ; => T
```

---

### 语音转写

#### `transcribe-voice-message`

将语音消息转写为文本。

```lisp
(transcribe-voice-message file-id &key language)
```

**参数**:
- `file-id`: 语音文件 ID
- `language`: 可选的语言代码（如 "en"、"zh"）

**返回值**: 成功返回转写文本，失败返回 `(nil error-keyword)`

**注意**: 此功能需要 Telegram Premium 订阅。

**示例**:
```lisp
(multiple-value-bind (text error)
    (transcribe-voice-message "file-id-123" :language "en")
  (if error
      (format t "Error: ~A~%" error)
      (format t "Transcription: ~A~%" text)))
```

#### `request-voice-transcription`

请求语音消息转写（异步）。

```lisp
(request-voice-transcription chat-id message-id &key language on-complete)
```

**参数**:
- `chat-id`: 聊天 ID
- `message-id`: 语音消息 ID
- `language`: 可选的语言代码
- `on-complete`: 转写完成时的回调

---

### 音频文件

#### `send-audio-file`

发送音频文件（音乐）。

```lisp
(send-audio-file chat-id file-path
                 &key duration title performer thumbnail reply-to-message-id)
```

**示例**:
```lisp
(send-audio-file 123456 "/path/to/music.mp3"
                 :title "My Song"
                 :performer "My Artist")
```

---

### 视频消息

#### `send-video-message`

发送圆形视频消息。

```lisp
(send-video-message chat-id file-id &key duration width height reply-to-message-id)
```

**参数**:
- `chat-id`: 聊天 ID
- `file-id`: 视频文件 ID
- `duration`: 时长（秒）
- `width`: 视频宽度（通常 640）
- `height`: 视频高度（通常 640，正方形）

#### `record-video-message`

录制并发送视频消息。

```lisp
(record-video-message chat-id &key max-duration on-complete)
```

---

### 群组语音聊天

#### `start-voice-chat`

在群组中启动语音聊天。

```lisp
(start-voice-chat chat-id &key title)
```

**示例**:
```lisp
(start-voice-chat -1001234567890 :title "Team Meeting")
```

#### `end-voice-chat`

结束语音聊天。

```lisp
(end-voice-chat chat-id)  ; => (values t nil)
```

#### `join-voice-chat`

加入语音聊天。

```lisp
(join-voice-chat chat-id &key as-speaker)
```

**参数**:
- `as-speaker`: T 表示作为发言人加入，NIL 表示作为听众

#### `leave-voice-chat`

离开语音聊天。

```lisp
(leave-voice-chat chat-id)  ; => T
```

#### `invite-to-voice-chat`

邀请用户加入语音聊天。

```lisp
(invite-to-voice-chat chat-id user-ids)
```

#### `toggle-voice-chat-mute`

切换语音聊天中的静音状态。

```lisp
(toggle-voice-chat-mute chat-id)
```

---

### 波形处理

#### `generate-waveform`

从音频数据生成波形。

```lisp
(generate-waveform audio-data &key width height)
```

#### `render-waveform-svg`

将波形渲染为 SVG。

```lisp
(render-waveform-svg waveform &key width height color)
```

**示例**:
```lisp
(let ((svg (render-waveform-svg '(100 150 200 180 120)
                                :width 200
                                :height 40
                                :color "#0088cc")))
  (format t "~A~%" svg))
```

#### `decode-waveform-from-base64`

从 base64 解码波形数据。

```lisp
(decode-waveform-from-base64 base64-string)
```

#### `encode-waveform-to-base64`

将波形编码为 base64。

```lisp
(encode-waveform-to-base64 waveform)
```

---

## CLOG UI 组件

### `render-voice-message`

在聊天中渲染语音消息。

```lisp
(render-voice-message win container voice-message on-play)
```

### `render-voice-recorder`

渲染语音录制 UI。

```lisp
(render-voice-recorder win container on-start on-stop on-cancel)
```

### `show-voice-chat-panel`

显示语音聊天面板。

```lisp
(show-voice-chat-panel win chat-id container)
```

---

## 使用示例

### 完整的语音消息流程

```lisp
(use-package :cl-telegram/api)

;; 1. 发送语音消息
(multiple-value-bind (msg error)
    (send-voice-file chat-id "/path/to/voice.ogg"
                     :caption "Hello!")
  (if error
      (format t "发送失败：~A~%" error)
      (format t "发送成功：~A~%" msg)))

;; 2. 录制语音消息
(record-voice-message chat-id
                      :max-duration 60
                      :on-complete (lambda (file-id duration waveform)
                                     (format t "录制完成：~A 秒~%" duration))
                      :on-cancel (lambda ()
                                   (format t "已取消~%")))

;; 3. 播放语音消息
(play-voice-message file-id
                    :on-complete (lambda (fid)
                                   (format t "播放完成~%")))

;; 4. 转写语音（需要 Premium）
(multiple-value-bind (text error)
    (transcribe-voice-message file-id :language "zh")
  (if error
      (format t "转写失败：~A~%" error)
      (format t "转写结果：~A~%" text)))
```

### 群组语音聊天

```lisp
;; 1. 启动语音聊天
(multiple-value-bind (chat error)
    (start-voice-chat chat-id :title "Team Meeting")
  (if error
      (format t "启动失败：~A~%" error)
      (format t "语音聊天已启动~%")))

;; 2. 加入语音聊天
(join-voice-chat chat-id :as-speaker t)

;; 3. 静音
(toggle-voice-chat-mute chat-id)

;; 4. 离开语音聊天
(leave-voice-chat chat-id)
```

---

## 测试

运行语音消息测试：

```lisp
(asdf:load-system :cl-telegram/tests)
(cl-telegram/tests:run-voice-messages-tests)
```

---

## 注意事项

1. **录音权限**: 录制语音消息需要访问音频输入设备
2. **文件格式**: 支持的语音格式包括 OGG (OPUS)、MP3、M4A
3. **文件大小**: 免费用户最大 20MB，Premium 用户最大 4GB
4. **转写服务**: 语音转写需要 Telegram Premium 订阅
5. **视频消息**: 圆形视频必须是正方形（通常 640x640）

---

## 故障排除

### 录音失败
- 检查麦克风权限
- 确认音频设备可用

### 上传失败
- 检查网络连接
- 验证文件大小不超过限制

### 播放失败
- 确认文件已下载完成
- 检查音频解码器

---

**最后更新**: 2026-04-19
