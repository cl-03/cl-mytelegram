# Release Notes - cl-telegram v0.26.0

**Release Date:** 2026-04-20

**Version:** 0.26.0

## Overview

cl-telegram v0.26.0 introduces advanced group video call features, Telegram-style video messages, and smart media album management. This release significantly enhances the multimedia and real-time communication capabilities of the library.

## 🎉 Major Features

### 1. Group Video Call Enhancements

Complete multi-participant video calling system:

- **Multi-Participant Video** (`group-video-call.lisp`)
  - `start-group-video-stream` - Start video in group call
  - `stop-group-video-stream` - Stop video stream
  - Support for 10+ simultaneous participants
  - Automatic video quality adaptation

- **Screen Sharing**
  - `enable-screen-sharing` - Share screen with participants
  - `disable-screen-sharing` - Stop screen sharing
  - `get-screen-share-streams` - Get active screen shares
  - Full screen or window capture support

- **Video Quality Control**
  - `set-video-quality` - Set quality (:ld, :sd, :hd, :fhd)
  - `get-video-quality` - Get current quality
  - `calculate-adaptive-quality` - Auto-adjust based on bandwidth
  - Quality presets optimized for different network conditions

- **Video Layout Management**
  - `get-group-video-layout` - Get current layout
  - `pin-participant-video` - Pin participant to prominent position
  - `unpin-participant-video` - Unpin participant
  - `set-video-layout-type` - Switch between grid/speaker/spotlight

- **Call Recording**
  - `toggle-group-call-recording` - Start/stop recording
  - `stop-group-call-recording` - Stop and save recording
  - `get-group-call-recording` - Get recording info
  - Automatic timestamp and storage management

- **AI Noise Reduction**
  - `enable-ai-noise-reduction` - Enable noise suppression
  - `disable-ai-noise-reduction` - Disable noise reduction
  - Configurable levels (:off, :low, :medium, :high, :auto)

**Example:**
```lisp
(asdf:load-system :cl-telegram)
(use-package :cl-telegram/api)

;; Initialize group video
(init-group-video :max-participants 10 :default-quality :hd)

;; Join group call and start video
(join-group-call group-call-id)
(start-group-video-stream group-call-id :resolution :hd :fps 30)

;; Enable screen sharing
(enable-screen-sharing group-call-id :quality :screen)

;; Pin a participant's video
(pin-participant-video group-call-id participant-id)

;; Start recording
(toggle-group-call-recording group-call-id)

;; Enable AI noise reduction
(enable-ai-noise-reduction group-call-id :level :medium)

;; Stop when done
(stop-group-video-stream group-call-id)
```

### 2. Video Messages

Telegram-style circular video messages:

- **Recording** (`video-messages.lisp`)
  - `start-video-message-recording` - Start recording
  - `stop-video-message-recording` - Stop and process
  - `pause-video-message-recording` - Pause recording
  - `resume-video-message-recording` - Resume recording
  - `cancel-video-message-recording` - Cancel and cleanup
  - `get-recording-progress` - Get current progress

- **Video Processing**
  - `process-video-message` - Process recorded video
  - `crop-video-to-circle` - Crop to circular format
  - `compress-video` - Compress to target size
  - `generate-video-thumbnail` - Generate thumbnail

- **Sending/Receiving**
  - `send-video-message` - Send video message to chat
  - `download-video-message` - Download received video
  - `parse-video-message` - Parse message object
  - `play-video-message` - Play video message

- **Utilities**
  - `get-video-metadata` - Extract duration, dimensions
  - `is-valid-video-message` - Validate video file

**Example:**
```lisp
;; Record video message
(start-video-message-recording :duration-limit 60 :quality :medium)
(sleep 5) ; Record for 5 seconds
(multiple-value-bind (path duration)
    (stop-video-message-recording)
  (format t "Recorded ~D seconds: ~A~%" duration path))

;; Send video message
(send-video-message chat-id path :caption "Check this out!")

;; Receive and play
(let ((msg (get-message message-id chat-id)))
  (when msg
    (let ((video (parse-video-message msg)))
      (when video
        (play-video-message (video-message-file-path video))))))
```

### 3. Media Album Management

Smart media organization and management:

- **Album CRUD** (`media-albums.lisp`)
  - `create-media-album` - Create new album
  - `delete-media-album` - Delete album
  - `edit-media-album` - Edit album metadata
  - `get-media-albums` - Get all albums for chat
  - `get-media-album` - Get album details

- **Media Management**
  - `add-media-to-album` - Add media to album
  - `remove-media-from-album` - Remove media
  - `reorder-album-media` - Reorder media in album

- **Smart Albums**
  - `auto-create-albums` - Auto-create from media patterns
  - `detect-media-events` - Detect events (trips, parties)
  - Group by date, event, or custom criteria

- **Tag System**
  - `add-media-tags` - Add tags to media
  - `remove-media-tags` - Remove tags
  - `search-media-by-tags` - Search by tags
  - `get-popular-tags` - Get most used tags

- **Search & Filter**
  - `search-media` - Search with multiple filters
  - `filter-media-by-type` - Filter by type
  - `get-media-timeline` - Get chronological timeline

- **Export**
  - `export-media-album` - Export album to directory
  - `export-all-media` - Export all media from chat

**Example:**
```lisp
;; Create album
(multiple-value-bind (album-id error)
    (create-media-album "Summer Vacation 2024" chat-id
                        :description "Our summer trip")
  ;; Add media
  (add-media-to-album album-id media-ids)
  ;; Add tags
  (add-media-tags media-id '("vacation" "summer" "beach")))

;; Auto-create albums from existing media
(auto-create-albums chat-id :by-date t :by-event t :min-items 3)

;; Search media
(search-media chat-id
              :type :photo
              :tags '("vacation")
              :date-from (encode-universal-time 0 0 0 1 1 2024))

;; Export album
(export-media-album album-id "/path/to/export/")
```

## 📦 New Files

### API Layer
```
src/api/
├── group-video-call.lisp       # Group video calls (~900 lines)
├── video-messages.lisp         # Video messages (~600 lines)
└── media-albums.lisp           # Media albums (~800 lines)
```

### Tests
```
tests/
└── v0.26.0-tests.lisp          # v0.26.0 test suite (50+ tests)
```

## 🔧 API Changes

### New Exports (api-package.lisp)

```lisp
;; Group Video Call (v0.26.0)
#:init-group-video
#:start-group-video-stream
#:stop-group-video-stream
#:enable-screen-sharing
#:disable-screen-sharing
#:set-video-quality
#:get-group-video-layout
#:pin-participant-video
#:toggle-group-call-recording
#:enable-ai-noise-reduction
#:get-group-video-stats

;; Video Messages (v0.26.0)
#:start-video-message-recording
#:stop-video-message-recording
#:pause-video-message-recording
#:get-recording-progress
#:send-video-message
#:process-video-message

;; Media Albums (v0.26.0)
#:create-media-album
#:get-media-albums
#:add-media-to-album
#:auto-create-albums
#:add-media-tags
#:search-media
#:export-media-album
```

## 🧪 Tests

New test suites:

- `v0.26.0-tests.lisp` - 50+ tests covering:
  - Group video call initialization and streaming
  - Screen sharing functionality
  - Video quality control
  - Call recording
  - Video message recording and processing
  - Media album CRUD operations
  - Tag system and search

## 📚 Documentation

- `docs/RELEASE_NOTES_v0.26.0.md` (this file)
- `docs/GAP_ANALYSIS_V0.25.0.md` - Updated gap analysis
- `docs/V0.26.0_DEVELOPMENT_PLAN.md` - Development plan

## 🚀 Usage Examples

### Group Video Call Complete Flow

```lisp
(asdf:load-system :cl-telegram)
(use-package :cl-telegram/ui)
(use-package :cl-telegram/api)

;; Start web UI
(run-web-server)

;; Initialize group video
(init-group-video :max-participants 10)

;; Create or join group call
(multiple-value-bind (call-info error)
    (create-group-call chat-id :is-video-chat t)
  (unless error
    ;; Join the call
    (join-group-call (getf call-info :group-call-id))
    
    ;; Start video
    (start-group-video-stream (getf call-info :group-call-id)
                              :resolution :hd)
    
    ;; Share screen if needed
    (enable-screen-sharing (getf call-info :group-call-id))
    
    ;; Record the call
    (toggle-group-call-recording (getf call-info :group-call-id))
    
    ;; Enable noise reduction
    (enable-ai-noise-reduction (getf call-info :group-call-id)
                               :level :auto)))
```

### Video Message Flow

```lisp
;; Record
(start-video-message-recording :duration-limit 60)
;; Wait for user to finish...
(multiple-value-bind (path duration error)
    (stop-video-message-recording)
  (unless error
    ;; Send
    (send-video-message chat-id path :caption "Video message")))
```

### Media Album Workflow

```lisp
;; Create album for event
(multiple-value-bind (album-id error)
    (create-media-album "Conference 2024" chat-id
                        :description "Tech conference photos")
  (unless error
    ;; Add photos as they come in
    (dolist (media-id new-media-ids)
      (add-media-to-album album-id (list media-id))
      (add-media-tags media-id '("conference" "2024")))
    
    ;; Export after event
    (export-media-album album-id "~/exports/conference-2024/")))
```

## ⚠️ Breaking Changes

None. This release is backwards compatible with v0.25.0.

## 🐛 Bug Fixes

- Fixed video stream state management
- Corrected layout participant tracking
- Fixed media tag index updates

## 🔜 Coming Next (v0.27.0)

- Chat enhancement features
- Auto-delete messages
- Chat backup/export
- Message statistics
- Global media search
- Link and file libraries

## 📊 Statistics

- **Total Lines of Code:** ~55,000+
- **New Files:** 4+
- **New API Functions:** 60+
- **Test Coverage:** 50+ new tests
- **Video Quality Presets:** 5 (LD, SD, HD, FHD, Screen)
- **Max Group Video Participants:** 10+
- **Supported Media Types:** Photo, Video, Document, Audio

## 📝 License

Boost Software License 1.0

---

**Full changelog available at:** `git log v0.25.0..v0.26.0`
