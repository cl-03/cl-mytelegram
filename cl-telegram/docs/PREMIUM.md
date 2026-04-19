# Telegram Premium Features Documentation

## Overview

Telegram Premium unlocks enhanced features and higher limits for power users. This document covers all Premium features implemented in cl-telegram.

## Table of Contents

- [Premium Status](#premium-status)
- [File Uploads](#file-uploads)
- [Premium Stickers & Reactions](#premium-stickers--reactions)
- [Profile Customization](#profile-customization)
- [Voice Transcription](#voice-transcription)
- [Doubled Limits](#doubled-limits)
- [Premium UI](#premium-ui)
- [Examples](#examples)

---

## Premium Status

### Check Premium Status

```lisp
(check-premium-status)
```

Returns `T` if user has Telegram Premium, `NIL` otherwise.

**Caching:** Results are cached for 1 hour by default.

### Verify Premium Status

```lisp
(verify-premium-status)
```

Verify premium status with Telegram servers.

**Returns:** Values `(is-premium error-message)`

**Example:**
```lisp
(multiple-value-bind (is-premium error)
    (verify-premium-status)
  (if is-premium
      (format t "Premium active!")
      (format t "Error: ~A" error)))
```

### Refresh Premium Status

```lisp
(refresh-premium-status)
```

Force refresh premium status from server (bypasses cache).

---

## File Uploads

### Get Max File Size

```lisp
(get-max-file-size)
```

**Returns:** Maximum file size in bytes

| Tier | Max Size |
|------|----------|
| Free | 2 GB (2,147,483,648 bytes) |
| Premium | 4 GB (4,294,967,296 bytes) |

### Check Upload Capability

```lisp
(can-upload-file-p file-size)
```

**Parameters:**
- `file-size` - File size in bytes

**Returns:** `T` if upload is allowed

### Validate File for Upload

```lisp
(validate-file-for-upload file-size file-path)
```

**Parameters:**
- `file-size` - File size in bytes
- `file-path` - Path to file

**Returns:** Values `(success error-message)`

**Example:**
```lisp
(multiple-value-bind (ok error)
    (validate-file-for-upload (* 3 1024 1024 1024) "/path/to/video.mp4")
  (if ok
      (send-video chat-id file-path)
      (format t "Cannot upload: ~A" error)))
```

---

## Premium Stickers & Reactions

### Get Premium Sticker Sets

```lisp
(get-premium-sticker-sets)
```

Returns list of premium-exclusive sticker sets.

### Check Sticker Access

```lisp
(can-use-premium-sticker-p sticker-set-name)
```

**Parameters:**
- `sticker-set-name` - Name of sticker set

**Returns:** `T` if user can use the sticker

### Get Premium Reactions

```lisp
(get-premium-reactions)
```

Returns list of premium-exclusive reaction emojis:
- 🎉 (Party popper)
- 💫 (Dizzy)
- 🌟 (Star)
- 💎 (Gem)
- 🔥 (Fire)
- And more...

### Check Reaction Access

```lisp
(can-send-reaction-p emoji)
```

**Parameters:**
- `emoji` - Reaction emoji

**Returns:** `T` if user can send the reaction

**Example:**
```lisp
;; Send premium reaction
(if (can-send-reaction-p "💎")
    (send-message-reaction chat-id message-id "💎")
    (send-message-reaction chat-id message-id "👍"))
```

---

## Profile Customization

### Profile Colors

```lisp
(get-premium-profile-colors)
```

Returns available premium profile color themes.

**Example themes:**
- Sunset (red to yellow gradient)
- Ocean (blue to cyan gradient)
- Forest (green gradient)
- Purple Haze (purple gradient)
- Midnight (dark gradient)

### Set Profile Color

```lisp
(set-profile-color color-id)
```

**Parameters:**
- `color-id` - ID of color theme

**Requires:** Telegram Premium

### Chat Themes

```lisp
(get-premium-chat-themes)
```

Returns available premium chat themes.

**Example themes:**
- Classic
- Day
- Night
- Arctic
- Ocean
- Mountain

### Set Chat Theme

```lisp
(set-chat-theme chat-id theme-id)
```

**Parameters:**
- `chat-id` - Chat identifier
- `theme-id` - Theme identifier

**Requires:** Telegram Premium

---

## Emoji Statuses

### Get Emoji Statuses

```lisp
(get-premium-emoji-statuses)
```

Returns available premium emoji statuses.

**Example statuses:** ⭐, 💎, 🎉, ✨, 🔥, 💫

### Set Emoji Status

```lisp
(set-emoji-status emoji &key duration)
```

**Parameters:**
- `emoji` - Emoji to use as status
- `duration` - Duration in seconds (NIL for permanent)

**Requires:** Telegram Premium

**Example:**
```lisp
;; Set permanent status
(set-emoji-status "⭐")

;; Set temporary status (24 hours)
(set-emoji-status "🎉" :duration 86400)
```

### Clear Emoji Status

```lisp
(clear-emoji-status)
```

Remove current emoji status.

---

## Voice Transcription

### Get Transcription Hours

```lisp
(get-premium-transcription-hours)
```

Returns remaining premium transcription hours.

### Transcribe Voice Message

```lisp
(transcribe-voice-message-premium message-id)
```

**Parameters:**
- `message-id` - Voice message ID

**Returns:** Transcription text

**Requires:** Telegram Premium

**Example:**
```lisp
(let ((transcription (transcribe-voice-message-premium msg-id)))
  (format t "Voice message says: ~A" transcription))
```

---

## Doubled Limits

### Get Doubled Limits Info

```lisp
(get-doubled-limits)
```

Returns plist with limit information:

| Feature | Free | Premium |
|---------|------|---------|
| Channels | 500 | 1000 |
| Folders | 10 | 20 |
| Pinned Chats | 5 | 10 |
| Saved Tags | 100 | 200 |
| Forward Limit | 1000 | 2000 |
| Download Speed | Standard | Priority |

### Check Pin Capability

```lisp
(can-pin-more-chats-p)
```

Returns `T` if user can pin additional chats.

### Check Channel Join Capability

```lisp
(can-join-more-channels-p)
```

Returns `T` if user can join additional channels.

---

## Premium UI

### Premium Badge

```lisp
(render-premium-badge)
```

Returns "⭐ Premium" string if user has premium, empty string otherwise.

### Premium Features Panel

```lisp
(render-premium-features-panel win container)
```

Renders premium features panel in CLOG UI.

**Features shown:**
- Premium status indicator
- List of enabled features
- Get Premium button (for free users)

### Show Premium Promo

```lisp
(show-premium-promo win)
```

Shows premium promotion modal dialog.

---

## Subscription Management

### Get Subscription Info

```lisp
(get-premium-subscription-info)
```

Returns plist with subscription details:
- `:is-active` - Whether premium is active
- `:expiration-date` - Expiration timestamp
- `:subscription-type` - `:monthly` or `:yearly`
- `:auto-renew` - Auto-renewal status
- `:payment-provider` - Payment provider name

### Cancel Subscription

```lisp
(cancel-premium-subscription)
```

Cancel premium subscription.

### Renew Subscription

```lisp
(renew-premium-subscription duration)
```

**Parameters:**
- `duration` - `:monthly` or `:yearly`

---

## Utilities

### Premium Required Check

```lisp
(premium-required-p feature)
```

**Parameters:**
- `feature` - Keyword symbol of feature

**Returns:** `T` if feature requires premium

**Features that require premium:**
- `:send-large-files`
- `:premium-stickers`
- `:premium-reactions`
- `:emoji-statuses`
- `:profile-colors`
- `:chat-themes`
- `:voice-transcription`
- `:advanced-chat-management`
- `:doubled-limits`

### Ensure Premium

```lisp
(ensure-premium feature &optional error-msg)
```

**Parameters:**
- `feature` - Keyword symbol
- `error-msg` - Optional custom error message

**Signals:** `premium-required-error` if user doesn't have premium

**Example:**
```lisp
(defun send-large-file (chat-id file)
  (ensure-premium :send-large-files)
  ;; File sending code...
  )
```

### Reset Premium Cache

```lisp
(reset-premium-cache)
```

Clear cached premium status.

### Get Premium Stats

```lisp
(get-premium-stats)
```

Returns usage statistics:
- `:is-premium` - Premium status
- `:large-files-sent` - Count of large files sent
- `:premium-stickers-used` - Premium sticker usage
- `:transcriptions-count` - Voice transcription count

---

## Examples

### Premium Feature Guard

```lisp
(defun upload-hd-video (chat-id video-path)
  "Upload HD video (requires premium)"
  (ensure-premium :send-large-files 
                  "HD video uploads require Telegram Premium")
  
  (let ((file-size (file-length video-path)))
    (if (can-upload-file-p file-size)
        (send-video chat-id video-path :quality :hd)
        (error "File too large"))))
```

### Premium Sticker Usage

```lisp
(defun send-premium-sticker (chat-id sticker-set)
  "Send premium sticker if available"
  (if (can-use-premium-sticker-p sticker-set)
      (send-sticker chat-id sticker-set)
      ;; Fallback to free stickers
      (send-sticker chat-id "free-sticker-pack")))
```

### Premium Workflow

```lisp
;; Check and display premium status
(if (check-premium-status)
    (progn
      (format t "⭐ Premium Active~%")
      (format t "Max file size: ~A GB~" 
              (/ (get-max-file-size) 1024 1024 1024))
      (format t "Available reactions: ~A~%" 
              (get-premium-reactions)))
    (progn
      (format t "Free Account~%")
      (format t "Upgrade to Premium for:~%")
      (format t "  - 4GB file uploads~%")
      (format t "  - Premium stickers & reactions~%")
      (format t "  - Profile customization~%")
      (format t "  - Voice transcription~%")))
```

---

## Error Handling

### Premium Required Error

```lisp
(define-condition premium-required-error (error)
  ((feature :initarg :feature :reader premium-error-feature)
   (message :initarg :message :reader premium-error-message)))
```

**Handle errors:**
```lisp
(handler-case
    (ensure-premium :send-large-files)
  (premium-required-error (e)
    (format t "Premium required for: ~A~%" 
            (premium-error-feature e))
    (format t "Message: ~A~%" 
            (premium-error-message e))))
```

---

## See Also

- [Stories API](STORIES.md) - Premium story features
- [Messages API](API_REFERENCE.md#messages) - File upload functions
- [Voice Messages](VOICE.md) - Transcription features
