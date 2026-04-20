# cl-telegram v0.26.0 Usage Examples

This document provides complete usage examples for cl-telegram v0.26.0 new features.

## Table of Contents

1. [Group Video Calls](#1-group-video-calls)
2. [Video Messages](#2-video-messages)
3. [Media Album Management](#3-media-album-management)
4. [Complete Application Examples](#4-complete-application-examples)

---

## 1. Group Video Calls

### 1.1 Initialization and Basic Usage

```lisp
;; Load system
(asdf:load-system :cl-telegram)
(use-package :cl-telegram/api)

;; Initialize group video subsystem
(init-group-video 
  :max-participants 10      ; Maximum 10 participants
  :default-quality :hd      ; Default HD quality
  :recording-dir "~/telegram-recordings/")  ; Recording directory
```

### 1.2 Starting a Video Call

```lisp
;; Create group call
(multiple-value-bind (call-info error)
    (create-group-call chat-id :is-video-chat t :title "Team Meeting")
  (if error
      (format t "Failed to create call: ~A~%" error)
      (let ((group-call-id (getf call-info :group-call-id)))
        
        ;; Join the call
        (join-group-call group-call-id)
        
        ;; Start video stream
        (multiple-value-bind (stream-id err)
            (start-group-video-stream group-call-id 
                                      :resolution :hd 
                                      :fps 30)
          (if err
              (format t "Failed to start video: ~A~%" err)
              (format t "Video stream started: ~A~%" stream-id)))
        
        group-call-id)))
```

### 1.3 Screen Sharing

```lisp
;; Enable screen sharing
(multiple-value-bind (stream-id error)
    (enable-screen-sharing group-call-id 
                           :quality :screen
                           :capture-window nil  ; nil = full screen
                           :capture-monitor nil) ; nil = primary monitor
  (if error
      (format t "Screen share failed: ~A~%" error)
      (format t "Screen sharing started: ~A~%" stream-id)))

;; Stop screen sharing
(disable-screen-sharing group-call-id)
```

### 1.4 Video Quality Adjustment

```lisp
;; Auto-adjust based on bandwidth
(set-video-quality group-call-id :auto)

;; Manual quality setting
(set-video-quality group-call-id :hd)  ; :ld :sd :hd :fhd

;; Get current quality
(let ((quality (get-video-quality group-call-id)))
  (format t "Current video quality: ~A~%" quality))
```

### 1.5 Video Layout Management

```lisp
;; Get current layout
(let ((layout (get-group-video-layout group-call-id)))
  (format t "Layout type: ~A~%" (getf layout :type))
  (format t "Participants: ~A~%" (getf layout :participants))
  (format t "Grid: ~Dx~D~%" 
          (getf layout :columns)
          (getf layout :rows)))

;; Switch layout type
(set-video-layout-type group-call-id :speaker)  ; :grid :speaker :spotlight

;; Pin participant video
(pin-participant-video group-call-id participant-id)

;; Unpin
(unpin-participant-video group-call-id participant-id)
```

### 1.6 Call Recording

```lisp
;; Start recording
(multiple-value-bind (recording-path error)
    (toggle-group-call-recording group-call-id)
  (if error
      (format t "Recording failed: ~A~%" error)
      (format t "Recording started: ~A~%" recording-path)))

;; Stop recording
(multiple-value-bind (path duration error)
    (stop-group-call-recording group-call-id)
  (if error
      (format t "Failed to stop recording: ~A~%" error)
      (format t "Recording complete: ~A (duration: ~D seconds)~%" path duration)))

;; Get recording info
(let ((recording (get-group-call-recording group-call-id)))
  (when recording
    (format t "Recording path: ~A~%" (getf recording :path))
    (format t "Is recording: ~A~%" (getf recording :active)))))
```

### 1.7 AI Noise Reduction

```lisp
;; Enable noise reduction
(enable-ai-noise-reduction group-call-id :level :auto)
;; Available levels: :off :low :medium :high :auto

;; Disable noise reduction
(disable-ai-noise-reduction group-call-id)
```

### 1.8 Getting Statistics

```lisp
;; Get call statistics
(let ((stats (get-group-video-stats group-call-id)))
  (format t "Stream count: ~D~%" (getf stats :stream-count))
  (format t "Is recording: ~A~%" (getf stats :is-recording))
  
  ;; Iterate through stream stats
  (dolist (stream-info (getf stats :streams))
    (format t "  Stream: ~A~%" (getf stream-info :stream-id))
    (format t "    Resolution: ~A, FPS: ~D~%" 
            (getf stream-info :resolution)
            (getf stream-info :fps))))

;; Get specific participant stats
(let ((p-stats (get-participant-video-stats group-call-id participant-id)))
  (when p-stats
    (format t "Participant ~A status: ~A~%" 
            participant-id 
            (getf p-stats :state))))
```

---

## 2. Video Messages

### 2.1 Recording Video Messages

```lisp
;; Start recording
(start-video-message-recording 
  :duration-limit 60    ; Maximum 60 seconds
  :quality :medium      ; :low :medium :high :auto
  :device-id nil)       ; nil = default camera

;; Get recording progress
(let ((progress (get-recording-progress)))
  (format t "State: ~A~%" (getf progress :state))
  (format t "Elapsed: ~D seconds~%" (getf progress :elapsed))
  (format t "Remaining: ~D seconds~%" (getf progress :remaining))
  (format t "Progress: ~D%~%" (* 100 (getf progress :percentage))))

;; Pause recording
(pause-video-message-recording)

;; Resume recording
(resume-video-message-recording)

;; Stop recording
(multiple-value-bind (path duration error)
    (stop-video-message-recording)
  (if error
      (format t "Failed to stop: ~A~%" error)
      (progn
        (format t "Recording complete: ~A~%" path)
        (format t "Duration: ~D seconds~%" duration))))

;; Cancel recording
(cancel-video-message-recording)
```

### 2.2 Processing Video

```lisp
;; Process recorded video (auto crop to circle and compress)
(multiple-value-bind (success error)
    (process-video-message input-path output-path
                           :compress t
                           :crop-circular t
                           :quality :medium
                           :max-size 10485760)  ; 10MB
  (if error
      (format t "Processing failed: ~A~%" error)
      (format t "Processing complete: ~A~%" output-path)))

;; Crop to circle only
(crop-video-to-circle input-path output-path :size 640)

;; Compress only
(compress-video input-path output-path 
                :max-size 5242880  ; 5MB
                :quality :high
                :codec :h264)

;; Generate thumbnail
(let ((thumb-path (generate-video-thumbnail video-path 
                                             :time-position 2
                                             :size 320)))
  (format t "Thumbnail: ~A~%" thumb-path))
```

### 2.3 Sending and Receiving

```lisp
;; Send video message
(multiple-value-bind (message-id error)
    (send-video-message chat-id video-path 
                        :caption "Check this out!"
                        :reply-to nil)
  (if error
      (format t "Send failed: ~A~%" error)
      (format t "Sent: message ID ~A~%" message-id)))

;; Download video message
(multiple-value-bind (file-path error)
    (download-video-message message-id 
                            :chat-id chat-id
                            :output-path nil)  ; nil = auto-generate path
  (if error
      (format t "Download failed: ~A~%" error)
      (format t "Downloaded to: ~A~%" file-path)))

;; Parse video message
(let ((msg (get-message message-id chat-id)))
  (when msg
    (let ((video (parse-video-message msg)))
      (when video
        (format t "Video message details:~%")
        (format t "  Duration: ~D seconds~%" (video-message-duration video))
        (format t "  Size: ~Dx~D~%" 
                (video-message-width video)
                (video-message-height video))
        (format t "  File size: ~D bytes~%" (video-message-file-size video))
        (format t "  Is circular: ~A~%" (video-message-is-circular video))))))

;; Play video message
(play-video-message video-path :fullscreen nil)
```

### 2.4 Validating Video

```lisp
;; Validate video message format
(multiple-value-bind (valid error)
    (is-valid-video-message video-path)
  (if valid
      (format t "Video format is valid~%")
      (format t "Video format invalid: ~A~%" error)))

;; Get video metadata
(multiple-value-bind (duration width height file-size)
    (get-video-metadata video-path)
  (format t "Duration: ~D seconds~%" duration)
  (format t "Size: ~Dx~D~%" width height)
  (format t "File size: ~D bytes~%" file-size))
```

---

## 3. Media Album Management

### 3.1 Creating and Managing Albums

```lisp
;; Create album
(multiple-value-bind (album-id error)
    (create-media-album "2024 Annual Meeting" chat-id 
                        :description "Company annual party photos"
                        :cover-media-id nil)
  (if error
      (format t "Failed to create album: ~A~%" error)
      (format t "Album created: ~A~%" album-id)))

;; Edit album
(edit-media-album album-id 
                  :title "2024 Annual Meeting - Complete"
                  :description "Updated description"
                  :cover-media-id cover-media-id)

;; Get album list
(let ((albums (get-media-albums chat-id)))
  (format t "Total ~D albums:~%" (length albums))
  (dolist (album-id albums)
    (let ((album (get-media-album album-id)))
      (when album
        (format t "  - ~A (~D photos)~%" 
                (getf album :title)
                (getf album :media-count))))))

;; Get album details
(let ((album (get-media-album album-id)))
  (when album
    (format t "Title: ~A~%" (getf album :title))
    (format t "Description: ~A~%" (getf album :description))
    (format t "Media count: ~D~%" (getf album :media-count))
    (format t "Created date: ~A~%" (getf album :created-date))))

;; Delete album
(delete-media-album album-id)
```

### 3.2 Managing Media

```lisp
;; Add media to album
(add-media-to-album album-id '("media-1" "media-2" "media-3"))

;; Remove media from album
(remove-media-from-album album-id '("media-2"))

;; Reorder media
(reorder-album-media album-id '("media-3" "media-1" "media-2"))
```

### 3.3 Smart Albums

```lisp
;; Auto-create albums
(let ((created (auto-create-albums chat-id 
                                   :by-date t      ; Group by date
                                   :by-event t     ; Detect events
                                   :min-items 3))) ; Minimum 3 items
  (format t "Auto-created ~D albums:~%" (length created))
  (dolist (album-id created)
    (let ((album (get-media-album album-id)))
      (when album
        (format t "  - ~A (~D items)~%" 
                (getf album :title)
                (getf album :media-count))))))
```

### 3.4 Tag System

```lisp
;; Add tags to media
(add-media-tags media-id '("travel" "beach" "sunset"))

;; Remove tags
(remove-media-tags media-id '("sunset"))

;; Search by tags
(let ((results (search-media-by-tags chat-id 
                                     '("travel" "beach")
                                     :match-all t))) ; Match all tags
  (format t "Found ~D media items~%" (length results)))

;; Get popular tags
(let ((popular (get-popular-tags chat-id :limit 10)))
  (format t "Popular tags:~%")
  (dolist (tag-count popular)
    (format t "  ~A: ~D times~%" (car tag-count) (cdr tag-count))))
```

### 3.5 Search and Filter

```lisp
;; Multi-criteria search
(let ((results (search-media chat-id 
                             :type :photo           ; Type
                             :date-from start-date  ; Start date
                             :date-to end-date      ; End date
                             :tags '("travel")      ; Tags
                             :query "beach"         ; Text search
                             :limit 50)))           ; Limit
  (format t "Found ~D media items~%" (length results)))

;; Filter by type
(photos := (filter-media-by-type chat-id :photo))
(videos := (filter-media-by-type chat-id :video))
(documents := (filter-media-by-type chat-id :document))

;; Get timeline
(let ((timeline (get-media-timeline chat-id 
                                    :start-date nil
                                    :end-date nil)))
  (dolist (date-media timeline)
    (format t "~A: ~D media items~%" 
            (car date-media)
            (length (cdr date-media)))))
```

### 3.6 Exporting Media

```lisp
;; Export album
(multiple-value-bind (count error)
    (export-media-album album-id "~/telegram-exports/album/"
                        :format nil)  ; nil = original format
  (if error
      (format t "Export failed: ~A~%" error)
      (format t "Exported ~D files~%" count)))

;; Export all media from chat
(multiple-value-bind (count error)
    (export-all-media chat-id "~/telegram-exports/chat/"
                      :format nil)
  (if error
      (format t "Export failed: ~A~%" error)
      (format t "Exported ~D files~%" count)))
```

---

## 4. Complete Application Examples

### 4.1 Video Conferencing Bot

```lisp
(defpackage :meeting-bot
  (:use :cl :cl-telegram/api))

(in-package :meeting-bot)

(defvar *active-meetings* (make-hash-table :test 'equal)
  "Active meetings list")

(defun start-meeting (chat-id title)
  "Start a new meeting"
  (multiple-value-bind (call-info error)
      (create-group-call chat-id :is-video-chat t :title title)
    (if error
        (format t "Failed to create meeting: ~A~%" error)
        (let ((group-call-id (getf call-info :group-call-id)))
          ;; Initialize video
          (init-group-video :max-participants 50)
          
          ;; Join and start video
          (join-group-call group-call-id)
          (start-group-video-stream group-call-id :resolution :hd)
          
          ;; Enable noise reduction
          (enable-ai-noise-reduction group-call-id :level :high)
          
          ;; Start recording
          (toggle-group-call-recording group-call-id)
          
          ;; Store meeting info
          (setf (gethash group-call-id *active-meetings*) 
                (list :title title
                      :chat-id chat-id
                      :start-time (get-universal-time)))
          
          (format t "Meeting started: ~A (ID: ~A)~%" title group-call-id)))))

(defun end-meeting (group-call-id)
  "End a meeting"
  (let ((meeting (gethash group-call-id *active-meetings*)))
    (when meeting
      ;; Stop recording
      (multiple-value-bind (path duration)
          (stop-group-call-recording group-call-id)
        (format t "Recording saved: ~A (duration: ~D seconds)~%" path duration))
      
      ;; Leave call
      (leave-group-call group-call-id)
      
      ;; Remove meeting info
      (remhash group-call-id *active-meetings*)
      
      (format t "Meeting ended: ~A~%" (getf meeting :title)))))

;; Usage
;; (start-meeting 123456789 "Monday Standup")
;; (end-meeting group-call-id)
```

### 4.2 Media Management Tool

```lisp
(defpackage :media-manager
  (:use :cl :cl-telegram/api))

(in-package :media-manager)

(defun organize-chat-media (chat-id)
  "Organize chat media"
  (format t "Starting to organize media for chat ~A...~%" chat-id)
  
  ;; Auto-create albums
  (let ((albums (auto-create-albums chat-id 
                                    :by-date t 
                                    :by-event t
                                    :min-items 5)))
    (format t "Created ~D albums~%" (length albums)))
  
  ;; Get popular tags
  (let ((popular (get-popular-tags chat-id :limit 20)))
    (format t "Popular tags:~%")
    (dolist (tag-count popular)
      (format t "  ~A: ~D times~%" (car tag-count) (cdr tag-count))))
  
  ;; Show media statistics
  (let* ((photos (filter-media-by-type chat-id :photo))
         (videos (filter-media-by-type chat-id :video))
         (documents (filter-media-by-type chat-id :document)))
    (format t "Media statistics:~%")
    (format t "  Photos: ~D~%" (length photos))
    (format t "  Videos: ~D~%" (length videos))
    (format t "  Documents: ~D~%" (length documents))))

(defun backup-chat-media (chat-id backup-dir)
  "Backup chat media"
  (format t "Starting backup of chat ~A to ~A~%" chat-id backup-dir)
  
  (multiple-value-bind (count error)
      (export-all-media chat-id backup-dir)
    (if error
        (format t "Backup failed: ~A~%" error)
        (format t "Backup complete: ~D files~%" count))))

;; Usage
;; (organize-chat-media 123456789)
;; (backup-chat-media 123456789 "~/telegram-backup/")
```

### 4.3 Video Diary Recorder

```lisp
(defpackage :video-diary
  (:use :cl :cl-telegram/api))

(in-package :video-diary)

(defvar *diary-chat-id* nil
  "Diary chat ID")

(defun record-diary-entry (title duration-seconds)
  "Record a video diary entry"
  (format t "Starting video diary: ~A~%" title)
  
  ;; Start recording
  (start-video-message-recording 
    :duration-limit duration-seconds
    :quality :high)
  
  ;; Show progress
  (let ((finished nil))
    (unwind-protect
         (progn
           (loop until finished do
             (let ((progress (get-recording-progress)))
               (format t "~D% (~D/~D seconds)~%" 
                       (* 100 (getf progress :percentage))
                       (getf progress :elapsed)
                       (getf progress :remaining))
               (when (>= (getf progress :percentage) 1.0)
                 (setf finished t))
               (sleep 1))))
      ;; Stop recording
      (multiple-value-bind (path duration error)
          (stop-video-message-recording)
        (if error
            (format t "Recording failed: ~A~%" error)
            (progn
              (format t "Recording complete: ~D seconds~%" duration)
              
              ;; Send to diary chat
              (multiple-value-bind (msg-id send-error)
                  (send-video-message *diary-chat-id* path 
                                      :caption title)
                (if send-error
                    (format t "Send failed: ~A~%" send-error)
                    (format t "Diary saved: message ID ~A~%" msg-id)))))))))

;; Usage
;; (setf video-diary::*diary-chat-id* 123456789)
;; (record-diary-entry "Today's work summary" 60)
```

---

## 5. Error Handling

```lisp
;; Handle common errors
(handler-case 
    (progn
      (init-group-video)
      (multiple-value-bind (stream-id error)
          (start-group-video-stream "call-1" :resolution :hd)
        (cond
          ((eql error :not-authenticated)
           (format t "Please log in first~%"))
          ((eql error :max-participants-reached)
           (format t "Participant limit reached~%"))
          ((eql error :webrtc-init-failed)
           (format t "WebRTC initialization failed~%"))
          (t
           (format t "Video started successfully: ~A~%" stream-id)))))
  (error (e)
    (format t "Error occurred: ~A~%" e)))
```

---

## 6. Performance Recommendations

### 6.1 Video Quality Selection

| Scenario | Recommended Quality | Bandwidth |
|----------|---------------------|-----------|
| Mobile network | :ld or :sd | 100-500 Kbps |
| WiFi normal call | :hd | 2-3 Mbps |
| High quality meeting | :fhd | 5+ Mbps |
| Screen sharing | :screen | 8+ Mbps |

### 6.2 Memory Management

```lisp
;; Periodically clean up unused resources
(defun cleanup-video-resources ()
  "Clean up video resources"
  (shutdown-group-video)
  (init-group-video))

;; Limit recording file count
(defun cleanup-old-recordings (keep-days)
  "Clean up old recordings"
  (let* ((dir (video-manager-recording-dir *group-video-manager*))
         (cutoff (- (get-universal-time) (* keep-days 24 60 60))))
    (dolist (file (directory (merge-pathnames "*.mkv" dir)))
      (let ((mod-time (file-write-date file)))
        (when (< mod-time cutoff)
          (delete-file file)
          (format t "Deleted: ~A~%" file))))))
```

---

**Document Version**: v0.26.0  
**Last Updated**: 2026-04-20
