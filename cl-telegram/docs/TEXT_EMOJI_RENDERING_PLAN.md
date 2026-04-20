# 文本/Emoji 渲染集成计划

**文档版本**: 1.0  
**更新日期**: 2026-04-20  
**目标版本**: cl-telegram v0.24.0

---

## 一、当前状态

### 1.1 现有实现

当前 `image-overlays.lisp` 中的文本/Emoji 叠加功能是 **placeholder 实现**：

```lisp
;; 当前实现（placeholder）
(defun add-text-overlay (image text &key x y font-size color opacity)
  "Add text overlay to image (placeholder implementation)"
  (log:info "Text overlay requested: ~A at (~A, ~A)" text x y)
  ;; TODO: Implement with cl-freetype
  image)

(defun add-emoji-overlay (image emoji &key x y size opacity)
  "Add emoji overlay to image (placeholder implementation)"
  (log:info "Emoji overlay requested: ~A at (~A, ~A)" emoji x y)
  ;; TODO: Implement with cl-cairo2 or emoji font
  image)
```

**已知限制**：
- 文本叠加仅记录日志，不实际渲染
- Emoji 叠加仅记录日志，不实际渲染
- 需要集成外部库才能实现完整功能

---

## 二、技术方案

### 2.1 文本渲染：cl-freetype2

**库选择**: [cl-freetype2](https://github.com/rpav/cl-freetype2) by rpav

**理由**：
- 活跃的维护状态
- 使用 CFFI，跨平台支持良好
- 提供 FreeType 2 的完整绑定
- 支持 CJK（中日韩）字体渲染
- 可通过 Quicklisp 安装

**系统要求**：
- FreeType 2 库（系统级安装）
- Linux: `libfreetype6-dev`
- Windows: MinGW with `mingw-gmp`
- macOS: `brew install freetype`

### 2.2 Emoji 渲染：cl-cairo2 + 颜色字体

**库选择**: [cl-cairo2](https://github.com/rpav/cl-cairo2) by rpav

**理由**：
- Cairo 图形库的 Common Lisp 绑定
- 支持矢量图形绘制
- 可通过系统颜色字体支持 Emoji
- 与 cl-freetype2 可协同工作

**系统要求**：
- Cairo 图形库（系统级安装）
- 颜色 Emoji 字体（如 Noto Color Emoji）
- Cairo 1.17+ 支持 COLRv1 颜色字体

**注意**：
- Cairo 的"toy text API"对 Emoji 支持有限
- 完整 Emoji 支持需要 Pango 集成
- 备选方案：将 Emoji 作为图像叠加

### 2.3 备选方案：zpb-ttf + cl-vectors

**纯 Common Lisp 方案**：
- [zpb-ttf](https://github.com/zkat/zpb-ttf) - 纯 Lisp TTF 解析器
- [cl-vectors](https://github.com/nikodemus/cl-vectors) - 矢量图形库

**优点**：
- 无外部 C 依赖
- 更容易安装和部署

**缺点**：
- 性能较低
- 功能不如 FreeType 完整
- 不支持颜色字体（Emoji）

---

## 三、实现计划

### 3.1 阶段 1：集成 cl-freetype2（文本渲染）

**工作量**: 3-5 天

#### 步骤 1.1：添加依赖

```lisp
;; cl-telegram.asd
:depends-on (:cl-freetype2
             :cl-cairo2
             ;; ... existing deps
             )
```

#### 步骤 1.2：创建字体管理模块

```lisp
;;; src/image-processing/font-manager.lisp

(defpackage #:cl-telegram/font-manager
  (:nicknames #:cl-tg/font)
  (:use #:cl)
  (:export
   ;; Font initialization
   #:init-font-system
   #:shutdown-font-system
   
   ;; Font loading
   #:load-font
   #:get-font-face
   #:unload-font
   
   ;; Text rendering
   #:render-text
   #:render-text-to-image
   #:measure-text
   
   ;; Font utilities
   #:get-available-fonts
   #:get-font-metrics
   #:supports-character-p))

;; Global state
(defvar *freetype-library* nil
  "FreeType library instance")

(defvar *font-cache* (make-hash-table :test 'equal)
  "Cache for loaded fonts")

;;; Initialization
(defun init-font-system ()
  "Initialize FreeType library"
  (unless *freetype-library*
    (setf *freetype-library* (ft:make-library))
    t))

;;; Font loading
(defun load-font (font-path)
  "Load font from file"
  (let ((cached (gethash font-path *font-cache*)))
    (when cached
      (return-from load-font cached))))

;;; Text rendering
(defun render-text-to-image (image text &key x y font-size color font-face)
  "Render text onto image"
  ;; Implementation using FreeType glyph rendering
  )
```

#### 步骤 1.3：更新 image-overlays.lisp

```lisp
;;; src/image-processing/image-overlays.lisp

;; Replace placeholder implementation
(defun add-text-overlay (image text &key x y font-size color opacity font-face)
  "Add text overlay to image (full implementation)"
  (handler-case
      (let ((font (or font-face *default-font*)))
        (render-text-to-image image text
                              :x x
                              :y y
                              :font-size font-size
                              :color color
                              :font-face font))
    (condition (e)
      (log:error "Text overlay failed: ~A" e)
      image)))
```

### 3.2 阶段 2：集成 cl-cairo2（Emoji 渲染）

**工作量**: 5-7 天

#### 步骤 2.1：创建 Emoji 渲染模块

```lisp
;;; src/image-processing/emoji-renderer.lisp

(defpackage #:cl-telegram/emoji-renderer
  (:nicknames #:cl-tg/emoji)
  (:use #:cl)
  (:export
   #:init-emoji-renderer
   #:render-emoji
   #:render-emoji-to-image
   #:get-emoji-image
   #:get-available-emoji))

;; Emoji cache
(defvar *emoji-cache* (make-hash-table :test 'equal)
  "Cache for rendered emoji images")

;; Default emoji size
(defvar *default-emoji-size* 48)

;;; Emoji rendering
(defun render-emoji-to-image (emoji &key size)
  "Render emoji to image surface"
  ;; Use Cairo to render emoji from system font
  )

(defun add-emoji-overlay (image emoji &key x y size opacity)
  "Add emoji overlay to image"
  (let ((emoji-img (render-emoji-to-image emoji :size (or size 48))))
    (when emoji-img
      ;; Composite emoji onto target image
      (composite-image image emoji-img x y :opacity opacity))
  image)
```

#### 步骤 2.2：Emoji 字体支持

```lisp
;; Check for system emoji fonts
(defun ensure-emoji-font ()
  "Ensure emoji font is available"
  (let ((emoji-fonts '("Noto Color Emoji"
                       "Apple Color Emoji"
                       "Segoe UI Emoji"
                       "Twemoji")))
    (dolist (font-name emoji-fonts)
      (when (font-available-p font-name)
        (return-from ensure-emoji-font font-name))))
  
  ;; Fallback: Download Twemoji
  (download-twemoji-font))
```

### 3.3 阶段 3：CJK 字体支持

**工作量**: 2-3 天

#### 步骤 3.1：中文字体支持

```lisp
;; Common CJK fonts
(defparameter +cjk-fonts+
  '(("zh" . ("Noto Sans CJK SC"      ; 简体中文
             "Source Han Sans SC"
             "WenQuanYi Micro Hei"
             "SimSun"
             "Microsoft YaHei"))
    ("zh-tw" . ("Noto Sans CJK TC"    ; 繁体中文
                "Source Han Sans TC"))
    ("ja" . ("Noto Sans CJK JP"       ; 日文
             "Source Han Sans JP"))
    ("ko" . ("Noto Sans CJK KR"       ; 韩文
             "Source Han Sans KR"))))

(defun get-cjk-font (language-code)
  "Get appropriate CJK font for language"
  (let ((fonts (cdr (assoc language-code +cjk-fonts+ :test #'string=))))
    (dolist (font-name fonts)
      (when (font-available-p font-name)
        (return-from get-cjk-font font-name))))
  
  ;; Fallback to first available CJK font
  (or (find-cjk-font)
      (error "No CJK font available")))
```

#### 步骤 3.2：多语言文本渲染

```lisp
(defun render-multilingual-text (image text &key language)
  "Render text with appropriate font for language"
  (let* ((lang (or language "auto"))
         (font (if (string= lang "auto")
                   (detect-language-and-get-font text)
                   (get-cjk-font lang))))
    (render-text-to-image image text :font-face font)))
```

---

## 四、API 设计

### 4.1 文本叠加 API

```lisp
;; Basic text overlay
(add-text-overlay image "Hello World"
                  :x 50 :y 100
                  :font-size 24
                  :color '(255 255 255))

;; Advanced text overlay with font
(add-text-overlay image "你好世界"
                  :x 50 :y 100
                  :font-size 24
                  :font-face "Noto Sans CJK SC"
                  :color '(255 255 255)
                  :stroke '(0 0 0 128)  ; 黑色描边
                  :shadow t)            ; 阴影

;; Multi-line text
(add-text-overlay image "Line 1
Line 2
Line 3"
                  :x 50 :y 100
                  :line-height 1.5
                  :align :center)
```

### 4.2 Emoji 叠加 API

```lisp
;; Basic emoji overlay
(add-emoji-overlay image "😀"
                   :x 100 :y 100
                   :size 48)

;; Multiple emoji
(add-emoji-overlay image "🎉🎊🎈"
                   :x 50 :y 50
                   :size 32
                   :spacing 10)

;; Custom emoji (Telegram)
(add-emoji-overlay image (make-custom-emoji "emoji_id_123")
                   :x 100 :y 100
                   :size 64)
```

### 4.3 水印 API（增强版）

```lisp
;; Text watermark with font
(add-watermark image "© 2024 My Brand"
               :position :bottom-right
               :font-face "Arial"
               :font-size 16
               :opacity 0.5
               :color '(255 255 255))

;; Emoji watermark
(add-watermark image "⭐"
               :position :bottom-right
               :type :emoji
               :size 32
               :opacity 0.3)
```

---

## 五、依赖配置

### 5.1 ASDF 系统定义

```lisp
;;; cl-telegram.asd

(asdf:defsystem #:cl-telegram
  :depends-on (:cl-freetype2
               :cl-cairo2
               :opticl
               :cl-log
               :trivial-2d-array
               ;; ... existing deps
               )
  :components ((:module "image-processing"
                :components ((:file "font-manager")
                             (:file "emoji-renderer")
                             (:file "image-overlays")  ; Updated
                             ;; ... other files
                             ))))
```

### 5.2 系统字体要求

**Linux (Debian/Ubuntu)**:
```bash
sudo apt-get install libfreetype6-dev libcairo2-dev
sudo apt-get install fonts-noto fonts-noto-cjk
```

**macOS**:
```bash
brew install freetype cairo
# macOS has system emoji fonts
```

**Windows**:
```bash
# Install MSYS2
pacman -S mingw-w64-x86_64-freetype mingw-w64-x86_64-cairo
# Windows has Segoe UI Emoji
```

---

## 六、测试计划

### 6.1 文本渲染测试

```lisp
(test test-text-overlay-english
  "Test English text rendering"
  (let ((image (make-instance 'opticl:rgba-image :width 200 :height 100)))
    (fill-white image)
    (add-text-overlay image "Hello World" :x 10 :y 50)
    (is-true (image-has-text-p image "Hello"))))

(test test-text-overlay-chinese
  "Test Chinese text rendering"
  (let ((image (make-instance 'opticl:rgba-image :width 200 :height 100)))
    (fill-white image)
    (add-text-overlay image "你好世界" :x 10 :y 50
                      :font-face "Noto Sans CJK SC")
    (is-true (image-has-text-p image "你好"))))
```

### 6.2 Emoji 渲染测试

```lisp
(test test-emoji-overlay
  "Test emoji rendering"
  (let ((image (make-instance 'opticl:rgba-image :width 100 :height 100)))
    (fill-white image)
    (add-emoji-overlay image "😀" :x 25 :y 25 :size 50)
    (is-true (image-has-emoji-p image))))

(test test-custom-emoji
  "Test custom emoji rendering"
  ;; Requires Telegram custom emoji download
  )
```

---

## 七、性能优化

### 7.1 字体缓存

```lisp
;; LRU cache for fonts
(defvar *font-cache-size* 10)
(defvar *font-cache* (make-hash-table :test 'equal))

(defun get-cached-font (font-path)
  "Get font from cache with LRU eviction"
  (let ((cached (gethash font-path *font-cache*)))
    (when cached
      ;; Move to front of LRU list
      (move-to-front font-path)
      cached)))
```

### 7.2 Emoji 预渲染

```lisp
;; Pre-render common emoji
(defvar *common-emoji* '("😀" "😂" "😍" "👍" "❤️" "🔥" "🎉" "✨"))

(defun preload-emoji ()
  "Pre-render common emoji"
  (dolist (emoji *common-emoji*)
    (render-emoji-to-image emoji :size 48)
    (render-emoji-to-image emoji :size 32)
    (render-emoji-to-image emoji :size 24)))
```

---

## 八、时间表

| 阶段 | 内容 | 工作量 | 优先级 |
|------|------|--------|--------|
| 1 | cl-freetype2 集成（文本） | 3-5 天 | P0 |
| 2 | cl-cairo2 集成（Emoji） | 5-7 天 | P1 |
| 3 | CJK 字体支持 | 2-3 天 | P0 |
| 4 | 性能优化 | 2 天 | P2 |
| 5 | 测试和文档 | 3 天 | P1 |

**总计**: 15-20 天

---

## 九、风险与缓解

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|----------|
| cl-freetype2 Windows 兼容性问题 | 中 | 中 | 提供备选方案 zpb-ttf |
| Cairo Emoji 支持不完整 | 中 | 中 | 使用 Twemoji 图像作为后备 |
| CJK 字体缺失 | 高 | 低 |  bundled 字体文件 |
| 性能问题 | 中 | 低 | 实现缓存和预渲染 |

---

## 十、参考资料

- [cl-freetype2 GitHub](https://github.com/rpav/cl-freetype2)
- [cl-cairo2 GitHub](https://github.com/rpav/cl-cairo2)
- [FreeType 文档](https://freetype.org/freetype2/docs/)
- [Cairo 文本渲染](https://www.cairographics.org/manual/cairo-text.html)
- [Noto 字体下载](https://fonts.google.com/noto)
- [Twemoji COLR](https://github.com/googlefonts/noto-emoji)
