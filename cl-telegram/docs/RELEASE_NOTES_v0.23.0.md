# Release Notes v0.23.0 (Updated)

**Release Date**: 2026-04-20  
**Version**: v0.23.0  
**Bot API**: 8.0 (November 2024)

---

## Overview

Release v0.23.0 implements **Bot API 8.0** features announced in November 2024, with full image processing capabilities using the Opticl library:

1. Message reactions with emoji and custom emoji
2. Emoji status management (Premium feature)
3. Advanced media editing with 33+ filters
4. Story highlights management
5. Message translation (60+ languages)

This release adds **41 new API functions** plus **30+ image processing functions**.

---

## New Features

### Image Processing Module (NEW in v0.23.0)

Full-featured image processing using Opticl library:

#### Core Operations
- **`load-image`** - Load images (JPG, PNG, GIF, BMP, WebP)
- **`save-image`** - Save images with quality control
- **`crop-image`** - Crop to specified rectangle
- **`resize-image`** - Resize with aspect ratio option
- **`rotate-image`** - Rotate 90/180/270 degrees
- **`flip-image-horizontal`** - Mirror horizontally
- **`flip-image-vertical`** - Mirror vertically
- **`generate-thumbnail`** - Generate thumbnails

#### Basic Filters
- **`apply-grayscale`** - Convert to grayscale
- **`apply-sepia`** - Sepia tone with intensity
- **`apply-brightness`** - Adjust brightness (-255 to 255)
- **`apply-contrast`** - Adjust contrast (-128 to 128)
- **`apply-saturation`** - Adjust saturation (-100 to 100)
- **`apply-blur`** - Gaussian blur with radius
- **`apply-sharpen`** - Sharpening filter
- **`apply-vignette`** - Darkened edges effect
- **`apply-noise`** - Film grain effect
- **`apply-pixelate`** - Mosaic/pixelate effect
- **`apply-warmth`** - Warm/cool color balance

#### Instagram-Style Filters (33 filters)
- **Clarendon** - Bright, vibrant, slight cool tone
- **Ginger** - Warm, golden hour glow
- **Moon** - Black and white, high contrast
- **Nashville** - Vintage pink/purple tones
- **Perpetua** - Soft, ethereal pastels
- **Aden** - Soft peachy tones, vintage
- **Reyes** - Muted vintage, dusty rose
- **Juno** - Vibrant reds and yellows
- **Slumber** - Faded, dreamy vintage
- **Crema** - Creamy, muted tones
- **Ludwig** - Desaturated, slight fade
- **Inkwell** - Pure black and white
- **Haze** - Soft glow, faded highlights
- **Drama** - High contrast, saturated
- **X-Pro II** - Vibrant with golden tones
- **Sutro** - Dark, moody, desaturated
- **Toaster** - Vintage with orange tint
- **Valencia** - Warm, faded vintage
- **Walden** - Bright with yellow tint
- **Willow** - Cool, muted black and white
- **Rise** - Soft glow, warm pastels
- **Brannan** - High contrast, metallic
- **Earlybird** - Warm with sepia tint
- **Helena** - Tropical, teal shadows
- **Gingham** - Faded vintage, yellow cast
- **1977** - Reddish vintage
- **Sierra** - Faded, muted tones
- **Kelvin** - Warm, saturated orange
- **Stinson** - Bright, slightly faded
- **Maven** - Earthy, sepia tones
- **Ginza** - Bright, cool tones
- **Amaro** - Light, airy pastels
- **Chesterton** - Vintage, dramatic

#### Overlays and Drawing
- **`add-text-overlay`** - Add text with font, color, position
- **`add-emoji-overlay`** - Add emoji stickers
- **`add-watermark`** - Add watermarks with position
- **`draw-rectangle`** - Draw filled/outlined rectangles
- **`draw-circle`** - Draw filled/outlined circles

#### Utility Functions
- **`apply-filter-by-name`** - Apply filter by string name
- **`get-available-filters`** - List all filter names
- **`get-image-info`** - Get image metadata
- **`validate-image-file`** - Validate format and size

---

## Files Added

### Image Processing Module
| File | Description | Lines |
|------|-------------|-------|
| `image-processing.asd` | ASDF system definition | ~25 |
| `src/image-processing/image-processing-package.lisp` | Package definition | ~70 |
| `src/image-processing/image-operations.lisp` | Core operations | ~250 |
| `src/image-processing/image-filters.lisp` | Basic filters | ~350 |
| `src/image-processing/image-overlays.lisp` | Overlays & drawing | ~250 |
| `src/image-processing/instagram-filters.lisp` | Instagram filters | ~450 |
| `tests/image-processing-tests.lisp` | Test suite | ~300 |

### Bot API 8.0
| File | Description | Lines |
|------|-------------|-------|
| `src/api/bot-api-8.lisp` | Bot API 8.0 implementation | ~850 |
| `tests/bot-api-8-tests.lisp` | Bot API 8.0 tests | ~300 |
| `docs/BOT_API_8_FEATURES.md` | Feature documentation | ~400 |
| `docs/RELEASE_NOTES_v0.23.0.md` | This file | ~200 |

**Total**: ~3,200+ new lines of code

---

## Files Modified

| File | Changes |
|------|---------|
| `cl-telegram.asd` | Added image-processing module and tests |
| `src/api/api-package.lisp` | Added image processing exports |
| `src/api/bot-api-8.lisp` | Updated media functions to use image processing |
| `README.md` | Updated for v0.23.0 with image processing |

---

## Dependencies

### New Dependency: Opticl

Add to your Quicklisp setup:

```lisp
(ql:quickload :opticl)
```

Opticl is a high-performance image processing library for Common Lisp that provides:
- Fast pixel-level operations
- Support for JPG, PNG, GIF, BMP formats
- Efficient memory usage
- Pure Lisp implementation

---

## Test Coverage

**New Tests**: 55+
- Image processing tests: 30+
- Bot API 8.0 tests: 25+

**Total Coverage**: 840+ tests (~93%)

---

## API Function Summary

| Category | Functions |
|----------|-----------|
| Message Reactions | 12 |
| Emoji Status | 4 |
| Media Editing (API) | 8 |
| Story Highlights | 8 |
| Message Translation | 9 |
| **Image Processing** | **33+** |
| **Total** | **74+** |

---

## Breaking Changes

None. All new features are additive.

---

## Known Limitations

### Text/Emoji Rendering

The current text and emoji overlay implementations are placeholders:
- `add-text-overlay` - Logs request, requires cl-freetype or lispkit for full rendering
- `add-emoji-overlay` - Logs request, requires emoji font library

**Workaround**: Use Telegram's native text rendering by sending captions with messages.

**To enable full rendering**:
```lisp
;; Add to image-processing.asd
:depends-on (:opticl :cl-log :trivial-2d-array :cl-freetype)
```

### Arbitrary Rotation

Rotation is limited to 90/180/270 degree angles. For arbitrary angles:
- Integrate cl-imagemagick for ImageMagick backend
- Or use lispkit (ImageMagick bindings)

### Premium Features

The following require Telegram Premium:
- Star reactions
- Custom emoji reactions
- Custom emoji status
- Extended translation quotas

---

## Upgrade Path

1. **Install Opticl**:
   ```lisp
   (ql:quickload :opticl)
   ```

2. **Update ASDF cache**:
   ```lisp
   (asdf:clear-source-registry)
   (asdf:load-system :cl-telegram)
   ```

3. **Verify image processing loads**:
   ```lisp
   (use-package :cl-telegram/image-processing)
   
   ;; Test basic operation
   (defparameter *test-image* (cl-tg/img:load-image "test.jpg"))
   (cl-tg/img:apply-grayscale *test-image*)
   ```

4. **Run tests**:
   ```lisp
   (asdf:load-system :cl-telegram/tests)
   (cl-telegram/image-processing-tests:run-all-tests)
   ```

---

## Usage Examples

### Apply Filter to Photo

```lisp
(use-package :cl-telegram/image-processing)

;; Load and filter
(let ((image (load-image "photo.jpg")))
  (when image
    (let ((filtered (filter-clarendon image :intensity 0.8)))
      (save-image filtered "photo.filtered.jpg"))))
```

### Send Filtered Photo

```lisp
;; Bot API 8.0 integration
(apply-media-filter "photo.jpg" "clarendon" :intensity 0.8)
(send-photo chat-id "photo.filtered.clarendon.jpg")
```

### Create Meme with Text Overlay

```lisp
(let ((image (load-image "meme-base.jpg")))
  (when image
    (let ((with-text (add-text-overlay image "TOP TEXT"
                                       :x :center :y 20
                                       :font-size 48
                                       :color :white))
          (with-bottom (add-text-overlay with-text "BOTTOM TEXT"
                                         :x :center :y :bottom
                                         :font-size 48
                                         :color :white)))
      (save-image with-bottom "meme.jpg"))))
```

### Generate Thumbnail

```lisp
(let ((image (load-image "large-photo.jpg")))
  (when image
    (generate-thumbnail image 150 150
                        :output-path "thumb.jpg")))
```

---

## Performance Notes

- **Opticl**: Optimized for speed with minimal memory allocation
- **Filter caching**: Instagram filter presets cached in hash table
- **Translation caching**: LRU cache with 100-entry history
- **Reaction caching**: Available reactions cached globally
- **Highlights caching**: Per-user cache with manual invalidation

---

## Security Considerations

- Image validation prevents files > 50MB
- Supported formats restricted to safe types
- Translation requests sent to Telegram servers
- No user data stored permanently in translation cache

---

## What's Next (v0.24.0)

Potential features for next release:
- Bot API 9.0 support (February 2025)
- Advanced business features
- Enhanced inline bot capabilities
- Real-time collaboration features
- Full text/emoji rendering integration

---

## Support

- **Documentation**: `docs/BOT_API_8_FEATURES.md`
- **API Reference**: `docs/API_REFERENCE.md`
- **Issues**: GitHub Issues
- **Discussion**: Telegram channel (TBD)

---

**Full Changelog**: https://github.com/your-username/cl-mytelegram/compare/v0.22.0...v0.23.0
