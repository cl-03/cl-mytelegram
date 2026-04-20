# 图像处理 API 参考

**版本**: 0.1.0  
**包**: `cl-telegram/image-processing` (别名：`cl-tg/img`)

---

## 目录

1. [核心操作](#1-核心操作)
2. [基础滤镜](#2-基础滤镜)
3. [Instagram 滤镜](#3-instagram-滤镜)
4. [叠加和绘图](#4-叠加和绘图)
5. [工具函数](#5-工具函数)

---

## 1. 核心操作

### 加载和保存

#### `load-image`

```lisp
(load-image file-path)
```

从文件加载图像。

**参数:**
- `file-path` - 图像文件路径

**返回:**
- 图像对象，或 NIL（失败时）

**支持格式:**
- JPG/JPEG, PNG, GIF, BMP

**示例:**
```lisp
(let ((image (load-image "photo.jpg")))
  (when image
    (format t "Loaded: ~Ax~A~%" 
            (image-width image) 
            (image-height image))))
```

---

#### `save-image`

```lisp
(save-image image file-path &key format quality)
```

保存图像到文件。

**参数:**
- `image` - 图像对象
- `file-path` - 输出文件路径
- `format` - 输出格式（"jpg", "png", "gif", "bmp"）
- `quality` - JPEG 质量 0-100（默认：90）

**返回:**
- 文件路径（成功），或 NIL（失败）

**示例:**
```lisp
(save-image image "output.jpg" :format "jpg" :quality 95)
```

---

### 图像属性

#### `image-width`

```lisp
(image-width image)
```

获取图像宽度（像素）。

---

#### `image-height`

```lisp
(image-height image)
```

获取图像高度（像素）。

---

#### `image-channels`

```lisp
(image-channels image)
```

获取颜色通道数（3=RGB, 4=RGBA）。

---

### 裁剪和调整大小

#### `crop-image`

```lisp
(crop-image image x y width height)
```

裁剪图像到指定矩形区域。

**参数:**
- `image` - 图像对象
- `x` - 左上角 X 坐标
- `y` - 左上角 Y 坐标
- `width` - 裁剪宽度
- `height` - 裁剪高度

**返回:**
- 裁剪后的图像对象

**示例:**
```lisp
(let ((cropped (crop-image image 100 100 500 500)))
  (save-image cropped "cropped.jpg"))
```

---

#### `resize-image`

```lisp
(resize-image image new-width new-height &key keep-aspect-ratio)
```

调整图像尺寸。

**参数:**
- `image` - 图像对象
- `new-width` - 目标宽度
- `new-height` - 目标高度
- `keep-aspect-ratio` - 是否保持宽高比（默认：NIL）

**返回:**
- 调整后的图像对象

**示例:**
```lisp
;; 拉伸到指定尺寸
(resize-image image 800 600)

;; 保持宽高比
(resize-image image 800 600 :keep-aspect-ratio t)
```

---

#### `scale-image`

```lisp
(scale-image image scale-factor)
```

按比例缩放图像。

**参数:**
- `image` - 图像对象
- `scale-factor` - 缩放因子（0.5=50%, 2.0=200%）

**返回:**
- 缩放后的图像对象

**示例:**
```lisp
;; 缩小到 50%
(scale-image image 0.5)

;; 放大到 200%
(scale-image image 2.0)
```

---

### 旋转

#### `rotate-image`

```lisp
(rotate-image image angle)
```

旋转图像。

**参数:**
- `image` - 图像对象
- `angle` - 旋转角度（90, 180, 270）

**返回:**
- 旋转后的图像对象

**示例:**
```lisp
(rotate-image image 90)   ;; 顺时针 90 度
(rotate-image image 180)  ;; 倒置
(rotate-image image 270)  ;; 逆时针 90 度
```

---

#### `flip-image-horizontal`

```lisp
(flip-image-horizontal image)
```

水平翻转图像（镜像）。

---

#### `flip-image-vertical`

```lisp
(flip-image-vertical image)
```

垂直翻转图像。

---

### 缩略图

#### `generate-thumbnail`

```lisp
(generate-thumbnail image max-width max-height &key output-path)
```

生成缩略图。

**参数:**
- `image` - 图像对象
- `max-width` - 最大宽度
- `max-height` - 最大高度
- `output-path` - 可选的输出文件路径

**返回:**
- 缩略图图像对象，或文件路径（如果指定 output-path）

**示例:**
```lisp
;; 生成内存中的缩略图
(let ((thumb (generate-thumbnail image 150 150)))
  (save-image thumb "thumb.jpg"))

;; 直接保存到文件
(generate-thumbnail image 150 150 :output-path "thumb.jpg")
```

---

## 2. 基础滤镜

### 颜色和色调

#### `apply-grayscale`

```lisp
(apply-grayscale image)
```

转换为灰度图像。

---

#### `apply-sepia`

```lisp
(apply-sepia image &key intensity)
```

应用棕褐色复古效果。

**参数:**
- `intensity` - 效果强度 0.0-1.0（默认：1.0）

---

#### `apply-brightness`

```lisp
(apply-brightness image adjustment)
```

调整亮度。

**参数:**
- `adjustment` - 调整值 -255 到 255（正=更亮）

**示例:**
```lisp
(apply-brightness image 50)   ;; 增亮
(apply-brightness image -50)  ;; 减暗
```

---

#### `apply-contrast`

```lisp
(apply-contrast image adjustment)
```

调整对比度。

**参数:**
- `adjustment` - 调整值 -128 到 128（正=更高对比度）

---

#### `apply-saturation`

```lisp
(apply-saturation image adjustment)
```

调整饱和度。

**参数:**
- `adjustment` - 调整值 -100 到 100（正=更饱和）

---

#### `apply-warmth`

```lisp
(apply-warmth image &key warmth)
```

调整色温（暖/冷）。

**参数:**
- `warmth` - 调整值 -50 到 50（正=更暖，负=更冷）

---

### 效果滤镜

#### `apply-blur`

```lisp
(apply-blur image &key radius)
```

应用高斯模糊。

**参数:**
- `radius` - 模糊半径（默认：2）

---

#### `apply-sharpen`

```lisp
(apply-sharpen image &key amount)
```

应用锐化效果。

**参数:**
- `amount` - 锐化强度（默认：1.5）

---

#### `apply-vignette`

```lisp
(apply-vignette image &key darkness radius)
```

应用晕影效果（边缘变暗）。

**参数:**
- `darkness` - 晕影暗度 0.0-1.0（默认：0.5）
- `radius` - 中心半径 0.0-1.0（默认：0.7）

---

#### `apply-noise`

```lisp
(apply-noise image &key amount)
```

添加噪点/胶片颗粒效果。

**参数:**
- `amount` - 噪点量 0-100（默认：10）

---

#### `apply-pixelate`

```lisp
(apply-pixelate image &key pixel-size)
```

应用像素化/马赛克效果。

**参数:**
- `pixel-size` - 像素块大小（默认：8）

---

## 3. Instagram 滤镜

### 滤镜列表

| 滤镜名称 | 描述 |
|----------|------|
| `clarendon` | 明亮、鲜艳、微冷色调 |
| `ginger` | 温暖、黄金时刻光晕 |
| `moon` | 黑白高对比度 |
| `nashville` | 复古粉紫色调 |
| `perpetua` | 柔和、空灵的淡色 |
| `aden` | 柔和桃色复古 |
| `reyes` | 柔和复古、玫瑰色 |
| `juno` | 鲜艳的红色和黄色 |
| `slumber` | 褪色的梦幻复古 |
| `crema` | 奶油色、柔和色调 |
| `ludwig` | 低饱和度、轻微褪色 |
| `inkwell` | 纯黑白 |
| `haze` | 柔光、褪色高光 |
| `drama` | 高对比度、饱和 |
| `x-pro-ii` | 鲜艳金色调 |
| `sutro` | 暗色、忧郁、低饱和 |
| `toaster` | 复古橙色调 |
| `valencia` | 温暖褪色复古 |
| `walden` | 明亮黄色调 |
| `willow` | 冷色柔和黑白 |
| `rise` | 柔光、暖色淡彩 |
| `brannan` | 高对比度金属感 |
| `earlybird` | 暖色棕褐色调 |
| `helena` | 热带、青色阴影 |
| `gingham` | 褪色复古黄色调 |
| `1977` | 红色复古 |
| `sierra` | 褪色柔和色调 |
| `kelvin` | 暖色饱和橙色 |
| `stinson` | 明亮轻微褪色 |
| `maven` | 大地色棕褐色 |
| `ginza` | 明亮冷色调 |
| `amaro` | 轻盈 airy 淡色 |
| `chesterton` | 复古戏剧性 |

### 使用方式

#### `apply-filter-by-name`

```lisp
(apply-filter-by-name image filter-name &key intensity)
```

按名称应用滤镜。

**参数:**
- `image` - 图像对象
- `filter-name` - 滤镜名称字符串
- `intensity` - 强度 0.0-1.0（默认：1.0）

**示例:**
```lisp
(apply-filter-by-name image "clarendon" :intensity 0.8)
```

---

#### `get-available-filters`

```lisp
(get-available-filters)
```

获取所有可用滤镜名称列表。

**返回:**
- 滤镜名称字符串列表

---

#### 直接使用滤镜函数

```lisp
(filter-clarendon image &key intensity)
(filter-ginger image &key intensity)
(filter-moon image &key intensity)
;; ... 等等
```

---

## 4. 叠加和绘图

### 文本叠加

#### `add-text-overlay`

```lisp
(add-text-overlay image text &key x y font-size color opacity)
```

添加文本叠加层。

**参数:**
- `image` - 图像对象
- `text` - 文本字符串
- `x` - X 坐标（默认：居中）
- `y` - Y 坐标（默认：底部）
- `font-size` - 字体大小（默认：24）
- `color` - 颜色 `:white`/`:black` 或 RGB 列表（默认：`:white`）
- `opacity` - 不透明度 0.0-1.0（默认：1.0）

**注意:** 当前实现为 placeholder，需要集成 cl-freetype 进行完整字体渲染。

---

### Emoji 叠加

#### `add-emoji-overlay`

```lisp
(add-emoji-overlay image emoji &key x y size opacity)
```

添加 emoji 叠加层。

**参数:**
- `image` - 图像对象
- `emoji` - Emoji 字符或自定义 emoji ID
- `x` - X 坐标（默认：居中）
- `y` - Y 坐标（默认：居中）
- `size` - 大小（默认：48）
- `opacity` - 不透明度 0.0-1.0（默认：1.0）

**注意:** 当前实现为 placeholder，需要 emoji 字体库支持。

---

### 水印

#### `add-watermark`

```lisp
(add-watermark image watermark-text &key position opacity font-size)
```

添加水印。

**参数:**
- `image` - 图像对象
- `watermark-text` - 水印文本
- `position` - 位置 `:bottom-right`/`:bottom-left`/`:top-right`/`:top-left`/`:center`
- `opacity` - 不透明度 0.0-1.0（默认：0.5）
- `font-size` - 字体大小（默认：16）

---

### 绘图原语

#### `draw-rectangle`

```lisp
(draw-rectangle image x y width height &key color filled stroke-width)
```

绘制矩形。

**参数:**
- `image` - 图像对象
- `x`, `y` - 左上角坐标
- `width`, `height` - 尺寸
- `color` - RGB 列表（默认：`(255 0 0)` 红色）
- `filled` - 是否填充（默认：NIL）
- `stroke-width` - 线宽（默认：2）

---

#### `draw-circle`

```lisp
(draw-circle image center-x center-y radius &key color filled stroke-width)
```

绘制圆形。

**参数:**
- `image` - 图像对象
- `center-x`, `center-y` - 圆心坐标
- `radius` - 半径
- `color` - RGB 列表（默认：`(255 0 0)` 红色）
- `filled` - 是否填充（默认：NIL）
- `stroke-width` - 线宽（默认：2）

---

## 5. 工具函数

### 图像信息

#### `get-image-info`

```lisp
(get-image-info file-path)
```

获取图像文件信息。

**返回:**
- 包含 `:width`, `:height`, `:channels`, `:format`, `:file-size` 的 plist

---

#### `image-exists-p`

```lisp
(image-exists-p file-path)
```

检查文件是否存在且为有效图像。

---

#### `validate-image-file`

```lisp
(validate-image-file file-path)
```

验证图像文件格式和大小。

**返回:**
- T（有效），或错误消息字符串（无效）

**限制:**
- 最大文件大小：50MB

---

### 临时目录

#### `ensure-temp-directory`

```lisp
(ensure-temp-directory)
```

确保临时目录存在。

**返回:**
- 临时目录路径

---

### 全局变量

#### `*temp-directory*`

临时文件目录。

#### `*supported-formats*`

支持的图像格式列表：`("jpg" "jpeg" "png" "gif" "webp" "bmp")`

---

## 错误处理

所有图像处理函数都包含错误处理，失败时返回原始图像或 NIL，并记录错误日志。

```lisp
(handler-case
    (let ((image (load-image "photo.jpg")))
      (when image
        (save-image (filter-clarendon image) "output.jpg")))
  (condition (e)
    (log:error "Image processing failed: ~A" e)))
```

---

## 性能提示

1. **批量处理**: 对多张图片应用相同滤镜时，使用批量处理
2. **缓存**: 对重复处理的图片使用缓存
3. **缩略图**: 处理前先生成缩略图进行预览
4. **质量设置**: 保存 JPEG 时使用适当的质量设置（80-95）

---

## 相关文档

- [Bot API 8.0 使用示例](EXAMPLES_BOT_API_8.md)
- [发布说明](RELEASE_NOTES_v0.23.0.md)
- [Opticl GitHub](https://github.com/rabbibotton/opticl)
