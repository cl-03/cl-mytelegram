# Media Editing Guide

## Overview

cl-telegram v0.15.0+ includes comprehensive message and media editing capabilities:

- **Message Editing** - Edit text, captions, media, keyboards
- **Media Processing** - Crop, rotate, apply filters, generate thumbnails
- **Overlays** - Add text and emoji overlays to media
- **Live Location** - Edit and stop live location updates

## Table of Contents

1. [Message Editing](#message-editing)
2. [Media Processing](#media-processing)
3. [Overlays](#overlays)
4. [Input Media Types](#input-media-types)
5. [API Reference](#api-reference)

---

## Message Editing

### Edit Message Text

```lisp
(use-package :cl-telegram/api)

;; Basic text edit
(multiple-value-bind (message error)
    (edit-message-text chat-id message-id "Updated text content")
  (if error
      (format t "Error: ~A~%" error)
      (format t "Message updated successfully~%")))

;; Edit with parse mode
(edit-message-text chat-id message-id "**Bold** and _italic_"
                   :parse-mode :markdown)

;; Edit with HTML formatting
(edit-message-text chat-id message-id 
                   "<b>Bold</b> and <i>italic</i>"
                   :parse-mode :html)

;; Edit with inline keyboard
(edit-message-text chat-id message-id "Choose an option:"
                   :reply-markup
                   (make-inline-keyboard
                    :keyboard (list
                               (list (make-inline-button "Option 1" :callback "opt1")
                                     (make-inline-button "Option 2" :callback "opt2")))))
```

### Edit Message Caption

```lisp
;; Edit caption for photo
(edit-message-caption chat-id message-id 
                      "New caption for the photo"
                      :show-caption-above-media t)

;; Edit with Markdown caption
(edit-message-caption chat-id message-id
                      "Photo from *vacation* 🌴"
                      :parse-mode :markdown)

;; Edit with entities
(edit-message-caption chat-id message-id
                      "Check out this link: example.com"
                      :entities (list (make-entity :url 20 10)))
```

### Edit Message Media

```lisp
;; Replace photo
(edit-message-media chat-id message-id
                    (make-input-media-photo :media "new_file_id"
                                            :caption "New photo"))

;; Replace video
(edit-message-media chat-id message-id
                    (make-input-media-video :media "new_video_id"
                                            :caption "Updated video"))

;; Replace with new keyboard
(edit-message-media chat-id message-id
                    (make-input-media-photo :media "file_id")
                    :reply-markup new-keyboard)
```

### Edit Reply Markup Only

```lisp
;; Update inline keyboard without changing message
(edit-message-reply-markup chat-id message-id
                           (make-inline-keyboard
                            :keyboard (list
                                       (list (make-inline-button "New Button" :callback "new")))))
```

### Edit Live Location

```lisp
;; Update live location
(edit-message-live-location chat-id message-id 
                            40.7128  ; latitude
                            -74.0060 ; longitude
                            :heading 90
                            :proximity-alert-radius 100)

;; Stop live location updates
(stop-message-live-location chat-id message-id)

;; Stop with custom keyboard
(stop-message-live-location chat-id message-id
                            :reply-markup
                            (make-inline-keyboard
                             :keyboard (list
                                        (list (make-inline-button "View Map" :url "https://maps.example.com")))))
```

### Unified Edit Interface

```lisp
;; Edit text
(edit-message chat-id message-id :text "New text")

;; Edit caption
(edit-message chat-id message-id :caption "New caption")

;; Edit media
(edit-message chat-id message-id :media new-media)

;; Edit keyboard only
(edit-message chat-id message-id :reply-markup new-keyboard)

;; Edit with multiple options
(edit-message chat-id message-id 
              :text "Updated"
              :parse-mode :html
              :reply-markup keyboard)
```

---

## Media Processing

### Crop Media

```lisp
;; Crop with all parameters
(multiple-value-bind (crop-params error)
    (crop-media "file_id" :x 10 :y 20 :width 100 :height 100)
  (if error
      (format t "Error: ~A~%" error)
      ;; Use crop-params with media upload
      (format t "Crop params: ~A~%" crop-params)))

;; Crop from center (x=0, y=0 means no offset)
(crop-media "file_id" :width 200 :height 200)
```

### Rotate Media

```lisp
;; Rotate 90 degrees clockwise
(rotate-media "file_id" :degrees 90)

;; Rotate 180 degrees
(rotate-media "file_id" :degrees 180)

;; Rotate 270 degrees (or -90)
(rotate-media "file_id" :degrees 270)
```

### Apply Filter

```lisp
(use-package :cl-telegram/api)

;; Available filters:
;; :grayscale, :sepia, :vintage, :dramatic, :pepper
;; :tonal, :noir, :fade, :misty, :serene
;; :soft, :clear, :vivid, :vibrant, :calm

;; Apply grayscale filter
(apply-filter "file_id" :grayscale :intensity 1.0)

;; Apply sepia with 50% intensity
(apply-filter "file_id" :sepia :intensity 0.5)

;; Apply vintage filter
(apply-filter "file_id" :vintage :intensity 0.8)

;; Apply vivid filter for vibrant colors
(apply-filter "file_id" :vivid :intensity 0.9)
```

### Generate Thumbnail

```lisp
;; Generate thumbnail for image
(generate-thumbnail "file_id" :size 320 :format :jpeg)

;; Generate thumbnail from video at 5 seconds
(generate-thumbnail "video_file_id" 
                    :size 320 
                    :format :jpeg 
                    :time-offset 5)

;; Generate PNG thumbnail
(generate-thumbnail "file_id" :size 256 :format :png)

;; Generate WebP thumbnail (smaller size)
(generate-thumbnail "file_id" :size 128 :format :webp)
```

---

## Overlays

### Add Text Overlay

```lisp
;; Add text at bottom
(add-text-overlay "file_id" "Copyright 2026"
                  :position :bottom
                  :size 24
                  :color :white)

;; Add text at top with background
(add-text-overlay "file_id" "Breaking News"
                  :position :top
                  :size 32
                  :color :white
                  :background :blur)

;; Add centered text
(add-text-overlay "file_id" "Title"
                  :position :center
                  :font "Arial"
                  :size 48
                  :color :black)

;; Valid positions:
;; :top, :bottom, :center, :top-left, :top-right
;; :bottom-left, :bottom-right
```

### Add Emoji Sticker Overlay

```lisp
;; Add emoji at top-right
(add-emoji-sticker "file_id" "😀"
                   :position :top-right
                   :size 64)

;; Add emoji at bottom-left
(add-emoji-sticker "file_id" "🎉"
                   :position :bottom-left
                   :size 128)

;; Add large emoji
(add-emoji-sticker "file_id" "❤️"
                   :position :center
                   :size 256)
```

---

## Input Media Types

### InputMediaPhoto

```lisp
(make-input-media-photo 
 :media "file_id_or_url"
 :caption "Photo caption"
 :show-caption-above-media t
 :has-spoiler nil
 :thumbnail "thumb_file_id")
```

### InputMediaVideo

```lisp
(make-input-media-video
 :media "file_id_or_url"
 :caption "Video caption"
 :thumbnail "thumb_file_id"
 :duration 60          ; seconds
 :width 1920
 :height 1080
 :supports-streaming t
 :has-spoiler nil
 :show-caption-above-media t)
```

### InputMediaAudio

```lisp
(make-input-media-audio
 :media "file_id_or_url"
 :caption "Audio caption"
 :thumbnail "thumb_file_id"
 :duration 180         ; seconds
 :performer "Artist Name"
 :title "Song Title")
```

### InputMediaDocument

```lisp
(make-input-media-document
 :media "file_id_or_url"
 :caption "Document caption"
 :thumbnail "thumb_file_id"
 :disable-content-type-detection nil)
```

### InputMediaAnimation (GIF)

```lisp
(make-input-media-animation
 :media "file_id_or_url"
 :caption "Animation caption"
 :thumbnail "thumb_file_id"
 :duration 5           ; seconds
 :width 480
 :height 270
 :has-spoiler nil)
```

---

## Complete Example

```lisp
;; Load system
(asdf:load-system :cl-telegram)
(use-package :cl-telegram/api)

;; Example: Edit message workflow
(defun edit-message-workflow (chat-id message-id)
  "Demonstrate message editing workflow"
  
  ;; 1. Edit text
  (multiple-value-bind (msg error)
      (edit-message-text chat-id message-id "Initial text")
    (when error
      (format t "Failed to edit text: ~A~%" error)
      (return-from edit-message-workflow nil)))
  
  ;; 2. Edit to add formatting
  (edit-message-text chat-id message-id 
                     "**Bold** and _italic_ text"
                     :parse-mode :markdown)
  
  ;; 3. Add inline keyboard
  (edit-message-reply-markup 
   chat-id message-id
   (make-inline-keyboard
    :keyboard (list
               (list (make-inline-button "Like" :callback "like")
                     (make-inline-button "Dislike" :callback "dislike")))))
  
  ;; 4. Edit caption (if media message)
  (edit-message-caption chat-id message-id 
                        "Updated caption with emoji 🎉"
                        :show-caption-above-media t))

;; Example: Media processing workflow
(defun process-and-send-media (chat-id original-file-id)
  "Process media and send with edits"
  
  ;; 1. Generate thumbnail
  (multiple-value-bind (thumb-params thumb-error)
      (generate-thumbnail original-file-id :size 320 :format :jpeg)
    (when thumb-error
      (format t "Thumbnail error: ~A~%" thumb-error)))
  
  ;; 2. Apply filter
  (multiple-value-bind (filtered-params filter-error)
      (apply-filter original-file-id :vivid :intensity 0.8)
    (when filter-error
      (format t "Filter error: ~A~%" filter-error)))
  
  ;; 3. Add text overlay
  (multiple-value-bind (overlay-params overlay-error)
      (add-text-overlay original-file-id "Processed Image"
                        :position :bottom
                        :size 24
                        :color :white)
    (when overlay-error
      (format t "Overlay error: ~A~%" overlay-error)))
  
  ;; 4. Send edited media
  (edit-message-media chat-id message-id
                      (make-input-media-photo 
                       :media original-file-id
                       :caption "Processed with vivid filter ✨"
                       :show-caption-above-media t)))

;; Example: Live location tracking
(defun track-location (chat-id message-id coordinates-stream)
  "Update live location with coordinate stream"
  (dolist (coords coordinates-stream)
    (destructuring-bind (lat lon &optional heading) coords
      (edit-message-live-location chat-id message-id lat lon
                                  :heading (or heading 0))
      (sleep 5)))) ; Update every 5 seconds
```

---

## API Reference

### Message Editing

| Function | Description |
|----------|-------------|
| `edit-message-text` | Edit message text |
| `edit-message-caption` | Edit media caption |
| `edit-message-media` | Edit media content |
| `edit-message-reply-markup` | Edit inline keyboard |
| `edit-message-live-location` | Update live location |
| `stop-message-live-location` | Stop location updates |
| `edit-message-checklist` | Edit checklist items |
| `edit-message` | Unified edit interface |

### Media Processing

| Function | Description |
|----------|-------------|
| `crop-media` | Crop media file |
| `rotate-media` | Rotate media (90, 180, 270) |
| `apply-filter` | Apply visual filter |
| `generate-thumbnail` | Generate thumbnail |

### Overlays

| Function | Description |
|----------|-------------|
| `add-text-overlay` | Add text overlay |
| `add-emoji-sticker` | Add emoji overlay |

### Input Media Helpers

| Function | Description |
|----------|-------------|
| `make-input-media-photo` | Create photo input |
| `make-input-media-video` | Create video input |
| `make-input-media-audio` | Create audio input |
| `make-input-media-document` | Create document input |
| `make-input-media-animation` | Create animation input |

---

## Constraints and Limits

| Constraint | Limit |
|------------|-------|
| Message text length | 0-4096 characters |
| Caption length | 0-1024 characters |
| Thumbnail size | 64-1280 pixels |
| Filter intensity | 0.0-1.0 |
| Font size (overlay) | 8-72 pixels |
| Emoji size | 16-256 pixels |
| Rotation angles | 90, 180, 270 degrees |

---

## Best Practices

1. **Validate before editing**: Check message ownership before editing
2. **Preserve formatting**: Maintain parse-mode consistency
3. **Test thumbnails**: Verify thumbnail generation for different media types
4. **Filter intensity**: Use moderate intensity (0.5-0.8) for natural look
5. **Location updates**: Rate limit location updates (every 5-10 seconds)

---

**Version:** v0.15.0  
**Last Updated:** April 2026
