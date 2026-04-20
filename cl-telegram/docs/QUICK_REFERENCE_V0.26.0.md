# cl-telegram v0.26.0 Quick Reference

## Quick Start

```lisp
;; Load and initialize
(asdf:load-system :cl-telegram)
(use-package :cl-telegram/api)
```

---

## Group Video Calls

| Function | Description |
|----------|-------------|
| `init-group-video` &key `:max-participants` `:default-quality` `:recording-dir` | Initialize video subsystem |
| `start-group-video-stream` group-call-id &key `:resolution` `:fps` | Start video stream |
| `stop-group-video-stream` group-call-id | Stop video stream |
| `enable-screen-sharing` group-call-id &key `:quality` `:capture-window` | Share screen |
| `set-video-quality` group-call-id quality | Set quality (`:ld`/`:sd`/`:hd`/`:fhd`) |
| `get-group-video-layout` group-call-id | Get current layout |
| `pin-participant-video` group-call-id participant-id | Pin participant |
| `toggle-group-call-recording` group-call-id | Start/stop recording |
| `enable-ai-noise-reduction` group-call-id &key `:level` | Enable noise reduction |
| `get-group-video-stats` group-call-id | Get statistics |

### Quick Example

```lisp
(init-group-video :max-participants 10 :default-quality :hd)
(join-group-call group-call-id)
(start-group-video-stream group-call-id :resolution :hd :fps 30)
(enable-screen-sharing group-call-id :quality :screen)
(toggle-group-call-recording group-call-id)
(enable-ai-noise-reduction group-call-id :level :auto)
```

---

## Video Messages

| Function | Description |
|----------|-------------|
| `start-video-message-recording` &key `:duration-limit` `:quality` | Start recording |
| `stop-video-message-recording` | Stop recording |
| `pause-video-message-recording` | Pause recording |
| `resume-video-message-recording` | Resume recording |
| `cancel-video-message-recording` | Cancel recording |
| `get-recording-progress` | Get progress plist |
| `process-video-message` input output &key `:compress` `:crop-circular` | Process video |
| `send-video-message` chat-id video-path &key `:caption` | Send video |
| `download-video-message` message-id &key `:chat-id` | Download video |
| `parse-video-message` message | Parse message object |
| `get-video-metadata` video-path | Get duration, dimensions |

### Quick Example

```lisp
(start-video-message-recording :duration-limit 60 :quality :high)
;; ... recording ...
(multiple-value-bind (path duration error)
    (stop-video-message-recording)
  (unless error
    (send-video-message chat-id path :caption "My video message")))
```

---

## Media Albums

| Function | Description |
|----------|-------------|
| `create-media-album` title chat-id &key `:description` | Create album |
| `delete-media-album` album-id | Delete album |
| `edit-media-album` album-id &key `:title` `:description` | Edit album |
| `get-media-albums` chat-id | Get all albums |
| `get-media-album` album-id | Get album details |
| `add-media-to-album` album-id media-ids | Add media |
| `remove-media-from-album` album-id media-ids | Remove media |
| `auto-create-albums` chat-id &key `:by-date` `:by-event` | Auto-create albums |
| `add-media-tags` media-id tags | Add tags |
| `search-media-by-tags` chat-id tags &key `:match-all` | Search by tags |
| `search-media` chat-id &key `:type` `:date-from` `:tags` | Multi-criteria search |
| `export-media-album` album-id output-dir | Export album |

### Quick Example

```lisp
(multiple-value-bind (album-id error)
    (create-media-album "Vacation 2024" chat-id
                        :description "Summer trip")
  (add-media-to-album album-id media-ids)
  (add-media-tags media-id '("vacation" "summer")))

;; Auto-create albums
(auto-create-albums chat-id :by-date t :by-event t :min-items 3)

;; Search
(search-media chat-id :type :photo :tags '("vacation"))
```

---

## Quality Presets

| Preset | Resolution | FPS | Bandwidth |
|--------|------------|-----|-----------|
| `:ld` | 240p | 15 | ~100 Kbps |
| `:sd` | 480p | 24 | ~500 Kbps |
| `:hd` | 720p | 30 | ~2 Mbps |
| `:fhd` | 1080p | 30 | ~5 Mbps |
| `:screen` | 1080p | 60 | ~8 Mbps |

---

## Error Handling

```lisp
(handler-case
    (start-group-video-stream group-call-id :resolution :hd)
  (:error (e)
    (cond
      ((eql e :not-authenticated) (format t "Please log in~%"))
      ((eql e :max-participants-reached) (format t "Limit reached~%"))
      ((eql e :webrtc-init-failed) (format t "WebRTC failed~%"))
      (t (format t "Error: ~A~%" e)))))
```

---

## Return Values

### Video Recording Progress
```lisp
(:state :recording :elapsed 30 :remaining 30 :percentage 0.5 :duration-limit 60)
```

### Group Video Stats
```lisp
(:stream-count 4
 :is-recording t
 :streams (( :stream-id "s1" :resolution :hd :fps 30 :participant-id "p1")
           ( :stream-id "s2" :resolution :sd :fps 24 :participant-id "p2")))
```

### Recording Stop
```lisp
(values "/path/to/video.mp4" 45 nil)  ; path, duration, error
```

---

## File Locations

| Component | Default Path |
|-----------|--------------|
| Video Recordings | `~/telegram-recordings/` |
| Video Messages (temp) | `~/temp/` |
| Media Exports | User specified |
| Thumbnails | Same directory as source |

---

## Performance Tips

1. **Use `:auto` quality** for adaptive bandwidth management
2. **Clean up old recordings** regularly to save disk space
3. **Limit group participants** to 10 for optimal performance
4. **Use `:ld` or `:sd`** on mobile networks
5. **Enable AI noise reduction** for better audio quality in noisy environments

---

**Version:** 0.26.0  
**Date:** 2026-04-20
