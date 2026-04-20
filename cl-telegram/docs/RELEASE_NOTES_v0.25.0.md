# Release Notes - cl-telegram v0.25.0

**Release Date:** 2026-04-20

**Version:** 0.25.0

## Overview

cl-telegram v0.25.0 introduces powerful new features for message translation, story highlights management, channel reactions with emoji status, and advanced media editing capabilities. This release significantly expands the bot API compatibility and user-facing features.

## 🎉 Major Features

### 1. Message Translation (60+ Languages)

Complete message translation system with support for 60+ languages:

- **Core Translation** (`translation.lisp`)
  - `translate-text` - Translate arbitrary text
  - `translate-message` - Translate individual messages
  - `translate-messages` - Bulk message translation
  - `translate-chat-messages` - Translate recent chat messages
  - 60+ languages including Chinese, Japanese, Russian, German, French, Spanish, etc.

- **Language Preferences**
  - Per-chat language settings
  - Global auto-translation toggle
  - Translation cache (LRU, 1000 entries)
  - Translation history (last 100)

- **API Integration**
  - DeepL API support (default)
  - Google Translate compatibility
  - LibreTranslate support (self-hosted option)
  - Auto-detect source language

- **Auto-Translation**
  - Real-time incoming message translation
  - Configurable update handlers
  - Preserves message entities and formatting

**Example:**
```lisp
;; Configure translation API
(configure-translation-api :provider :deepl :api-key "your-key")

;; Translate text
(translate-text "Hello, World!" :zh)
;; => "你好，世界！"

;; Set chat language preference
(set-chat-language chat-id :ja)

;; Enable auto-translation
(enable-auto-translation t)

;; Translate a message
(translate-message message-id chat-id :en)
```

### 2. Story Highlights Management

Complete story highlights system:

- **CRUD Operations** (`story-highlights.lisp`)
  - `create-story-highlight` - Create highlights with custom covers
  - `edit-story-highlight` - Edit title, description, stories, privacy
  - `edit-highlight-cover` - Edit cover with crop and rotation
  - `delete-story-highlight` - Delete highlights
  - `reorder-story-highlights` - Reorder highlights in profile

- **Story Management**
  - `add-stories-to-highlight` - Add stories to existing highlight
  - `remove-stories-from-highlight` - Remove specific stories
  - `archive-story-to-highlight` - Archive story directly to highlight

- **Privacy Controls**
  - Public - Anyone can see
  - Contacts - Only contacts can see
  - Close Friends - Only close friends can see
  - Custom - Custom privacy rules

- **Utilities**
  - Search highlights by title/description
  - Get highlight count
  - Export highlights
  - Cache management

**Example:**
```lisp
;; Create highlight
(create-story-highlight "Travel 2024" '(1001 1002 1003)
                        :cover-story-id 1001
                        :description "My travels"
                        :privacy :public)

;; Edit highlight
(edit-story-highlight highlight-id
                      :title "Updated Title"
                      :privacy :contacts)

;; Reorder highlights
(reorder-story-highlights '(3 1 2))

;; Search highlights
(search-highlights "Travel" user-id)
```

### 3. Channel Reactions & Emoji Status

Advanced reactions and emoji status features:

- **Message Reactions** (`channel-reactions.lisp`)
  - `send-channel-message-reaction` - Send reactions (emoji or custom)
  - `remove-channel-message-reaction` - Remove reactions
  - `get-channel-message-reactions` - Get reaction breakdown
  - `get-recent-channel-reactors` - Get users who reacted

- **Reaction Analytics**
  - `get-channel-reaction-stats` - Detailed statistics
  - `get-channel-reaction-analytics` - Channel-wide analytics
  - `get-reaction-trend` - Reaction trends over time

- **Emoji Status**
  - `set-emoji-status` - Set user emoji status
  - `clear-emoji-status` - Clear status
  - `get-emoji-statuses` - Get available statuses
  - `get-premium-emoji-statuses` - Premium-only statuses
  - `get-user-emoji-status` - Get user's current status

- **Available Reactions**
  - `get-channel-available-reactions` - Get available reactions
  - `set-channel-available-reactions` - Configure for channel

**Example:**
```lisp
;; Send reaction
(send-channel-message-reaction channel-id message-id "👍")
(send-channel-message-reaction channel-id message-id 54321 :is-big t) ; Custom emoji

;; Get reactions
(get-channel-message-reactions channel-id message-id)

;; Get reaction stats
(get-channel-reaction-stats channel-id message-id)

;; Set emoji status
(set-emoji-status 54321 :duration 3600) ; 1 hour

;; Get user status
(get-user-emoji-status user-id)
```

### 4. Advanced Media Editing

Professional-grade media editing:

- **Image Enhancement** (`advanced-media-editing.lisp`)
  - `enhance-image` - AI-powered enhancement
  - `auto-enhance-image` - Automatic enhancements
  - `denoise-image` - Noise reduction
  - `sharpen-image` - Image sharpening
  - `upscale-image` - 2x upscaling

- **Color Adjustments**
  - `adjust-image-brightness` - Brightness control
  - `adjust-image-contrast` - Contrast adjustment
  - `adjust-image-saturation` - Saturation control
  - `adjust-image-tonemap` - Tone mapping

- **Professional Filters**
  - `apply-cinematic-filter` - Cinematic look
  - `apply-vintage-filter` - Vintage film effect
  - `apply-teal-orange-grade` - Hollywood color grade
  - `apply-vignette` - Vignette effect
  - `add-film-grain` - Film grain texture

- **Batch Processing**
  - `batch-process-images` - Process multiple images
  - `convert-image-format` - Format conversion (PNG/JPEG/WebP/BMP)

- **Watermarking**
  - `add-watermark` - Text watermark
  - `add-logo-watermark` - Logo overlay

**Example:**
```lisp
;; Enhance image
(enhance-image "input.jpg" "output.jpg" :enhancement :auto)

;; Apply filter
(apply-professional-filter image :cinematic :intensity 1.0)

;; Batch process
(batch-process-images "*.jpg" "output/"
                      (lambda (path) (enhance-image path path)))

;; Adjust colors
(adjust-image-contrast image 1.2)
(adjust-image-saturation image 1.15)

;; Add watermark
(add-watermark image "© 2024" :position :bottom-right)
```

## 📦 New Files

### API Layer
```
src/api/
├── translation.lisp              # Message translation (500+ lines)
├── story-highlights.lisp         # Story highlights (450+ lines)
├── channel-reactions.lisp        # Reactions & emoji status (400+ lines)
└── advanced-media-editing.lisp   # Media editing (600+ lines)
```

### Tests
```
tests/
├── translation-tests.lisp        # Translation tests (30+ tests)
├── story-highlights-tests.lisp   # Highlights tests (25+ tests)
└── channel-reactions-tests.lisp  # Reactions tests (20+ tests)
```

## 🔧 API Changes

### New Exports (api-package.lisp)

```lisp
;; Translation
#:translate-text
#:translate-message
#:translate-chat-messages
#:set-chat-language
#:enable-auto-translation
#:configure-translation-api

;; Story Highlights
#:create-story-highlight
#:edit-story-highlight
#:delete-story-highlight
#:reorder-story-highlights
#:get-story-highlights

;; Channel Reactions
#:send-channel-message-reaction
#:get-channel-message-reactions
#:set-emoji-status
#:get-emoji-statuses

;; Advanced Media Editing
#:enhance-image
#:apply-professional-filter
#:adjust-image-brightness
#:batch-process-images
#:add-watermark
```

## 🧪 Tests

New test suites:

- `translation-tests.lisp` - 30+ tests for translation features
- `story-highlights-tests.lisp` - 25+ tests for highlights
- `channel-reactions-tests.lisp` - 20+ tests for reactions

## 📚 Documentation

- `docs/RELEASE_NOTES_v0.25.0.md` (this file)

## 🚀 Usage Examples

### Message Translation

```lisp
(asdf:load-system :cl-telegram)
(use-package :cl-telegram/api)

;; Configure API
(configure-translation-api :provider :deepl :api-key "your-key")

;; Translate message
(translate-message 100 chat-id :en)

;; Enable auto-translation for all incoming messages
(enable-auto-translation t)
```

### Story Highlights

```lisp
;; Create highlight
(create-story-highlight "Best Of 2024" '(1001 1002 1003)
                        :cover-story-id 1001
                        :privacy :public)

;; Edit privacy
(set-highlight-privacy highlight-id :contacts)

;; Search
(search-highlights "Travel")
```

### Channel Reactions

```lisp
;; Send reaction with big animation
(send-channel-message-reaction channel-id message-id "❤️" :is-big t)

;; Get who reacted
(get-recent-channel-reactors channel-id message-id :limit 20)

;; Set emoji status
(set-emoji-status 54321 :duration 86400) ; 24 hours
```

### Media Editing

```lisp
;; Auto-enhance
(enhance-image "photo.jpg" "enhanced.jpg" :enhancement :auto)

;; Apply cinematic filter
(let ((image (opticl:read-png-file "input.png")))
  (apply-cinematic-filter image :intensity 0.8))

;; Batch convert
(batch-process-images "*.png" "jpeg-output/"
                      (lambda (in out)
                        (convert-image-format in :jpeg :quality 90)))
```

## ⚠️ Breaking Changes

None. This release is backwards compatible with v0.24.0.

## 🐛 Bug Fixes

- Fixed translation cache key generation
- Corrected privacy string conversion
- Fixed reaction cache invalidation

## 🔜 Coming Next (v0.26.0)

- Scheduled messages
- Custom emoji packs
- Chat folders sync
- Premium features expansion
- Voice message transcription

## 📊 Statistics

- **Total Lines of Code:** ~28,000+
- **New Files:** 8+
- **New API Functions:** 80+
- **Test Coverage:** 80%+
- **Supported Languages:** 60+ (translation)

## 📝 License

Boost Software License 1.0

---

**Full changelog available at:** `git log v0.24.0..v0.25.0`
