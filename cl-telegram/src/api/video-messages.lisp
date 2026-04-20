;;; video-messages.lisp --- Video message support for cl-telegram
;;;
;;; Provides Telegram-style video message features:
;;; - Circular video messages (round videos)
;;; - Video recording with progress
;;; - Video compression and encoding
;;; - Thumbnail generation
;;; - Send/receive video messages
;;;
;;; Version: 0.26.0

(in-package #:cl-telegram/api)

;;; ============================================================================
;;; Video Message Class
;;; ============================================================================

(defclass video-message ()
  ((message-id :initform nil :accessor video-message-id)
   (chat-id :initarg :chat-id :reader video-message-chat-id)
   (file-id :initform nil :accessor video-message-file-id)
   (file-path :initform nil :accessor video-message-file-path)
   (duration :initform nil :accessor video-message-duration)
   (width :initform 640 :accessor video-message-width)
   (height :initform 640 :accessor video-message-height)
   (file-size :initform nil :accessor video-message-file-size)
   (mime-type :initform "video/mp4" :accessor video-message-mime-type)
   (thumbnail-path :initform nil :accessor video-message-thumbnail-path)
   (is-circular :initform t :accessor video-message-is-circular)
   (supports-streaming :initform nil :accessor video-message-supports-streaming)
   (caption :initform nil :accessor video-message-caption)
   (date :initform nil :accessor video-message-date)
   (from-user-id :initform nil :accessor video-message-from-user-id)
   (waveform :initform nil :accessor video-message-waveform))) ; For voice-like visualization

(defun make-video-message (chat-id &key (file-path nil) (duration 15))
  "Create a new video message instance.

   CHAT-ID: The chat to send to
   FILE-PATH: Path to video file
   DURATION: Video duration in seconds

   Returns:
     video-message instance"
  (let ((msg (make-instance 'video-message :chat-id chat-id)))
    (when file-path
      (setf (video-message-file-path msg) file-path)
      ;; Extract metadata if file exists
      (when (probe-file file-path)
        (setf (video-message-file-size msg) (file-length file-path))))
    (setf (video-message-duration msg) duration
          (video-message-date msg) (get-universal-time))
    msg))

;;; ============================================================================
;;; Recording State
;;; ============================================================================

(defclass video-recorder ()
  ((state :initform :idle :accessor recorder-state) ; :idle, :recording, :paused, :stopped
   (start-time :initform nil :accessor recorder-start-time)
   (pause-time :initform nil :accessor recorder-pause-time)
   (total-paused-duration :initform 0 :accessor recorder-total-paused)
   (duration-limit :initform 60 :accessor recorder-duration-limit) ; seconds
   (quality :initform :auto :accessor recorder-quality)
   (output-path :initform nil :accessor recorder-output-path)
   (temp-path :initform nil :accessor recorder-temp-path)
   (current-frame :initform 0 :accessor recorder-current-frame)
   (total-frames :initform nil :accessor recorder-total-frames)
   (device-id :initform nil :accessor recorder-device-id)
   (error :initform nil :accessor recorder-error)))

(defvar *video-recorder* nil
  "Global video recorder instance")

(defun make-video-recorder ()
  "Create a new video recorder instance.

   Returns:
     video-recorder instance"
  (make-instance 'video-recorder))

(defun init-video-recorder ()
  "Initialize video recorder subsystem.

   Returns:
     T on success"
  (unless *video-recorder*
    (setf *video-recorder* (make-video-recorder)))
  t)

;;; ============================================================================
;;; Recording Controls
;;; ============================================================================

(defun start-video-message-recording (&key (duration-limit 60) (quality :auto)
                                           (device-id nil) (output-dir nil))
  "Start recording video message.

   DURATION-LIMIT: Maximum recording duration in seconds
   QUALITY: Recording quality (:auto, :low, :medium, :high)
   DEVICE-ID: Camera device ID (nil for default)
   OUTPUT-DIR: Output directory (nil for temp)

   Returns:
     (values t error)"
  (unless *video-recorder*
    (init-video-recorder))

  (let ((recorder *video-recorder*))
    (unless (eql (recorder-state recorder) :idle)
      (return-from start-video-message-recording
        (values nil :already-recording "Already recording")))

    ;; Reset state
    (setf (recorder-state recorder) :recording)
    (setf (recorder-start-time recorder) (get-universal-time))
    (setf (recorder-pause-time recorder) nil)
    (setf (recorder-total-paused recorder) 0)
    (setf (recorder-duration-limit recorder) duration-limit)
    (setf (recorder-quality recorder) quality)
    (setf (recorder-device-id recorder) device-id)
    (setf (recorder-error recorder) nil)
    (setf (recorder-current-frame recorder) 0)

    ;; Set output path
    (let* ((timestamp (format-time-string "~Y~m~d_%H%M%S"))
           (dir (or output-dir (namestring (merge-pathnames "temp/" (user-homedir-pathname)))))
           (temp-file (format nil "~Avideo_msg_~A.tmp" dir timestamp)))
      (ensure-directories-exist temp-file)
      (setf (recorder-temp-path recorder) temp-file)
      (setf (recorder-output-path recorder)
            (format nil "~Avideo_msg_~A.mp4" dir timestamp)))

    ;; Start capture (would integrate with camera API in production)
    ;; For now, mock the recording state
    (format t "Started video recording (limit: ~Ds, quality: ~A)~%"
            duration-limit quality)
    (format t "Output: ~A~%" (recorder-temp-path recorder))

    (values t nil)))

(defun stop-video-message-recording ()
  "Stop recording video message.

   Returns:
     (values video-path duration error)"
  (unless *video-recorder*
    (return-from stop-video-message-recording
      (values nil nil :not-initialized "Video recorder not initialized")))

  (let ((recorder *video-recorder*))
    (unless (eql (recorder-state recorder) :recording)
      (return-from stop-video-message-recording
        (values nil nil :not-recording "Not recording")))

    ;; Calculate duration
    (let* ((end-time (get-universal-time))
           (raw-duration (- end-time (recorder-start-time recorder)))
           (actual-duration (- raw-duration (/ (recorder-total-paused recorder) 60)))
           (temp-path (recorder-temp-path recorder))
           (output-path (recorder-output-path recorder)))

      ;; Set state
      (setf (recorder-state recorder) :stopped)

      ;; Process video (crop to circle, compress)
      (multiple-value-bind (success process-error)
          (process-video-message temp-path output-path
                                 :compress t
                                 :crop-circular t
                                 :quality (recorder-quality recorder))
        (unless success
          (return-from stop-video-message-recording
            (values nil nil process-error)))

        ;; Generate thumbnail
        (let ((thumb-path (generate-video-thumbnail output-path)))
          (when thumb-path
            (setf (video-message-thumbnail-path recorder) thumb-path)))

        (format t "Stopped recording (~D seconds): ~A~%"
                actual-duration output-path)
        (values output-path actual-duration nil)))))

(defun pause-video-message-recording ()
  "Pause video recording.

   Returns:
     (values t error)"
  (let ((recorder *video-recorder*))
    (unless recorder
      (return-from pause-video-message-recording
        (values nil :not-initialized "Video recorder not initialized")))

    (unless (eql (recorder-state recorder) :recording)
      (return-from pause-video-message-recording
        (values nil :not-recording "Not recording")))

    (setf (recorder-state recorder) :paused)
    (setf (recorder-pause-time recorder) (get-universal-time))
    (format t "Recording paused~%")
    (values t nil)))

(defun resume-video-message-recording ()
  "Resume paused recording.

   Returns:
     (values t error)"
  (let ((recorder *video-recorder*))
    (unless recorder
      (return-from resume-video-message-recording
        (values nil :not-initialized "Video recorder not initialized")))

    (unless (eql (recorder-state recorder) :paused)
      (return-from resume-video-message-recording
        (values nil :not-paused "Recording not paused")))

    ;; Accumulate paused duration
    (let ((paused-duration (/ (- (get-universal-time)
                                  (recorder-pause-time recorder))
                               60)))
      (incf (recorder-total-paused recorder) paused-duration))

    (setf (recorder-state recorder) :recording)
    (setf (recorder-pause-time recorder) nil)
    (format t "Recording resumed~%")
    (values t nil)))

(defun cancel-video-message-recording ()
  "Cancel video recording and cleanup.

   Returns:
     (values t error)"
  (let ((recorder *video-recorder*))
    (unless recorder
      (return-from cancel-video-message-recording
        (values nil :not-initialized "Video recorder not initialized")))

    (unless (member (recorder-state recorder) '(:recording :paused))
      (return-from cancel-video-message-recording
        (values nil :not-recording "Not recording")))

    ;; Cleanup temp file
    (let ((temp-path (recorder-temp-path recorder)))
      (when (and temp-path (probe-file temp-path))
        (delete-file temp-path)))

    ;; Reset state
    (setf (recorder-state recorder) :idle)
    (setf (recorder-temp-path recorder) nil)
    (setf (recorder-output-path recorder) nil)

    (format t "Recording cancelled~%")
    (values t nil)))

(defun get-recording-progress ()
  "Get current recording progress.

   Returns:
     Progress plist with :elapsed, :remaining, :percentage, :state"
  (unless *video-recorder*
    (return-from get-recording-progress
      (list :state :idle :percentage 0.0)))

  (let ((recorder *video-recorder*))
    (unless (member (recorder-state recorder) '(:recording :paused))
      (return-from get-recording-progress
        (list :state (recorder-state recorder) :percentage 0.0)))

    (let* ((start (recorder-start-time recorder))
           (now (get-universal-time))
           (elapsed-raw (- now start))
           (elapsed (- elapsed-raw (/ (recorder-total-paused recorder) 60)))
           (limit (recorder-duration-limit recorder))
           (percentage (min 1.0 (/ elapsed limit))))
      (list :state (recorder-state recorder)
            :elapsed elapsed
            :remaining (- limit elapsed)
            :percentage percentage
            :duration-limit limit))))

;;; ============================================================================
;;; Video Processing
;;; ============================================================================

(defun process-video-message (input-path output-path &key (compress t)
                                                           (crop-circular t)
                                                           (quality :auto)
                                                           (max-size 10485760)) ; 10MB default
  "Process recorded video message.

   INPUT-PATH: Source video file
   OUTPUT-PATH: Destination file
   COMPRESS: Whether to compress video
   CROP-CIRCULAR: Whether to crop to circular format
   QUALITY: Quality preset for compression
   MAX-SIZE: Maximum file size in bytes

   Returns:
     (values success error)"
  (unless (probe-file input-path)
    (return-from process-video-message
      (values nil :file-not-found (format nil "Input file not found: ~A" input-path))))

  (let ((temp-file (format nil "~A.processing.tmp" input-path)))
    (unwind-protect
         (progn
           ;; Step 1: Crop to circular if requested
           (when crop-circular
             (unless (crop-video-to-circle input-path temp-file)
               (return-from process-video-message
                 (values nil :crop-failed "Failed to crop video to circle"))))

           ;; Step 2: Compress if requested
           (when compress
             (let ((source (if crop-circular temp-file input-path)))
               (unless (compress-video source output-path
                                       :max-size max-size
                                       :quality quality)
                 (return-from process-video-message
                   (values nil :compress-failed "Failed to compress video")))))

           ;; If neither crop nor compress, just copy
           (unless (or crop-circular compress)
             (uiop:copy-file input-path output-path))

           (format t "Video processed: ~A~%" output-path)
           (values t nil))
      ;; Cleanup temp file
      (when (probe-file temp-file)
        (delete-file temp-file)))))

(defun crop-video-to-circle (input-path output-path &key (size 640))
  "Crop video to circular format.

   INPUT-PATH: Source video file
   OUTPUT-PATH: Destination file
   SIZE: Output video dimension (width=height)

   Returns:
     T on success, NIL on failure"
  (declare (ignorable input-path output-path size))
  ;; In production, this would use FFmpeg or similar:
  ;; ffmpeg -i input -vf \"crop=w=min(min(480\\,iw)\\,ih):h=min(min(480\\,iw)\\,ih),scale=480:480,setsar=1,format=yuva420p\" output.mp4

  ;; For now, mock success
  (format t "Would crop ~A to circular (~Dx~D) -> ~A~%" input-path size size output-path)
  t)

(defun compress-video (input-path output-path &key (max-size 10485760)
                                                  (quality :auto)
                                                  (codec :h264))
  "Compress video to target size.

   INPUT-PATH: Source video file
   OUTPUT-PATH: Destination file
   MAX-SIZE: Maximum file size in bytes
   QUALITY: Quality preset
   CODEC: Video codec (:h264, :h265, :vp9)

   Returns:
     T on success, NIL on failure"
  (declare (ignorable input-path output-path max-size quality codec))
  ;; In production, this would use FFmpeg:
  ;; ffmpeg -i input -c:v libx264 -crf 28 -preset medium -c:v aac -b:a 128k output.mp4

  ;; Quality to CRF mapping
  (let ((crf (case quality
               (:low 32)
               (:medium 28)
               (:high 23)
               (:auto 28)
               (otherwise 28))))
    (format t "Would compress ~A -> ~A (max: ~D bytes, CRF: ~D)~%"
            input-path output-path max-size crf))
  t)

(defun generate-video-thumbnail (video-path &key (time-position 1) (size 320))
  "Generate thumbnail from video.

   VIDEO-PATH: Source video file
   TIME-POSITION: Time in seconds for thumbnail capture
   SIZE: Thumbnail dimension

   Returns:
     Thumbnail path or NIL"
  (declare (ignorable video-path time-position size))
  ;; In production:
  ;; ffmpeg -i video.mp4 -ss 00:00:01 -vframes 1 -vf scale=320:320 thumb.jpg

  (let* ((dir (pathname-directory-pathname video-path))
         (thumb-path (format nil "~Athumbnail.jpg" (namestring dir))))
    (format t "Would generate thumbnail at ~Ds from ~A -> ~A~%"
            time-position video-path thumb-path)
    thumb-path))

;;; ============================================================================
;;; Sending Video Messages
;;; ============================================================================

(defun send-video-message (chat-id video-path &key (caption nil) (reply-to nil))
  "Send video message to chat.

   CHAT-ID: The chat to send to
   VIDEO-PATH: Path to video file
   CAPTION: Optional caption
   REPLY-TO: Message ID to reply to

   Returns:
     (values message-id error)"
  (unless (authorized-p)
    (return-from send-video-message
      (values nil :not-authorized "User not authenticated")))

  (unless (probe-file video-path)
    (return-from send-video-message
      (values nil :file-not-found (format nil "Video file not found: ~A" video-path))))

  (let ((connection (ensure-auth-connection)))
    (unless connection
      (return-from send-video-message
        (values nil :no-connection "No active connection")))

    ;; Get video metadata
    (multiple-value-bind (duration width height file-size)
        (get-video-metadata video-path)
      (let* ((file-content (with-open-file (s video-path :element-type '(unsigned-byte 8)
                                              :direction :input)
                             (let ((buf (make-array (file-length s) :element-type '(unsigned-byte 8))))
                               (read-sequence buf s)
                               buf)))
             (request (make-tl-object
                       'messages.sendMedia
                       :peer (make-tl-object 'inputPeerUser :user-id chat-id)
                       :media (make-tl-object
                               'inputMediaUploadedDocument
                               :file file-content
                               :mime-type "video/mp4"
                               :attributes (list
                                            (make-tl-object
                                             'documentAttributeVideo
                                             :duration duration
                                             :w width
                                             :h height
                                             :supports-streaming nil)
                                            (make-tl-object
                                             'documentAttributeFilename
                                             :file-name "video_message.mp4")))
                               :thumb nil)
                       :message (or caption "")
                       :random-id (random (expt 2 63))
                       :reply-to-msg-id reply-to
                       :clear-draft nil)))
        (rpc-handler-case (rpc-call connection request :timeout 30000)
          (:ok (result)
            (if (eq (getf result :@type) :updates)
                (let ((message-id (getf (getf result :message) :id)))
                  (format t "Sent video message: ~A to chat ~A~%" message-id chat-id)
                  (values message-id nil))
                (values nil :unexpected-response result)))
          (:error (err)
            (values nil :rpc-error err))))))

(defun get-video-metadata (video-path)
  "Extract video metadata.

   VIDEO-PATH: Path to video file

   Returns:
     (values duration width height file-size)"
  (declare (ignorable video-path))
  ;; In production, use FFprobe or similar:
  ;; ffprobe -v error -show_entries stream=codec_name,codec_type,width,height,duration -of json video.mp4

  ;; Mock metadata for now
  (let ((file-size (if (probe-file video-path) (file-length video-path) 1048576)))
    (values 15    ; duration in seconds
            640   ; width
            640   ; height
            file-size)))

;;; ============================================================================
;;; Receiving Video Messages
;;; ============================================================================

(defun download-video-message (message-id &key (chat-id nil) (output-path nil))
  "Download video message.

   MESSAGE-ID: The message ID
   CHAT-ID: Chat ID (current chat if nil)
   OUTPUT-PATH: Output file path (auto-generated if nil)

   Returns:
     (values file-path error)"
  (unless (authorized-p)
    (return-from download-video-message
      (values nil :not-authorized "User not authenticated")))

  ;; Get message to find document
  (let* ((connection (ensure-auth-connection))
         (message (get-message message-id chat-id)))
    (unless message
      (return-from download-video-message
        (values nil :message-not-found "Message not found")))

    ;; Extract document from message
    (let* ((media (getf message :media))
           (document (when (eq (getf media :@type) :messageMediaDocument)
                       (getf media :document))))
      (unless document
        (return-from download-video-message
          (values nil :not-video-message "Message is not a video message")))

      ;; Get file ID and download
      (let ((file-id (getf document :id)))
        (if output-path
            (download-file file-id output-path)
            (let* ((dir (namestring (merge-pathnames "downloads/" (user-homedir-pathname))))
                   (default-path (format nil "~Avideo_~A.mp4" dir message-id)))
              (ensure-directories-exist default-path)
              (download-file file-id default-path)))))))

(defun parse-video-message (message)
  "Parse message into video-message object.

   MESSAGE: The message object

   Returns:
     video-message instance or NIL"
  (let* ((media (getf message :media))
         (document (when (eq (getf media :@type) :messageMediaDocument)
                     (getf media :document))))
    (when document
      (let* ((attributes (getf document :attributes))
             (video-attr (find-if (lambda (attr)
                                    (eq (getf attr :@type) :documentAttributeVideo))
                                  attributes))
             (chat-id (getf message :peer-id)))
        (when video-attr
          (let ((vm (make-instance 'video-message :chat-id chat-id)))
            (setf (video-message-file-id vm) (getf document :id))
            (setf (video-message-duration vm) (getf video-attr :duration))
            (setf (video-message-width vm) (getf video-attr :w))
            (setf (video-message-height vm) (getf video-attr :h))
            (setf (video-message-file-size vm) (getf document :size))
            (setf (video-message-message-id vm) (getf message :id))
            (setf (video-message-from-user-id vm) (getf message :from-id))
            vm))))))

;;; ============================================================================
;;; Video Message Utilities
;;; ============================================================================

(defun play-video-message (video-path &key (fullscreen nil))
  "Play video message.

   VIDEO-PATH: Path to video file
   FULLSCREEN: Whether to play fullscreen

   Returns:
     T on success"
  (declare (ignorable video-path fullscreen))
  (unless (probe-file video-path)
    (return-from play-video-message
      (values nil :file-not-found "Video file not found")))

  ;; In production, integrate with media player
  (format t "Would play video: ~A (fullscreen: ~A)~%" video-path fullscreen)
  t)

(defun get-video-message-duration (video-path)
  "Get video duration in seconds.

   VIDEO-PATH: Path to video file

   Returns:
     Duration in seconds"
  (declare (ignorable video-path))
  ;; In production, use ffprobe
  15) ; Mock value

(defun is-valid-video-message (video-path)
  "Validate video message file.

   VIDEO-PATH: Path to video file

   Returns:
     (values valid error)"
  (unless (probe-file video-path)
    (return-from is-valid-video-message
      (values nil :file-not-found "File not found")))

  (let ((file-size (file-length video-path)))
    ;; Check size limits (max 10MB for video messages)
    (when (> file-size 10485760)
      (return-from is-valid-video-message
        (values nil :too-large "Video exceeds 10MB limit")))

    ;; Check extension
    (let ((ext (pathname-type video-path)))
      (unless (member ext '("mp4" "mov" "webm" "mkv") :test 'string-equal)
        (return-from is-valid-video-message
          (values nil :unsupported-format "Unsupported video format"))))

    ;; In production, also check:
    ;; - Video codec (H.264)
    ;; - Audio codec (AAC)
    ;; - Duration (< 60s for video messages)
    ;; - Dimensions (square for circular)

    (values t nil)))

;;; Export symbols (to be added to api-package.lisp)
;; #:start-video-message-recording
;; #:stop-video-message-recording
;; #:pause-video-message-recording
;; #:resume-video-message-recording
;; #:cancel-video-message-recording
;; #:get-recording-progress
;; #:process-video-message
;; #:crop-video-to-circle
;; #:compress-video
;; #:generate-video-thumbnail
;; #:send-video-message
;; #:download-video-message
;; #:parse-video-message
;; #:play-video-message
;; #:get-video-metadata
;; #:is-valid-video-message
